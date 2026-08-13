package service

import (
	"sync"
	"time"

	"rixingyishan-service/config"
)

// 短信验证码频控（内存存储）
type smsRateLimiter struct {
	mu              sync.Mutex
	lastSendByPhone map[string]time.Time
	dailyByPhone    map[string]*dailyCounter
	dailyByIP       map[string]*dailyCounter
}

type dailyCounter struct {
	date  string
	count int
}

var SMSLimiter = &smsRateLimiter{
	lastSendByPhone: make(map[string]time.Time),
	dailyByPhone:    make(map[string]*dailyCounter),
	dailyByIP:       make(map[string]*dailyCounter),
}

// CheckAndRecord 检查并记录一次发送; 返回 (ok, reason)
func (l *smsRateLimiter) CheckAndRecord(phone, ip string) (bool, string) {
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	today := now.Format("2006-01-02")

	// 60秒频控
	if last, ok := l.lastSendByPhone[phone]; ok {
		if now.Sub(last) < config.SMSResendInterval {
			return false, "请求过于频繁，请稍后再试"
		}
	}

	// 每日手机号上限
	pc, ok := l.dailyByPhone[phone]
	if !ok || pc.date != today {
		pc = &dailyCounter{date: today, count: 0}
		l.dailyByPhone[phone] = pc
	}
	if pc.count >= config.SMSDailyLimitPhone {
		return false, "该手机号今日发送次数已达上限"
	}

	// 每日IP上限
	ic, ok := l.dailyByIP[ip]
	if !ok || ic.date != today {
		ic = &dailyCounter{date: today, count: 0}
		l.dailyByIP[ip] = ic
	}
	if ic.count >= config.SMSDailyLimitIP {
		return false, "该IP今日发送次数已达上限"
	}

	// 记录
	l.lastSendByPhone[phone] = now
	pc.count++
	ic.count++
	return true, ""
}
