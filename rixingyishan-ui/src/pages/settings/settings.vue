<template>
  <view class="container">
    <!-- 用户资料区（已登录时） -->
    <view v-if="isLoggedIn" class="profile-section">
      <view class="profile-card">
        <view class="profile-avatar" :style="{ backgroundColor: avatarColor }" @click="editNickname">
          <text class="avatar-text">{{ nicknameInitial }}</text>
        </view>
        <view class="profile-info">
          <text class="profile-nickname" @click="editNickname">{{ userProfile?.nickname || '点击设置昵称' }}</text>
          <text class="profile-phone">{{ maskedPhone }}</text>
          <view class="profile-merit">
            <text class="profile-merit-text">功德 {{ userProfile?.totalMerit || 0 }} ✨</text>
          </view>
        </view>
      </view>
    </view>

    <!-- 未登录 -->
    <view v-else class="settings-section">
      <view class="setting-item" @click="goToLogin">
        <text class="setting-label">登录</text>
        <text class="setting-action">点击登录</text>
      </view>
    </view>

    <!-- 设置项 -->
    <view class="settings-section">
      <view class="setting-item">
        <text class="setting-label">仅 Wi-Fi 上传</text>
        <switch
          :checked="wifiOnly"
          @change="onWifiOnlyChange"
          color="#E8733A"
        />
      </view>
      <text class="setting-hint">开启后仅在连接 Wi-Fi 时自动上传媒体</text>

      <view class="setting-item">
        <text class="setting-label">视频默认时长限制</text>
        <text class="setting-value">{{ videoDurationLimit }}秒</text>
      </view>

      <!-- 排名可见性开关 -->
      <view v-if="isLoggedIn" class="setting-item">
        <text class="setting-label">排行榜可见</text>
        <switch
          :checked="showInRanking"
          @change="onShowInRankingChange"
          color="#E8733A"
        />
      </view>
    </view>

    <!-- 已登录操作 -->
    <view v-if="isLoggedIn" class="settings-section">
      <view class="setting-item" @click="editNickname">
        <text class="setting-label">修改昵称</text>
        <text class="setting-action">→</text>
      </view>
      <view class="setting-item" @click="onLogout">
        <text class="setting-label danger-text">退出登录</text>
        <text class="setting-action danger-text">清除登录状态</text>
      </view>
    </view>

    <!-- 缓存清理 -->
    <view class="settings-section">
      <view class="setting-item" @click="clearCache">
        <text class="setting-label">清理缓存</text>
        <text class="setting-action">清理上传队列和临时缓存</text>
      </view>
      <view class="setting-item" @click="deleteAllRecords">
        <text class="setting-label danger-text">删除所有本地记录</text>
        <text class="setting-action danger-text">不可恢复，请谨慎操作</text>
      </view>
    </view>

    <view class="settings-section">
      <view class="setting-item" @click="exportData">
        <text class="setting-label">导出数据</text>
        <text class="setting-action">导出所有记录为 JSON</text>
      </view>
    </view>

    <!-- 协议入口 (P1-06) -->
    <view class="settings-section">
      <view class="setting-item" @click="openUserAgreement">
        <text class="setting-label">用户协议</text>
        <text class="setting-action">→</text>
      </view>
      <view class="setting-item" @click="openPrivacyPolicy">
        <text class="setting-label">隐私政策</text>
        <text class="setting-action">→</text>
      </view>
    </view>

    <view class="about-section">
      <text class="about-title">关于</text>
      <text class="version-text">版本：v0.2.0 (P1)</text>
      <text class="about-desc">日行一善 - 记录每天的美好瞬间</text>
    </view>

    <!-- 修改昵称弹窗 -->
    <view v-if="showNicknameModal" class="modal-mask" @click="closeNicknameModal">
      <view class="modal-content" @click.stop>
        <text class="modal-title">修改昵称</text>
        <input
          class="modal-input"
          v-model="newNickname"
          placeholder="输入新昵称"
          maxlength="20"
        />
        <view class="modal-buttons">
          <button class="modal-btn modal-btn-cancel" @click="closeNicknameModal">取消</button>
          <button class="modal-btn modal-btn-confirm" @click="saveNickname">保存</button>
        </view>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { onShow } from "@dcloudio/uni-app";
import { RecordRepository } from "@/services/RecordRepository";
import { AuthService } from "@/services/AuthService";
import { MeritService, getAvatarColor, getNicknameInitial, maskPhone } from "@/services/MeritService";
import type { UserProfile } from "@/types";

