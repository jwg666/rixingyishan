package service

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"sync"
	"time"

	"rixingyishan-service/config"
)

// ---------- 短信验证码存储（内存版：TTL + 尝试次数限制） ----------

type smsCodeEntry struct {
	code     string
	expireAt time.Time
	attempts int
}

// 单个验证码最多允许验证次数，防暴力破解
const maxVerifyAttempts = 5

var (
	codeMu    sync.Mutex
	codeStore = make(map[string]*smsCodeEntry)
)

// StoreSMSCode 存储指定验证码（mock 模式用）
func StoreSMSCode(phone, code string) {
	codeMu.Lock()
	defer codeMu.Unlock()
	codeStore[phone] = &smsCodeEntry{code: code, expireAt: time.Now().Add(config.SMSCodeTTL)}
}

// GenerateSMSCode 生成 6 位随机数字验证码并存储，返回验证码
func GenerateSMSCode(phone string) string {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		// 极端情况下回退到时间戳尾 6 位
		n = big.NewInt(time.Now().UnixNano() % 1000000)
	}
	code := fmt.Sprintf("%06d", n.Int64())
	StoreSMSCode(phone, code)
	return code
}

// CheckSMSCode 校验验证码：过期/超次/错误分别给出原因，成功后立即销毁
func CheckSMSCode(phone, code string) (bool, string) {
	codeMu.Lock()
	defer codeMu.Unlock()

	cleanupExpiredLocked()

	e, ok := codeStore[phone]
	if !ok || time.Now().After(e.expireAt) {
		return false, "验证码不存在或已过期，请重新获取"
	}
	if e.attempts >= maxVerifyAttempts {
		delete(codeStore, phone)
		return false, "验证次数过多，请重新获取验证码"
	}
	if e.code != code {
		e.attempts++
		return false, "验证码错误"
	}
	delete(codeStore, phone)
	return true, ""
}

func cleanupExpiredLocked() {
	now := time.Now()
	for k, e := range codeStore {
		if now.After(e.expireAt) {
			delete(codeStore, k)
		}
	}
}
