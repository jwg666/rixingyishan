package service

import (
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
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