const wifiOnly = ref(false);
const videoDurationLimit = ref(30);
const isLoggedIn = ref(false);
const showInRanking = ref(true);
const userProfile = ref<UserProfile | null>(null);
const showNicknameModal = ref(false);
const newNickname = ref("");
const isSavingNickname = ref(false);

const avatarColor = computed(() => {
  return getAvatarColor(userProfile.value?.avatarSeed || "");
});

const nicknameInitial = computed(() => {
  return getNicknameInitial(userProfile.value?.nickname);
});

const maskedPhone = computed(() => {
  return maskPhone(AuthService.getUserPhone());
});

onMounted(() => {
  loadSettings();
  refreshAuthState();
});

onShow(() => {
  refreshAuthState();
});

async function refreshAuthState() {
  isLoggedIn.value = AuthService.isLoggedIn();
  if (isLoggedIn.value) {
    await loadUserProfile();
  }
}

async function loadUserProfile() {
  try {
    userProfile.value = await MeritService.getProfile();
    if (userProfile.value) {
      showInRanking.value = userProfile.value.showInRanking;
    }
  } catch {
    // 静默失败
  }
}

function loadSettings() {
  try {
    const savedWifiOnly = uni.getStorageSync("settings_wifi_only");
    if (savedWifiOnly !== "") {
      wifiOnly.value = savedWifiOnly === "true";
    }

    const savedDuration = uni.getStorageSync("settings_video_duration");
    if (savedDuration) {
      videoDurationLimit.value = parseInt(savedDuration, 10);
    }
  } catch (e) {
    console.error("Failed to load settings", e);
  }
}

function onWifiOnlyChange(e: Event) {
  const detail = (e as unknown as { detail: { value: boolean } }).detail;
  wifiOnly.value = detail.value;
  try {
    uni.setStorageSync("settings_wifi_only", String(wifiOnly.value));
  } catch (e) {
    console.error("Failed to save wifi only setting", e);
  }
}

async function onShowInRankingChange(e: Event) {
  const detail = (e as unknown as { detail: { value: boolean } }).detail;
  showInRanking.value = detail.value;
  try {
    await MeritService.updateShowInRanking(showInRanking.value);
  } catch {
    uni.showToast({ title: "设置失败", icon: "none" });
    showInRanking.value = !detail.value;
  }
}

function editNickname() {
  newNickname.value = userProfile.value?.nickname || "";
  showNicknameModal.value = true;
}

function closeNicknameModal() {
  showNicknameModal.value = false;
}

async function saveNickname() {
  const nickname = newNickname.value.trim();
  if (!nickname) {
    uni.showToast({ title: "昵称不能为空", icon: "none" });
    return;
  }

  isSavingNickname.value = true;
  try {
    await MeritService.updateNickname(nickname);
    if (userProfile.value) {
      userProfile.value.nickname = nickname;
    }
    uni.showToast({ title: "昵称已更新", icon: "success" });
    closeNicknameModal();
  } catch {
    uni.showToast({ title: "更新失败", icon: "none" });
  } finally {
    isSavingNickname.value = false;
  }
}

/** 退出登录 — 调用后端API + 清除本地token + 暂停上传 + 标记 needsAccountBind */
function onLogout() {
  uni.showModal({
    title: "确认退出",
    content: "退出后需要重新登录才能同步数据，确定退出吗？",
    success: async (res) => {
      if (res.confirm) {
        // 标记未同步记录 needsAccountBind
        const records = RecordRepository.getAll();
        records.forEach((r) => {
          if (r.status !== "synced" && !r.userId) {
            (r as any).needsAccountBind = true;
            r.updatedAt = new Date().toISOString();
            RecordRepository.update(r);
          }
        });

        // 调用后端退出API + 清除token
        await AuthService.logout();
        refreshAuthState();
        uni.showToast({ title: "已退出登录", icon: "success" });
      }
    },
  });
}

function goToLogin() {
  uni.navigateTo({
    url: "/pages/login/login",
  });
}

/**
 * 清理缓存（P0-02）
 */
function clearCache() {
  uni.showModal({
    title: "清理缓存",
    content: "将清理上传任务队列和临时媒体缓存，不会删除您的记录。确定继续吗？",
    success: (res) => {
      if (res.confirm) {
        try {
          RecordRepository.clearUploadTasks();
          RecordRepository.clearTempMedia();
          RecordRepository.clearCompletedUploadTasks();
          uni.showToast({ title: "缓存已清理", icon: "success" });
        } catch (e) {
          uni.showToast({ title: "清理失败", icon: "none" });
        }
      }
    },
  });
}

/**
 * 删除所有本地记录（P0-02）
 */
