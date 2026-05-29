package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"rixingyishan-service/service"
)

// Response 统一响应
type Response struct {
	Code    int         `json:"code"`
	Message string      `json:"message"`
	Data    interface{} `json:"data"`
}

// AuthRequired JWT 认证中间件
func AuthRequired() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, Response{
				Code:    40001,
				Message: "缺少认证信息",
				Data:    nil,
			})
			c.Abort()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.JSON(http.StatusUnauthorized, Response{
				Code:    40001,
				Message: "认证格式错误",
				Data:    nil,
			})
			c.Abort()
			return
		}

		claims, err := service.ParseToken(parts[1])
		if err != nil {
			c.JSON(http.StatusUnauthorized, Response{
				Code:    40001,
				Message: "token 无效或已过期",
				Data:    nil,
			})
			c.Abort()
			return
		}

		if claims.Type != "access" {
			c.JSON(http.StatusUnauthorized, Response{
				Code:    40001,
				Message: "请使用 access token",
				Data:    nil,
			})
			c.Abort()
			return
		}

		// 检查黑名单
		if service.TokenBlacklist.Contains(claims.ID) {
			c.JSON(http.StatusUnauthorized, Response{
				Code:    40001,
				Message: "token 已被吊销",
				Data:    nil,
			})
			c.Abort()
			return
		}

		c.Set("userId", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("jti", claims.ID)
		c.Next()
	}
}

// OptionalAuth 可选认证中间件（有 token 就解析，没有也放行）
func OptionalAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.Next()
			return
		}

		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || parts[0] != "Bearer" {
			c.Next()
			return
		}

		claims, err := service.ParseToken(parts[1])
		if err != nil {
			c.Next()
			return
		}

		if claims.Type != "access" {
			c.Next()
			return
		}

		if service.TokenBlacklist.Contains(claims.ID) {
			c.Next()
			return
		}

		c.Set("userId", claims.UserID)
		c.Set("phone", claims.Phone)
		c.Set("jti", claims.ID)
		c.Next()
	}
}

// GetUserID 从 context 获取 userId
func GetUserID(c *gin.Context) uint {
	if v, exists := c.Get("userId"); exists {
		if id, ok := v.(uint); ok {
			return id
		}
	}
	return 0
}

// GetJTI 从 context 获取 jti
func GetJTI(c *gin.Context) string {
	if v, exists := c.Get("jti"); exists {
		if jti, ok := v.(string); ok {
			return jti
		}
	}
	return ""
}
