package handler

import (
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
	"rixingyishan-service/config"
	"rixingyishan-service/middleware"
	"rixingyishan-service/model"
	"rixingyishan-service/service"
)

// AuthHandler 认证 handler
type AuthHandler struct {
	DB *gorm.DB
}

// NewAuthHandler 创建 AuthHandler
func NewAuthHandler(db *gorm.DB) *AuthHandler {
	return &AuthHandler{DB: db}
}

// SendSMS 发送验证码
func (h *AuthHandler) SendSMS(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "手机号不能为空",
			Data:    nil,
		})
		return
	}

	ip := c.ClientIP()
	ok, reason := service.SMSLimiter.CheckAndRecord(req.Phone, ip)
	if !ok {
		c.JSON(http.StatusTooManyRequests, middleware.Response{
			Code:    40001,
			Message: reason,
			Data:    nil,
		})
		return
	}

	// Mock: 打印验证码
	fmt.Printf("[SMS Mock] 发送验证码 %s 到手机 %s\n", config.MockSMSCode, req.Phone)

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"message": "验证码已发送",
		},
	})
}

// VerifySMS 校验验证码 + 签发 token
func (h *AuthHandler) VerifySMS(c *gin.Context) {
	var req struct {
		Phone string `json:"phone" binding:"required"`
		Code  string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "参数不完整",
			Data:    nil,
		})
		return
	}

	// Mock: 验证码校验
	if req.Code != config.MockSMSCode {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "验证码错误",
			Data:    nil,
		})
		return
	}

	// 查找或创建用户
	var user model.User
	result := h.DB.Where("phone = ?", req.Phone).First(&user)
	if result.Error == gorm.ErrRecordNotFound {
		// 自动注册
		user = model.User{
			Phone:    req.Phone,
			Nickname: "用户" + req.Phone[len(req.Phone)-4:],
		}
		if err := h.DB.Create(&user).Error; err != nil {
			c.JSON(http.StatusInternalServerError, middleware.Response{
				Code:    40001,
				Message: "创建用户失败",
				Data:    nil,
			})
			return
		}
	}

	// 签发 token
	accessToken, err := service.GenerateAccessToken(user.ID, user.Phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "生成token失败",
			Data:    nil,
		})
		return
	}

	refreshToken, err := service.GenerateRefreshToken(user.ID, user.Phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "生成token失败",
			Data:    nil,
		})
		return
	}

	result2 := service.VerifyResult{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		ExpiresIn:    int64(config.AccessTokenExpire.Seconds()),
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data:    result2,
	})
}

// RefreshToken 刷新 access token
func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refreshToken" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "refreshToken 不能为空",
			Data:    nil,
		})
		return
	}

	claims, err := service.ParseToken(req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, middleware.Response{
			Code:    40001,
			Message: "refreshToken 无效或已过期",
			Data:    nil,
		})
		return
	}

	if claims.Type != "refresh" {
		c.JSON(http.StatusBadRequest, middleware.Response{
			Code:    40001,
			Message: "请使用 refresh token",
			Data:    nil,
		})
		return
	}

	// 检查黑名单
	if service.TokenBlacklist.Contains(claims.ID) {
		c.JSON(http.StatusUnauthorized, middleware.Response{
			Code:    40001,
			Message: "refreshToken 已被吊销",
			Data:    nil,
		})
		return
	}

	// 生成新的 access token
	accessToken, err := service.GenerateAccessToken(claims.UserID, claims.Phone)
	if err != nil {
		c.JSON(http.StatusInternalServerError, middleware.Response{
			Code:    40001,
			Message: "生成token失败",
			Data:    nil,
		})
		return
	}

	result := service.RefreshResult{
		AccessToken: accessToken,
		ExpiresIn:   int64(config.AccessTokenExpire.Seconds()),
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data:    result,
	})
}

// Logout POST /api/auth/logout — 吊销 refresh token
func (h *AuthHandler) Logout(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refreshToken"`
	}
	_ = c.ShouldBindJSON(&req)

	if req.RefreshToken != "" {
		claims, err := service.ParseToken(req.RefreshToken)
		if err == nil && claims.ID != "" {
			expiry := time.Unix(claims.ExpiresAt.Unix(), 0)
			service.TokenBlacklist.Add(claims.ID, expiry)
		}
	}

	c.JSON(http.StatusOK, middleware.Response{
		Code:    0,
		Message: "success",
		Data: gin.H{
			"message": "已退出登录",
		},
	})
}
