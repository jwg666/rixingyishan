package config

import (
	"bufio"
	"os"
	"strconv"
	"strings"
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

	// SMS mock（SMS_PROVIDER != aliyun 时使用）
	MockSMSCode = "123456"

	// Rate limit
	SMSResendInterval  = 60 * time.Second
	SMSDailyLimitPhone = 5
	SMSDailyLimitIP    = 10
)

// ---------- SMS 配置（环境变量 / .env 加载） ----------

var (
	// SMSProvider 短信供应商："aliyun" 走真实发送，其它值走 mock
	SMSProvider = "mock"

	// 阿里云短信配置
	AliyunAccessKeyID     string
	AliyunAccessKeySecret string
	AliyunSMSSignName     string
	AliyunSMSTemplateCode string

	// SMSCodeTTL 验证码有效期（默认 5 分钟，可用 SMS_CODE_TTL 秒数覆盖）
	SMSCodeTTL = 5 * time.Minute
)

func init() {
	loadDotEnv(".env")

	if v := os.Getenv("SMS_PROVIDER"); v != "" {
		SMSProvider = strings.ToLower(strings.TrimSpace(v))
	}
	AliyunAccessKeyID = strings.TrimSpace(os.Getenv("ALIYUN_ACCESS_KEY_ID"))
	AliyunAccessKeySecret = strings.TrimSpace(os.Getenv("ALIYUN_ACCESS_KEY_SECRET"))
	AliyunSMSSignName = strings.TrimSpace(os.Getenv("ALIYUN_SMS_SIGN_NAME"))
	AliyunSMSTemplateCode = strings.TrimSpace(os.Getenv("ALIYUN_SMS_TEMPLATE_CODE"))
	if v := os.Getenv("SMS_CODE_TTL"); v != "" {
		if n, err := strconv.Atoi(strings.TrimSpace(v)); err == nil && n > 0 {
			SMSCodeTTL = time.Duration(n) * time.Second
		}
	}
}

// loadDotEnv 简易 .env 加载：KEY=VALUE 行，忽略空行与 # 注释；
// 已存在的环境变量优先，不覆盖。
func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		k = strings.TrimSpace(k)
		v = strings.TrimSpace(strings.Trim(strings.TrimSpace(v), `"'`))
		if k == "" {
			continue
		}
		if _, exists := os.LookupEnv(k); !exists {
			os.Setenv(k, v)
		}
	}
}

// BaseURL 对外可访问的服务基地址（用于拼接 uploadUrl/remoteUrl）。
// 部署在 nginx 反代后时应设为公网地址，如 https://agent01.qdyhjz.cn/rxys
// 可用环境变量 RXYS_BASE_URL 覆盖。
var BaseURL = func() string {
	if v := os.Getenv("RXYS_BASE_URL"); v != "" {
		return v
	}
	return "http://127.0.0.1:8866"
}()
