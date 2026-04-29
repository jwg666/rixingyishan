<template>
  <view class="container">
    <view class="settings-section">
      <view class="setting-item">
        <text class="setting-label">仅 Wi-Fi 上传</text>
        <switch
          :checked="wifiOnly"
          @change="onWifiOnlyChange"
          color="#1890ff"
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

    <view class="settings-section">
      <view class="setting-item" @click="clearCache">
        <text class="setting-label">清除缓存</text>
        <text class="setting-action">清除本地缓存数据</text>
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

const wifiOnly = ref(false);
const videoDurationLimit = ref(30);

onMounted(() => {
  loadSettings();
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

function onWifiOnlyChange(e: any) {
  wifiOnly.value = e.detail.value;
  try {
    uni.setStorageSync("settings_wifi_only", String(wifiOnly.value));
  } catch (e) {
    console.error("Failed to save wifi only setting", e);
  }
}

function clearCache() {
  uni.showModal({
    title: "确认清除",
    content: "这将清除所有缓存数据，但不会删除您的记录。确定继续吗？",
    success: (res) => {
      if (res.confirm) {
        try {
          uni.clearStorageSync();
          uni.showToast({ title: "缓存已清除", icon: "success" });
        } catch (e) {
          uni.showToast({ title: "清除失败", icon: "none" });
        }
      }
    }
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
      }
    });
  } catch (e) {
    uni.showToast({ title: "导出失败", icon: "none" });
  }
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #f5f5f5;
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
  color: #1890ff;
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