function deleteAllRecords() {
  uni.showModal({
    title: "⚠️ 危险操作",
    content: "这将永久删除所有本地记录和上传任务，此操作不可恢复！确定要继续吗？",
    confirmColor: "#ff4d4f",
    success: (res) => {
      if (res.confirm) {
        uni.showModal({
          title: "再次确认",
          content: "真的要删除所有记录吗？此操作无法撤销！",
          confirmColor: "#ff4d4f",
          success: (res2) => {
            if (res2.confirm) {
              try {
                RecordRepository.clearAllRecords();
                uni.showToast({ title: "所有记录已删除", icon: "none" });
              } catch (e) {
                uni.showToast({ title: "删除失败", icon: "none" });
              }
            }
          },
        });
      }
    },
  });
}

function exportData() {
  try {
    const records = RecordRepository.getAll();
    const data = JSON.stringify(records, null, 2);

    uni.setClipboardData({
      data,
      success: () => {
        uni.showToast({ title: "数据已复制到剪贴板", icon: "success" });
      },
    });
  } catch (e) {
    uni.showToast({ title: "导出失败", icon: "none" });
  }
}

/** 协议入口 (P1-06) — 跳转协议页 */
function openUserAgreement() {
  uni.navigateTo({ url: "/pages/agreement/agreement?type=agreement" });
}

function openPrivacyPolicy() {
  uni.navigateTo({ url: "/pages/agreement/agreement?type=privacy" });
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 20rpx;
  padding-bottom: 40rpx;
}

/* 用户资料区 */
.profile-section {
  margin-bottom: 20rpx;
}

.profile-card {
  background: linear-gradient(135deg, #FFF0E5 0%, #FFE4CC 100%);
  border-radius: 16rpx;
  padding: 24rpx;
  display: flex;
  align-items: center;
  gap: 20rpx;
  box-shadow: 0 4rpx 12rpx rgba(232, 115, 58, 0.1);
}

.profile-avatar {
  width: 96rpx;
  height: 96rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.avatar-text {
  font-size: 40rpx;
  color: #ffffff;
  font-weight: bold;
}

.profile-info {
  flex: 1;
  min-width: 0;
}

.profile-nickname {
  font-size: 32rpx;
  font-weight: bold;
  color: #333333;
  display: block;
  margin-bottom: 4rpx;
}

.profile-phone {
  font-size: 24rpx;
  color: #8B7E74;
  display: block;
  margin-bottom: 8rpx;
}

.profile-merit {
  display: inline-flex;
}

.profile-merit-text {
  font-size: 24rpx;
  color: #FFD700;
  font-weight: 500;
}

/* 设置项 */
.settings-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  margin-bottom: 20rpx;
  overflow: hidden;
}

.setting-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24rpx;
  border-bottom: 1rpx solid #f0f0f0;
}

.setting-item:last-child {
  border-bottom: none;
}

.setting-label {
  font-size: 28rpx;
  color: #333333;
}

.setting-value {
  font-size: 28rpx;
  color: #E8733A;
}

.setting-action {
  font-size: 24rpx;
  color: #999999;
}

.setting-hint {
  font-size: 24rpx;
  color: #999999;
  padding: 0 24rpx 16rpx;
  display: block;
}

.danger-text {
  color: #ff4d4f;
}

.about-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  text-align: center;
}

.about-title {
  font-size: 28rpx;
  font-weight: bold;
  color: #333333;
  margin-bottom: 16rpx;
  display: block;
}

.version-text {
  font-size: 24rpx;
  color: #999999;
  margin-bottom: 8rpx;
  display: block;
}

.about-desc {
  font-size: 24rpx;
  color: #666666;
}

/* 修改昵称弹窗 */
.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 32rpx;
  width: 80%;
  max-width: 600rpx;
}

.modal-title {
  font-size: 32rpx;
  font-weight: bold;
  color: #333333;
  margin-bottom: 24rpx;
  display: block;
  text-align: center;
}

.modal-input {
  border: 1rpx solid #e8e8e8;
  border-radius: 12rpx;
  padding: 16rpx;
  font-size: 28rpx;
  background-color: #FFF8F0;
  margin-bottom: 24rpx;
}

.modal-buttons {
  display: flex;
  gap: 16rpx;
}

.modal-btn {
  flex: 1;
  border-radius: 12rpx;
  font-size: 28rpx;
  padding: 16rpx 0;
  border: none;
}

.modal-btn-cancel {
  background-color: #f0f0f0;
  color: #666666;
}

.modal-btn-confirm {
  background-color: #E8733A;
  color: #ffffff;
}
</style>
