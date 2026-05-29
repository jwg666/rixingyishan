package model

import (
	"time"

	"gorm.io/gorm"
)

// User 用户模型
type User struct {
	ID        uint           `json:"id" gorm:"primaryKey"`
	Phone     string         `json:"phone" gorm:"uniqueIndex;size:20"`
	Nickname  string         `json:"nickname" gorm:"size:50"`
	Avatar    string         `json:"avatar" gorm:"size:500"`
	CreatedAt time.Time      `json:"createdAt"`
	UpdatedAt time.Time      `json:"updatedAt"`
	DeletedAt gorm.DeletedAt `json:"-" gorm:"index"`
}

// Record 记录模型
type Record struct {
	ID          uint           `json:"id" gorm:"primaryKey"`
	UserID      uint           `json:"userId" gorm:"index"`
	Type        string         `json:"type" gorm:"size:20"`
	Content     string         `json:"content" gorm:"type:text"`
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
