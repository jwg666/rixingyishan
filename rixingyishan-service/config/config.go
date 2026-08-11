package config

import (
	"os"
	"time"
)

const (
	// Server
	ServerPort = ":8866"

	// Database
	DBPath = "data/rixingyishan.db"

	// Upload
	UploadDir       = "uploads"
	UploadURLPrefix = "/uploads"

	// JWT
	JWTSecret          = "rixingyishan-dev-jwt-secret-2026"
	AccessTokenExpire  = 2 * time.Hour
	RefreshTokenExpire = 30 * 24 * time.Hour

	// SMS mock
	MockSMSCode = "123456"

	// Rate limit
	SMSResendInterval   = 60 * time.Second
	SMSDailyLimitPhone  = 5
	SMSDailyLimitIP     = 10
)

// BaseURL 对外可访问的服务基地址（用于拼接 uploadUrl/remoteUrl）。
// 部署在 nginx 反代后时应设为公网地址，如 https://agent01.qdyhjz.cn/rxys
// 可用环境变量 RXYS_BASE_URL 覆盖。
var BaseURL = func() string {
	if v := os.Getenv("RXYS_BASE_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:8866"
}()
