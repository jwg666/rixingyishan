<template>
  <view class="container">
    <!-- 顶部品牌区 -->
    <view class="header">
      <view class="logo">
        <text class="logo-icon">☀️</text>
      </view>
      <text class="app-name">日行一善</text>
      <text class="app-desc">记录每天的美好瞬间</text>
    </view>

    <!-- 登录表单卡片 -->
    <view class="form-card">
      <view class="input-group">
        <text class="label">手机号</text>
        <view class="input-box" :class="{ focused: focusKey === 'phone' }">
          <input
            class="input"
            v-model="phone"
            type="text"
            inputmode="numeric"
            maxlength="11"
            placeholder="请输入手机号"
            placeholder-class="input-ph"
            :focus="focusKey === 'phone'"
            @input="onPhoneInput"
            @focus="focusKey = 'phone'"
            @blur="focusKey = ''"
          />
        </view>
      </view>

      <view class="input-group">
        <text class="label">验证码</text>
        <view class="code-row">
          <view class="input-box code-box" :class="{ focused: focusKey === 'code' }">
            <input
              class="input"
              v-model="code"
              type="text"
              inputmode="numeric"
              maxlength="6"
              placeholder="6位验证码"
              placeholder-class="input-ph"
              :focus="focusKey === 'code'"
              @input="onCodeInput"
              @focus="focusKey = 'code'"
              @blur="focusKey = ''"
            />
          </view>
          <button
            class="code-btn"
            :disabled="countdown > 0 || !isPhoneValid"
            @click="sendCode"
          >
            {{ countdown > 0 ? `${countdown}s` : '获取验证码' }}
          </button>
        </view>
      </view>

      <button class="login-btn" :class="{ ready: canLogin }" :disabled="!canLogin || isLogging" @click="doLogin">
        {{ isLogging ? '登录中...' : '登录' }}
      </button>

      <!-- 协议勾选 -->
      <view class="agreement-row" @click="toggleAgree">
        <view class="checkbox" :class="{ checked: agreed }">
          <text v-if="agreed" class="check-icon">✓</text>
        </view>
        <text class="agreement-text">
          我已阅读并同意
          <text class="agreement-link" @click.stop="openAgreement('agreement')">《用户协议》</text>
          和
          <text class="agreement-link" @click.stop="openAgreement('privacy')">《隐私政策》</text>
        </text>
      </view>
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
const agreed = ref(false);
const focusKey = ref("");

let countdownTimer: ReturnType<typeof setInterval> | null = null;

onLoad((options) => {
  if (options?.redirect) {
    redirect.value = decodeURIComponent(options.redirect);
  }
});

/** 手机号输入过滤：只留数字，截断11位 */
function onPhoneInput(e: any) {
  const raw = (e.detail?.value ?? phone.value ?? "").toString();
  const v = raw.replace(/\D/g, "").slice(0, 11);
  if (v !== phone.value) phone.value = v;
}

/** 验证码输入过滤：只留数字，截断6位 */
function onCodeInput(e: any) {
  const raw = (e.detail?.value ?? code.value ?? "").toString();
  const v = raw.replace(/\D/g, "").slice(0, 6);
  if (v !== code.value) code.value = v;
}

/** 手机号格式校验 */
const isPhoneValid = computed(() => /^1[3-9]\d{9}$/.test(phone.value));

/** 是否可以登录 */
const canLogin = computed(
  () => isPhoneValid.value && /^\d{6}$/.test(code.value) && agreed.value
);

/** 切换协议勾选 */
function toggleAgree() {
  agreed.value = !agreed.value;
}

