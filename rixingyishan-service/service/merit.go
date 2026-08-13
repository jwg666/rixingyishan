package service

import (
	"strings"

	"gorm.io/gorm"
	"rixingyishan-service/model"
)

// MeritService 功德标签业务
type MeritService struct {
	DB *gorm.DB
}

// NewMeritService 创建 MeritService
func NewMeritService(db *gorm.DB) *MeritService {
	return &MeritService{DB: db}
}

// MeritTagDTO 标签 DTO（keywords 拆成数组）
type MeritTagDTO struct {
	ID         uint     `json:"id"`
	Name       string   `json:"name"`
	Icon       string   `json:"icon"`
	MeritValue int      `json:"meritValue"`
	Keywords   []string `json:"keywords"`
	SortOrder  int      `json:"sortOrder"`
}

// ListEnabledTags 获取所有启用标签
func (s *MeritService) ListEnabledTags() ([]MeritTagDTO, error) {
	var tags []model.MeritTag
	if err := s.DB.Where("enabled = ?", true).Order("sort_order ASC").Find(&tags).Error; err != nil {
		return nil, err
	}
	dtos := make([]MeritTagDTO, 0, len(tags))
	for _, t := range tags {
		dtos = append(dtos, MeritTagDTO{
			ID:         t.ID,
			Name:       t.Name,
			Icon:       t.Icon,
			MeritValue: t.MeritValue,
			Keywords:   splitKeywords(t.Keywords),
			SortOrder:  t.SortOrder,
		})
	}
	return dtos, nil
}

// MatchTag 智能匹配：根据 content 中关键词命中数取最高，无匹配返回"其他善行"
func (s *MeritService) MatchTag(content string) (*MeritTagDTO, error) {
	tags, err := s.ListEnabledTags()
	if err != nil {
		return nil, err
	}
	if len(tags) == 0 {
		return nil, nil
	}

	var best *MeritTagDTO
	bestHits := 0
	var fallback *MeritTagDTO

	for i := range tags {
		t := tags[i]
		if t.Name == "其他善行" {
			fb := t
			fallback = &fb
		}
		hits := 0
		for _, kw := range t.Keywords {
			kw = strings.TrimSpace(kw)
			if kw == "" {
				continue
			}
			if strings.Contains(content, kw) {
				hits++
			}
		}
		if hits > bestHits {
			bestHits = hits
			b := t
			best = &b
		}
	}

	if best != nil {
		return best, nil
	}
	if fallback != nil {
		return fallback, nil
	}
	// 兜底取第一个
	first := tags[0]
	return &first, nil
}

// GetTagByName 按名称查询标签
func (s *MeritService) GetTagByName(name string) (*model.MeritTag, error) {
	var t model.MeritTag
	if err := s.DB.Where("name = ?", name).First(&t).Error; err != nil {
		return nil, err
	}
	return &t, nil
}

func splitKeywords(s string) []string {
	if strings.TrimSpace(s) == "" {
		return []string{}
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}
