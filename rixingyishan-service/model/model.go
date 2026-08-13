package model

import (
	"crypto/rand"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID           uint           `json:"id" gorm:"primaryKey"`
	Phone        string         `json:"phone" gorm:"uniqueIndex;size:20"`
	Nickname     string         `json:"nickname" gorm:"size:30"`
	Avatar       string         `json:"avatar" gorm:"size:500"`
	TotalMerit   int            `json:"totalMerit" gorm:"default:0"`
	AvatarSeed   string         `json:"avatarSeed" gorm:"size:8"`
	ShowInRanking bool          `json:"showInRanking" gorm:"default:true"`
	WxOpenid     string         `json:"wxOpenid" gorm:"size:64"`
	WxUnionid    string         `json:"wxUnionid" gorm:"size:64"`
	CreatedAt    time.Time      `json:"createdAt"`
	UpdatedAt    time.Time      `json:"updatedAt"`
	DeletedAt    gorm.DeletedAt `json:"-" gorm:"index"`
}

// BeforeCreate hook — 生成 AvatarSeed
func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.AvatarSeed == "" {
		u.AvatarSeed = randomHex(6)
	}
	return nil
}

// randomHex 生成 n 字符的 hex 字符串
func randomHex(n int) string {
	b := make([]byte, (n+1)/2)
	_, _ = rand.Read(b)
	s := fmt.Sprintf("%x", b)
	if len(s) > n {
		s = s[:n]
	}
	return s
}

// Record 记录模型
type Record struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	UserID      uint           `json:"userId" gorm:"index"`
	Type        string         `json:"type" gorm:"size:20"`
	Content     string         `json:"content" gorm:"type:text"`
	Tag         string         `json:"tag" gorm:"size:30;not null;default:'其他善行'"`
	MeritValue  int            `json:"meritValue" gorm:"not null;default:0"`
	RecordDate  string         `json:"recordDate" gorm:"size:10;index"`
	SyncVersion int            `json:"syncVersion" gorm:"default:1"`
	CreatedAt   time.Time      `json:"createdAt"`
	UpdatedAt   time.Time      `json:"updatedAt"`
	DeletedAt   gorm.DeletedAt `json:"-" gorm:"index"`
	Media       []Media        `json:"media" gorm:"foreignKey:RecordID"`
}

// Media 媒体模型
type Media struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	RecordID  uint   `json:"recordId" gorm:"index"`
	ObjectKey string `json:"objectKey" gorm:"size:500"`
	RemoteUrl string `json:"remoteUrl" gorm:"size:500"`
	MimeType  string `json:"mimeType" gorm:"size:100"`
	Size      int64  `json:"size"`
	SortOrder int    `json:"sortOrder"`
}

// MeritTag 功德标签配置
type MeritTag struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	Name       string `json:"name" gorm:"size:30;not null"`
	Icon       string `json:"icon" gorm:"size:10"`
	MeritValue int    `json:"meritValue" gorm:"not null"`
	Keywords   string `json:"keywords" gorm:"size:500"` // 逗号分隔
	SortOrder  int    `json:"sortOrder" gorm:"default:0"`
	Enabled    bool   `json:"enabled" gorm:"default:true"`
}

// SeedMeritTags 种子数据
func SeedMeritTags(db *gorm.DB) {
	var count int64
	db.Model(&MeritTag{}).Count(&count)
	if count > 0 {
		return
	}
	tags := []MeritTag{
		{Name: "关爱动物", Icon: "🐾", MeritValue: 10, Keywords: "猫,狗,喂,流浪,救助,动物,鸟,鱼,兔子", SortOrder: 1},
		{Name: "帮助他人", Icon: "🤝", MeritValue: 10, Keywords: "帮,助,搀,扶,让座,指路,帮忙", SortOrder: 2},
		{Name: "环保行动", Icon: "🌱", MeritValue: 8, Keywords: "捡,垃圾,环保,节约,回收,种树,节能", SortOrder: 3},
		{Name: "孝老爱亲", Icon: "❤️", MeritValue: 15, Keywords: "父,母,孝,亲,陪,看望,长辈,养老", SortOrder: 4},
		{Name: "捐赠善举", Icon: "💝", MeritValue: 20, Keywords: "捐,赠,献,慈善,公益,助学,扶贫", SortOrder: 5},
		{Name: "志愿服务", Icon: "🕊️", MeritValue: 15, Keywords: "志愿,服务,社区,义务,支教,义诊", SortOrder: 6},
		{Name: "关爱儿童", Icon: "👶", MeritValue: 12, Keywords: "儿童,孩子,留守,助学,陪伴,辅导", SortOrder: 7},
		{Name: "其他善行", Icon: "✨", MeritValue: 5, Keywords: "", SortOrder: 8},
	}
	for _, t := range tags {
		db.Create(&t)
	}
}

// RankingCache 排行缓存
type RankingCache struct {
	ID           uint      `json:"id" gorm:"primaryKey"`
	RankType     string    `json:"rankType" gorm:"size:10;not null"` // total/daily
	UserID       uint      `json:"userId" gorm:"index"`
	Nickname     string    `json:"nickname" gorm:"size:30"`
	AvatarSeed   string    `json:"avatarSeed" gorm:"size:8"`
	MeritValue   int       `json:"meritValue"`
	RankPosition int       `json:"rankPosition"`
	CalculatedAt time.Time `json:"calculatedAt"`
}