/** 打开协议/隐私页 */
function openAgreement(type: "agreement" | "privacy") {
  uni.navigateTo({ url: `/pages/agreement/agreement?type=${type}` });
}

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
  if (!agreed.value) {
    uni.showToast({ title: "请先阅读并同意用户协议和隐私政策", icon: "none" });
    return;
  }

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
  background: linear-gradient(180deg, #FFEDD9 0%, #FFF8F0 42%, #FFF8F0 100%);
  padding: 0 48rpx;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

/* ---------- 顶部品牌 ---------- */
.header {
  text-align: center;
  margin-top: 96rpx;
  margin-bottom: 72rpx;
}

.logo {
  width: 128rpx;
  height: 128rpx;
  margin: 0 auto 28rpx;
  border-radius: 36rpx;
  background: linear-gradient(135deg, #FFB25C 0%, #E8733A 100%);
  box-shadow: 0 12rpx 32rpx rgba(232, 115, 58, 0.35);
  display: flex;
  align-items: center;
  justify-content: center;
}

.logo-icon {
  font-size: 64rpx;
  line-height: 1;
}

.app-name {
  font-size: 52rpx;
  font-weight: bold;
  color: #5A3A22;
  display: block;
  margin-bottom: 14rpx;
  letter-spacing: 4rpx;
}

.app-desc {
  font-size: 28rpx;
  color: #A8907A;
  display: block;
}

/* ---------- 表单卡片 ---------- */
.form-card {
  background-color: #ffffff;
  border-radius: 32rpx;
  padding: 48rpx 40rpx 44rpx;
  box-shadow: 0 8rpx 40rpx rgba(206, 126, 58, 0.12);
}

.input-group {
  margin-bottom: 36rpx;
}

.label {
  font-size: 28rpx;
  color: #5A3A22;
  font-weight: 600;
  margin-bottom: 16rpx;
  display: block;
}

/*
 * uni-app H5 把 <input> 编译成 uni-input > .uni-input-wrapper > input 三层。
 * 必须给外壳固定高度，并让内部 wrapper/input 高度 100%，
 * 否则真实 input 高度塌陷为 0，点不进去。
 */
.input-box {
  height: 96rpx;
  background-color: #FFF8F0;
  border: 2rpx solid #F0DFCB;
  border-radius: 20rpx;
  padding: 0 28rpx;
  box-sizing: border-box;
  display: flex;
  align-items: center;
  transition: border-color 0.2s, background-color 0.2s, box-shadow 0.2s;
}

.input-box.focused {
  border-color: #E8733A;
  background-color: #ffffff;
  box-shadow: 0 0 0 6rpx rgba(232, 115, 58, 0.12);
}

.input {
  width: 100%;
  height: 100%;
  font-size: 32rpx;
  color: #333333;
  letter-spacing: 2rpx;
}

.input :deep(.uni-input-wrapper) {
  height: 100%;
  width: 100%;
  align-items: center;
}

.input :deep(.uni-input-input) {
  height: 100%;
  font-size: 32rpx;
  color: #333333;
  background: transparent;
  border: none;
  outline: none;
}

.input-ph {
  color: #C7B29C;
  font-size: 30rpx;
}

/* ---------- 验证码行 ---------- */
.code-row {
  display: flex;
  align-items: center;
  gap: 20rpx;
}

.code-box {
  flex: 1;
  min-width: 0;
}

.code-btn {
  flex-shrink: 0;
  height: 96rpx;
  line-height: 96rpx;
  padding: 0 36rpx;
  background: linear-gradient(135deg, #FFA25C 0%, #E8733A 100%);
  color: #ffffff;
  border: none;
  border-radius: 20rpx;
  font-size: 28rpx;
  font-weight: 600;
  white-space: nowrap;
}

.code-btn::after {
  border: none;
}

.code-btn[disabled] {
  background: #EDE2D6;
  color: #A8907A;
}

/* ---------- 登录按钮 ---------- */
.login-btn {
  margin-top: 12rpx;
  height: 104rpx;
  line-height: 104rpx;
  padding: 0;
  background: #E5D8C8;
  color: #ffffff;
  border: none;
  border-radius: 52rpx;
  font-size: 34rpx;
  font-weight: 600;
  letter-spacing: 8rpx;
  width: 100%;
}

.login-btn::after {
  border: none;
}

.login-btn.ready {
  background: linear-gradient(135deg, #FFB25C 0%, #E8733A 100%);
  box-shadow: 0 10rpx 28rpx rgba(232, 115, 58, 0.35);
}

.login-btn[disabled] {
  color: #ffffff;
}

/* ---------- 协议 ---------- */
.agreement-row {
  display: flex;
  align-items: flex-start;
  gap: 14rpx;
  margin-top: 32rpx;
  padding: 0 8rpx;
}

.checkbox {
  flex-shrink: 0;
  width: 34rpx;
  height: 34rpx;
  border: 2rpx solid #D8C6B2;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-top: 2rpx;
  background-color: #ffffff;
}

.checkbox.checked {
  background: linear-gradient(135deg, #FFB25C 0%, #E8733A 100%);
  border-color: #E8733A;
}

.check-icon {
  color: #ffffff;
  font-size: 22rpx;
  line-height: 1;
}

.agreement-text {
  font-size: 24rpx;
  color: #A8907A;
  line-height: 1.6;
}

.agreement-link {
  color: #E8733A;
}

/* ---------- 底部 ---------- */
.footer {
  text-align: center;
  margin-top: 48rpx;
}

.footer-text {
  font-size: 24rpx;
  color: #BFA98F;
}
</style>
