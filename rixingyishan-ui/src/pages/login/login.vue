<template>
  <view class="container">
    <view class="header">
      <text class="app-name">日行一善</text>
      <text class="app-desc">记录每天的美好瞬间</text>
    </view>

    <view class="form-section">
      <view class="input-group">
        <text class="label">手机号</text>
        <input
          class="input"
          v-model="phone"
          type="number"
          maxlength="11"
          placeholder="请输入手机号"
        />
      </view>

      <view class="input-group">
        <text class="label">验证码</text>
        <view class="code-row">
          <input
            class="input code-input"
            v-model="code"
            type="number"
            maxlength="6"
            placeholder="请输入验证码"
          />
          <button
            class="code-btn"
            :disabled="countdown > 0 || !isPhoneValid"
            @click="sendCode"
          >
            {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
          </button>
        </view>
      </view>

      <button class="login-btn" :disabled="!canLogin || isLogging" @click="doLogin">
        {{ isLogging ? '登录中...' : '登录' }}
      </button>
    </view>

    <view class="footer">
      <text class="footer-text">未注册手机号将自动创建账号</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed } from "vue";
import { onLoad } from "@dcloudio/uni-app";
import { AuthService } from "@/services/AuthService";

const phone = ref("");
const code = ref("");
const countdown = ref(0);
const isLogging = ref(false);
const redirect = ref("");

let countdownTimer: ReturnType<typeof setInterval> | null = null;

onLoad((options) => {
  if (options?.redirect) {
    redirect.value = decodeURIComponent(options.redirect);
  }
});

/** 手机号格式校验 */
const isPhoneValid = computed(() => /^1[3-9]\d{9}$/.test(phone.value));

/** 是否可以登录 */
const canLogin = computed(() => isPhoneValid.value && /^\d{6}$/.test(code.value));

/** 发送验证码 */
async function sendCode() {
  if (!isPhoneValid.value || countdown.value > 0) return;

  try {
    await AuthService.sendSmsCode(phone.value);
    uni.showToast({ title: "验证码已发送", icon: "success" });

    // 启动倒计时
    countdown.value = 60;
    countdownTimer = setInterval(() => {
      countdown.value -= 1;
      if (countdown.value <= 0) {
        if (countdownTimer) {
          clearInterval(countdownTimer);
          countdownTimer = null;
        }
      }
    }, 1000);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "发送验证码失败";
    uni.showToast({ title: msg, icon: "none" });
  }
}

/** 登录 */
async function doLogin() {
  if (!canLogin.value || isLogging.value) return;

  isLogging.value = true;
  try {
    const result = await AuthService.verifySmsCode(phone.value, code.value);
    uni.showToast({ title: "登录成功", icon: "success" });

    // 延迟跳转
    setTimeout(() => {
      if (redirect.value) {
        // 跳回原页面
        uni.redirectTo({ url: redirect.value });
      } else {
        // 跳转首页
        uni.switchTab({ url: "/pages/index/index" });
      }
    }, 1000);
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "登录失败";
    uni.showToast({ title: msg, icon: "none" });
  } finally {
    isLogging.value = false;
  }
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 40rpx 32rpx;
  display: flex;
  flex-direction: column;
}

.header {
  text-align: center;
  margin-top: 80rpx;
  margin-bottom: 60rpx;
}

.app-name {
  font-size: 48rpx;
  font-weight: bold;
  color: #E8733A;
  display: block;
  margin-bottom: 16rpx;
}

.app-desc {
  font-size: 28rpx;
  color: #999999;
  display: block;
}

.form-section {
  background-color: #ffffff;
  border-radius: 20rpx;
  padding: 40rpx 32rpx;
}

.input-group {
  margin-bottom: 32rpx;
}

.label {
  font-size: 28rpx;
  color: #333333;
  margin-bottom: 12rpx;
  display: block;
}

.input {
  border: 1rpx solid #e8e8e8;
  border-radius: 12rpx;
  padding: 20rpx 24rpx;
  font-size: 28rpx;
  background-color: #FFF8F0;
  width: 100%;
  box-sizing: border-box;
}

.code-row {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.code-input {
  flex: 1;
}

.code-btn {
  flex-shrink: 0;
  background-color: #E8733A;
  color: #ffffff;
  border: none;
  border-radius: 12rpx;
  font-size: 24rpx;
  padding: 20rpx 24rpx;
  white-space: nowrap;
  line-height: 1.2;
}

.code-btn[disabled] {
  background-color: #cccccc;
  color: #ffffff;
}

.login-btn {
  margin-top: 16rpx;
  background-color: #E8733A;
  color: #ffffff;
  border: none;
  border-radius: 12rpx;
  font-size: 32rpx;
  padding: 24rpx 0;
  width: 100%;
}

.login-btn[disabled] {
  background-color: #cccccc;
}

.footer {
  text-align: center;
  margin-top: 40rpx;
}

.footer-text {
  font-size: 24rpx;
  color: #999999;
}
</style>
