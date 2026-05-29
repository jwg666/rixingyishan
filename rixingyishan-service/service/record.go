package service

import (
	"time"

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

// CreateRecord 创建记录
func (s *RecordService) CreateRecord(userID uint, req *CreateRecordReq) (*model.Record, error) {
	record := &model.Record{
		UserID:      userID,
		Type:        req.Type,
		Content:     req.Content,
		RecordDate:  req.RecordDate,
		SyncVersion: 1,
	}
	if err := s.DB.Create(record).Error; err != nil {
		return nil, err
	}
	// 创建 media
	for i, m := range req.Media {
		media := model.Media{
			RecordID:  record.ID,
			ObjectKey: m.ObjectKey,
			RemoteUrl: m.RemoteUrl,
			MimeType:  m.MimeType,
			Size:      m.Size,
			SortOrder: i,
		}
		if err := s.DB.Create(&media).Error; err != nil {
			return nil, err
		}
		record.Media = append(record.Media, media)
	}
	return record, nil
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

// DeleteRecord 软删除
func (s *RecordService) DeleteRecord(id, userID uint) error {
	result := s.DB.Where("id = ? AND user_id = ?", id, userID).Delete(&model.Record{})
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return result.Error
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

// CreateRecordReq 创建记录请求
type CreateRecordReq struct {
	Type       string         `json:"type" binding:"required,oneof=photo video text"`
	Content    string         `json:"content"`
	RecordDate string         `json:"recordDate" binding:"required"`
	Media      []MediaInput   `json:"media"`
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
}

// Notice: we need time import for potential use
var _ = time.ANSIC
