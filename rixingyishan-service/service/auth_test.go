package service

import (
	"testing"
	"time"
)

func TestTokenRoundTrip(t *testing.T) {
	access, err := GenerateAccessToken(42, "13800000000")
	if err != nil {
		t.Fatalf("generate access token: %v", err)
	}
	claims, err := ParseToken(access)
	if err != nil {
		t.Fatalf("parse access token: %v", err)
	}
	if claims.UserID != 42 || claims.Phone != "13800000000" || claims.Type != "access" {
		t.Errorf("access claims = %+v", claims)
	}

	refresh, err := GenerateRefreshToken(42, "13800000000")
	if err != nil {
		t.Fatalf("generate refresh token: %v", err)
	}
	claims, err = ParseToken(refresh)
	if err != nil {
		t.Fatalf("parse refresh token: %v", err)
	}
	if claims.Type != "refresh" {
		t.Errorf("refresh token type = %q, want refresh", claims.Type)
	}
}

func TestParseTokenRejectsGarbage(t *testing.T) {
	if _, err := ParseToken("not-a-token"); err == nil {
		t.Error("garbage token should fail to parse")
	}
}

func TestTokenBlacklist(t *testing.T) {
	refresh, err := GenerateRefreshToken(7, "13800000001")
	if err != nil {
		t.Fatalf("generate refresh token: %v", err)
	}
	claims, err := ParseToken(refresh)
	if err != nil {
		t.Fatalf("parse token: %v", err)
	}
	if claims.ID == "" {
		t.Fatal("token should carry a jti")
	}

	TokenBlacklist.Add(claims.ID, time.Now().Add(time.Hour))
	if !TokenBlacklist.Contains(claims.ID) {
		t.Error("jti should be blacklisted")
	}

	// 已过期项视同不在黑名单
	TokenBlacklist.Add("expired-jti", time.Now().Add(-time.Hour))
	if TokenBlacklist.Contains("expired-jti") {
		t.Error("expired jti should not be blacklisted")
	}

	// 空 jti 不入榜
	TokenBlacklist.Add("", time.Now().Add(time.Hour))
	if TokenBlacklist.Contains("") {
		t.Error("empty jti should never be blacklisted")
	}
}
