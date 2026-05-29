package config

import "time"

const (
	// Server
	ServerPort = ":8866"
	BaseURL    = "http://127.0.0.1:8866"

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
