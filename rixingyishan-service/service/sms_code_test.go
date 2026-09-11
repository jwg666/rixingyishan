package service

import (
	"testing"
	"time"
)

func resetCodeStore() {
	codeMu.Lock()
	defer codeMu.Unlock()
	codeStore = make(map[string]*smsCodeEntry)
}

func TestCheckSMSCodeSuccessDestroys(t *testing.T) {
	resetCodeStore()
	const phone = "13800000001"

	StoreSMSCode(phone, "123456")

	if ok, _ := CheckSMSCode(phone, "000000"); ok {
		t.Error("wrong code should fail")
	}
	if ok, reason := CheckSMSCode(phone, "123456"); !ok {
		t.Fatalf("correct code should pass, reason=%q", reason)
	}
	// 成功后立即销毁
	if ok, _ := CheckSMSCode(phone, "123456"); ok {
		t.Error("code should be destroyed after success")
	}
}

func TestCheckSMSCodeMaxAttempts(t *testing.T) {
	resetCodeStore()
	const phone = "13800000002"

	StoreSMSCode(phone, "123456")
	for i := 0; i < maxVerifyAttempts; i++ {
		if ok, _ := CheckSMSCode(phone, "000000"); ok {
			t.Fatal("wrong code should fail")
		}
	}
	// 次数用尽后即使验证码正确也拒绝
	if ok, reason := CheckSMSCode(phone, "123456"); ok || reason != "验证次数过多，请重新获取验证码" {
		t.Errorf("after max attempts: ok=%v reason=%q", ok, reason)
	}
}

func TestCheckSMSCodeExpired(t *testing.T) {
	resetCodeStore()
	const phone = "13800000003"

	StoreSMSCode(phone, "123456")
	codeMu.Lock()
	codeStore[phone].expireAt = time.Now().Add(-time.Minute)
	codeMu.Unlock()

	if ok, reason := CheckSMSCode(phone, "123456"); ok || reason == "" {
		t.Errorf("expired code should fail, ok=%v reason=%q", ok, reason)
	}
}

func TestGenerateSMSCodeFormat(t *testing.T) {
	resetCodeStore()
	const phone = "13800000004"

	code := GenerateSMSCode(phone)
	if len(code) != 6 {
		t.Errorf("code = %q, want 6 digits", code)
	}
	codeMu.Lock()
	e, ok := codeStore[phone]
	codeMu.Unlock()
	if !ok || e.code != code {
		t.Error("generated code should be stored")
	}
}
