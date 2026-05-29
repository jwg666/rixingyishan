package service

import (
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"rixingyishan-service/config"
)

// Claims JWT claims
type Claims struct {
	UserID uint   `json:"userId"`
	Phone  string `json:"phone"`
	Type   string `json:"type"` // access / refresh
	jwt.RegisteredClaims
}

// GenerateAccessToken 生成 access token
func GenerateAccessToken(userID uint, phone string) (string, error) {
	return generateToken(userID, phone, "access", config.AccessTokenExpire)
}

// GenerateRefreshToken 生成 refresh token
func GenerateRefreshToken(userID uint, phone string) (string, error) {
	return generateToken(userID, phone, "refresh", config.RefreshTokenExpire)
}

func generateToken(userID uint, phone, tokenType string, expire time.Duration) (string, error) {
	claims := Claims{
		UserID: userID,
		Phone:  phone,
		Type:   tokenType,
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(),
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(expire)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			Issuer:    "rixingyishan",
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(config.JWTSecret))
}

// ParseToken 解析 token
func ParseToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", t.Header["alg"])
		}
		return []byte(config.JWTSecret), nil
	})
	if err != nil {
		return nil, err
	}
	if claims, ok := token.Claims.(*Claims); ok && token.Valid {
		return claims, nil
	}
	return nil, errors.New("invalid token")
}

// ---------- Token 黑名单（内存版） ----------

type tokenBlacklist struct {
	mu    sync.RWMutex
	items map[string]time.Time // jti -> 过期时间
}

var TokenBlacklist = &tokenBlacklist{
	items: make(map[string]time.Time),
}

// Add 将 jti 加入黑名单（带过期时间，便于清理）
func (b *tokenBlacklist) Add(jti string, expireAt time.Time) {
	if jti == "" {
		return
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	b.items[jti] = expireAt
	// 顺手清理过期项
	now := time.Now()
	for k, v := range b.items {
		if v.Before(now) {
			delete(b.items, k)
		}
	}
}

// Contains 判断 jti 是否在黑名单中
func (b *tokenBlacklist) Contains(jti string) bool {
	if jti == "" {
		return false
	}
	b.mu.RLock()
	defer b.mu.RUnlock()
	exp, ok := b.items[jti]
	if !ok {
		return false
	}
	if exp.Before(time.Now()) {
		return false
	}
	return true
}
