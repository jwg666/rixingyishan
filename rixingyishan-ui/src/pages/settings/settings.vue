<template>
  <view class="container">
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
    </view>

    <view class="settings-section">
      <view class="setting-item">
        <text class="setting-label">视频默认时长限制</text>
        <text class="setting-value">{{ videoDurationLimit }}秒</text>
      </view>
    </view>

    <!-- 登录/用户信息 (P0-03) -->
    <view class="settings-section">
      <view class="setting-item" @click="onAccountClick">
        <text class="setting-label">{{ isLoggedIn ? userPhone : '登录' }}</text>
        <text class="setting-action">{{ isLoggedIn ? '已登录' : '点击登录' }}</text>
      </view>
      <view v-if="isLoggedIn" class="setting-item" @click="onLogout">
        <text class="setting-label danger-text">退出登录</text>
        <text class="setting-action">清除登录状态</text>
      </view>
    </view>

    <!-- 缓存清理 (P0-02 拆分) -->
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

    <view class="about-section">
      <text class="about-title">关于</text>
      <text class="version-text">版本：v0.1.0 (MVP)</text>
      <text class="about-desc">日行一善 - 记录每天的美好瞬间</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { RecordRepository } from "@/services/RecordRepository";
import { AuthService } from "@/services/AuthService";

const wifiOnly = ref(false);
const videoDurationLimit = ref(30);
const isLoggedIn = ref(false);
const userPhone = ref("");

onMounted(() => {
  loadSettings();
  refreshAuthState();
});

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

function refreshAuthState() {
  isLoggedIn.value = AuthService.isLoggedIn();
  userPhone.value = AuthService.getUserPhone();
}

function onWifiOnlyChange(e: Event) {
  // uni-app switch change 事件的 detail.value 为 boolean
  const detail = (e as unknown as { detail: { value: boolean } }).detail;
  wifiOnly.value = detail.value;
  try {
    uni.setStorageSync("settings_wifi_only", String(wifiOnly.value));
  } catch (e) {
    console.error("Failed to save wifi only setting", e);
  }
}

/** 点击登录/已登录区域 */
function onAccountClick() {
  if (isLoggedIn.value) {
    // 已登录，不做任何操作（或可跳转用户详情）
    return;
  }
  uni.navigateTo({
    url: "/pages/login/login",
  });
}

/** 退出登录 */
function onLogout() {
  uni.showModal({
    title: "确认退出",
    content: "退出后需要重新登录才能同步数据，确定退出吗？",
    success: (res) => {
      if (res.confirm) {
        AuthService.logout();
        refreshAuthState();
        uni.showToast({ title: "已退出登录", icon: "success" });
      }
    },
  });
}

/**
 * 清理缓存（P0-02）— 仅清理上传任务队列和临时媒体缓存，不影响记录
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
 * 删除所有本地记录（P0-02）— 危险操作，强二次确认 + 红色警告
 */
function deleteAllRecords() {
  uni.showModal({
    title: "⚠️ 危险操作",
    content: "这将永久删除所有本地记录和上传任务，此操作不可恢复！确定要继续吗？",
    confirmColor: "#ff4d4f",
    success: (res) => {
      if (res.confirm) {
        // 二次确认
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
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 20rpx;
}

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
</style>
