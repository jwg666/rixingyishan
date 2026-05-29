package service

import (
	"time"

	"gorm.io/gorm"
	"rixingyishan-service/model"
)

// RankingService 排行榜业务
type RankingService struct {
	DB *gorm.DB
}

// NewRankingService 创建 RankingService
func NewRankingService(db *gorm.DB) *RankingService {
	return &RankingService{DB: db}
}

// RankingItem 排行项
type RankingItem struct {
	RankPosition int    `json:"rankPosition"`
	Nickname     string `json:"nickname"`
	AvatarSeed   string `json:"avatarSeed"`
	MeritValue   int    `json:"meritValue"`
	IsMe         bool   `json:"isMe"`
}

// RankingResult 排行结果
type RankingResult struct {
	Items  []RankingItem  `json:"items"`
	MyRank *RankingItem   `json:"myRank"`
}

// CalculateRankings 计算排行并写入缓存
func (s *RankingService) CalculateRankings(rankType string) error {
	now := time.Now()

	switch rankType {
	case "total":
		return s.calculateTotalRankings(now)
	case "daily":
		return s.calculateDailyRankings(now)
	}
	return nil
}

func (s *RankingService) calculateTotalRankings(now time.Time) error {
	var users []model.User
	if err := s.DB.Where("show_in_ranking = ? AND total_merit > 0", true).
		Order("total_merit DESC").
		Limit(50).
		Find(&users).Error; err != nil {
		return err
	}

	// 删除旧缓存
	s.DB.Where("rank_type = ?", "total").Delete(&model.RankingCache{})

	for i, u := range users {
		cache := model.RankingCache{
			RankType:     "total",
			UserID:        u.ID,
			Nickname:      u.Nickname,
			AvatarSeed:    u.AvatarSeed,
			MeritValue:    u.TotalMerit,
			RankPosition:  i + 1,
			CalculatedAt:  now,
		}
		s.DB.Create(&cache)
	}
	return nil
}

func (s *RankingService) calculateDailyRankings(now time.Time) error {
	today := now.Format("2006-01-02")

	type dailyRow struct {
		UserID      uint
		Nickname    string
		AvatarSeed  string
		DailyMerit  int
	}

	var rows []dailyRow
	if err := s.DB.Model(&model.Record{}).
		Select("records.user_id, users.nickname, users.avatar_seed, SUM(records.merit_value) as daily_merit").
		Joins("JOIN users ON users.id = records.user_id").
		Where("records.record_date = ? AND users.show_in_ranking = ?", today, true).
		Group("records.user_id, users.nickname, users.avatar_seed").
		Order("daily_merit DESC").
		Limit(50).
		Scan(&rows).Error; err != nil {
		return err
	}

	// 删除旧缓存
	s.DB.Where("rank_type = ?", "daily").Delete(&model.RankingCache{})

	for i, r := range rows {
		cache := model.RankingCache{
			RankType:     "daily",
			UserID:        r.UserID,
			Nickname:      r.Nickname,
			AvatarSeed:    r.AvatarSeed,
			MeritValue:    r.DailyMerit,
			RankPosition:  i + 1,
			CalculatedAt:  now,
		}
		s.DB.Create(&cache)
	}
	return nil
}

// GetRankings 获取排行数据（带缓存判断）
func (s *RankingService) GetRankings(rankType string, page, pageSize int, currentUserID uint) (*RankingResult, error) {
	// 检查缓存是否存在且未过期
	var cacheCount int64
	s.DB.Model(&model.RankingCache{}).Where("rank_type = ?", rankType).Count(&cacheCount)

	if cacheCount == 0 {
		_ = s.CalculateRankings(rankType)
	} else {
		// 检查是否超过2小时
		var lastCalc model.RankingCache
		s.DB.Where("rank_type = ?", rankType).Order("calculated_at DESC").First(&lastCalc)
		if time.Since(lastCalc.CalculatedAt) > 2*time.Hour {
			_ = s.CalculateRankings(rankType)
		}
	}

	// 分页查询缓存
	var caches []model.RankingCache
	offset := (page - 1) * pageSize
	s.DB.Where("rank_type = ?", rankType).
		Order("rank_position ASC").
		Offset(offset).Limit(pageSize).
		Find(&caches)

	items := make([]RankingItem, 0, len(caches))
	for _, c := range caches {
		items = append(items, RankingItem{
			RankPosition: c.RankPosition,
			Nickname:      c.Nickname,
			AvatarSeed:    c.AvatarSeed,
			MeritValue:    c.MeritValue,
			IsMe:          c.UserID == currentUserID,
		})
	}

	// 查询当前用户排名
	var myRank *RankingItem
	if currentUserID > 0 {
		var myCache model.RankingCache
		if err := s.DB.Where("rank_type = ? AND user_id = ?", rankType, currentUserID).First(&myCache).Error; err == nil {
			myRank = &RankingItem{
				RankPosition: myCache.RankPosition,
				Nickname:      myCache.Nickname,
				AvatarSeed:    myCache.AvatarSeed,
				MeritValue:    myCache.MeritValue,
				IsMe:          true,
			}
		}
	}

	return &RankingResult{
		Items:  items,
		MyRank: myRank,
	}, nil
}
