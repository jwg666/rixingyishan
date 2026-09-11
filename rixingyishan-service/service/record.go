package service

import (
	"gorm.io/gorm"
	"rixingyishan-service/model"
)

// RecordService 记录业务逻辑
type RecordService struct {
	DB *gorm.DB
}

// NewRecordService 创建 RecordService
func NewRecordService(db *gorm.DB) *RecordService {
	return &RecordService{DB: db}
}

// resolveTagMerit 服务端权威计分：按 tag 从 MeritTag 配置取分值；
// 未知/停用 tag 归一化为「其他善行」，配置整体缺失时该 tag 原样保留、分值为 0。
// 客户端上报的 meritValue 不被信任。
func resolveTagMerit(db *gorm.DB, tag string) (string, int) {
	var t model.MeritTag
	if err := db.Where("name = ? AND enabled = ?", tag, true).First(&t).Error; err == nil {
		return t.Name, t.MeritValue
	}
	var fallback model.MeritTag
	if err := db.Where("name = ? AND enabled = ?", "其他善行", true).First(&fallback).Error; err == nil {
		return fallback.Name, fallback.MeritValue
	}
	return tag, 0
}

// CreateRecord 创建记录（计分/媒体/功德累加在同一事务内）
func (s *RecordService) CreateRecord(userID uint, req *CreateRecordReq) (*model.Record, error) {
	record := &model.Record{
		UserID:      userID,
		Type:        req.Type,
		Content:     req.Content,
		RecordDate:  req.RecordDate,
		SyncVersion: 1,
	}
	err := s.DB.Transaction(func(tx *gorm.DB) error {
		tag, merit := resolveTagMerit(tx, req.Tag)
		record.Tag = tag
		record.MeritValue = merit
		if err := tx.Create(record).Error; err != nil {
			return err
		}
		for i, m := range req.Media {
			media := model.Media{
				RecordID:  record.ID,
				ObjectKey: m.ObjectKey,
				RemoteUrl: m.RemoteUrl,
				MimeType:  m.MimeType,
				Size:      m.Size,
				SortOrder: i,
			}
			if err := tx.Create(&media).Error; err != nil {
				return err
			}
			record.Media = append(record.Media, media)
		}
		if record.MeritValue > 0 {
			if err := tx.Model(&model.User{}).Where("id = ?", userID).
				UpdateColumn("total_merit", gorm.Expr("total_merit + ?", record.MeritValue)).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return record, nil
}

// ErrSyncConflict LWW 冲突：客户端携带的 syncVersion 落后于服务端
type ErrSyncConflict struct {
	Current *model.Record
}

func (e *ErrSyncConflict) Error() string {
	return "记录已被更新，请以服务端最新版本为准"
}

// UpdateRecordReq 更新记录请求（LWW：携带客户端持有的 syncVersion）。
// type 与 recordDate 不可变；media 全量替换。
type UpdateRecordReq struct {
	SyncVersion int          `json:"syncVersion"`
	Content     string       `json:"content"`
	Tag         string       `json:"tag"`
	Media       []MediaInput `json:"media"`
}

// UpdateRecord LWW 更新：incoming syncVersion < 服务端版本时返回 ErrSyncConflict（携带服务端当前记录）；
// syncVersion 缺省（0）视为强制更新。内容、计分、media 替换与功德差额在同一事务内。
func (s *RecordService) UpdateRecord(id, userID uint, req *UpdateRecordReq) (*model.Record, error) {
	err := s.DB.Transaction(func(tx *gorm.DB) error {
		var record model.Record
		if err := tx.Preload("Media", func(db *gorm.DB) *gorm.DB {
			return db.Order("sort_order ASC")
		}).Where("id = ? AND user_id = ?", id, userID).First(&record).Error; err != nil {
			return err
		}
		if req.SyncVersion > 0 && req.SyncVersion < record.SyncVersion {
			return &ErrSyncConflict{Current: &record}
		}

		tag := record.Tag
		if req.Tag != "" {
			tag = req.Tag
		}
		tag, newMerit := resolveTagMerit(tx, tag)
		meritDelta := newMerit - record.MeritValue

		updates := map[string]interface{}{
			"content":      req.Content,
			"tag":          tag,
			"merit_value":  newMerit,
			"sync_version": record.SyncVersion + 1,
		}
		if err := tx.Model(&model.Record{}).Where("id = ?", record.ID).Updates(updates).Error; err != nil {
			return err
		}
		if err := tx.Where("record_id = ?", record.ID).Delete(&model.Media{}).Error; err != nil {
			return err
		}
		for i, m := range req.Media {
			media := model.Media{
				RecordID:  record.ID,
				ObjectKey: m.ObjectKey,
				RemoteUrl: m.RemoteUrl,
				MimeType:  m.MimeType,
				Size:      m.Size,
				SortOrder: i,
			}
			if err := tx.Create(&media).Error; err != nil {
				return err
			}
		}
		if meritDelta != 0 {
			if err := tx.Model(&model.User{}).Where("id = ?", userID).
				UpdateColumn("total_merit", gorm.Expr("total_merit + ?", meritDelta)).Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return s.GetRecordByID(id, userID)
}

// GetRecordByID 获取记录详情
func (s *RecordService) GetRecordByID(id, userID uint) (*model.Record, error) {
	var record model.Record
	if err := s.DB.Where("id = ? AND user_id = ?", id, userID).Preload("Media", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC")
	}).First(&record).Error; err != nil {
		return nil, err
	}
	return &record, nil
}

// ListRecordsByDay 按天分页查询
func (s *RecordService) ListRecordsByDay(userID uint, dayKey string, page, pageSize int) ([]model.Record, int64, error) {
	var records []model.Record
	var total int64

	query := s.DB.Where("user_id = ? AND record_date = ?", userID, dayKey)
	query.Model(&model.Record{}).Count(&total)

	offset := (page - 1) * pageSize
	if err := query.Preload("Media", func(db *gorm.DB) *gorm.DB {
		return db.Order("sort_order ASC")
	}).Order("created_at DESC").Offset(offset).Limit(pageSize).Find(&records).Error; err != nil {
		return nil, 0, err
	}
	return records, total, nil
}

// DeleteRecord 软删除，并在同一事务内扣回该记录贡献的功德
func (s *RecordService) DeleteRecord(id, userID uint) error {
	return s.DB.Transaction(func(tx *gorm.DB) error {
		var record model.Record
		if err := tx.Where("id = ? AND user_id = ?", id, userID).First(&record).Error; err != nil {
			return err
		}
		if err := tx.Delete(&record).Error; err != nil {
			return err
		}
		if record.MeritValue > 0 {
			if err := tx.Model(&model.User{}).Where("id = ?", userID).
				UpdateColumn("total_merit", gorm.Expr("total_merit - ?", record.MeritValue)).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// GetDaysByMonth 获取当月有记录的日期列表
func (s *RecordService) GetDaysByMonth(userID uint, month string) ([]string, error) {
	var days []string
	startDate := month + "-01"
	endDate := month + "-31"
	if err := s.DB.Model(&model.Record{}).
		Where("user_id = ? AND record_date >= ? AND record_date <= ?", userID, startDate, endDate).
		Distinct("record_date").
		Order("record_date DESC").
		Pluck("record_date", &days).Error; err != nil {
		return nil, err
	}
	return days, nil
}

// CreateRecordReq 创建记录请求（meritValue 由服务端按 tag 计算，不接受客户端上报）
type CreateRecordReq struct {
	Type       string       `json:"type" binding:"required,oneof=photo video text"`
	Content    string       `json:"content"`
	Tag        string       `json:"tag"`
	RecordDate string       `json:"recordDate" binding:"required"`
	Media      []MediaInput `json:"media"`
}

// MediaInput 媒体输入
type MediaInput struct {
	ObjectKey string `json:"objectKey"`
	RemoteUrl string `json:"remoteUrl"`
	MimeType  string `json:"mimeType"`
	Size      int64  `json:"size"`
}

// ListRecordsResp 列表响应
type ListRecordsResp struct {
	Records  []model.Record `json:"records"`
	Total    int64          `json:"total"`
	Page     int            `json:"page"`
	PageSize int            `json:"pageSize"`
}

// DaysResp 日期列表响应
type DaysResp struct {
	Days []string `json:"days"`
}

// RefreshResult 刷新 token 结果
type RefreshResult struct {
	AccessToken string `json:"accessToken"`
	ExpiresIn   int64  `json:"expiresIn"`
}

// VerifyResult 验证结果
type VerifyResult struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	ExpiresIn    int64  `json:"expiresIn"`
	UserID       uint   `json:"userId"`
	Phone        string `json:"phone"`
}
