<template>
  <view class="container" v-if="record">
    <view class="header-section">
      <view class="header-row">
        <text class="record-type">{{ getRecordTypeText(record.type) }}</text>
        <text class="record-status" :class="'status-' + record.status">
          {{ getStatusText(record.status) }}
        </text>
      </view>
      <text v-if="record.title" class="record-title">{{ record.title }}</text>
      <text class="record-time">{{ formatFullTime(record.createdAt) }}</text>
      <text v-if="record.location" class="record-location">
        📍 {{ record.location.name || `${record.location.lat}, ${record.location.lng}` }}
      </text>
    </view>

    <view class="content-section">
      <text class="content-text">{{ record.content }}</text>
    </view>

    <view v-if="record.tags && record.tags.length > 0" class="tags-section">
      <view v-for="(tag, index) in record.tags" :key="index" class="tag">
        <text class="tag-text">#{{ tag }}</text>
      </view>
    </view>

    <view v-if="record.media.length > 0" class="media-section">
      <text class="section-title">媒体</text>
      <view class="media-grid">
        <view
          v-for="(media, index) in record.media"
          :key="index"
          class="media-item"
          @click="previewMedia(index)"
        >
          <image
            v-if="media.mimeType.startsWith('image')"
            :src="media.remoteUrl || media.localPath || ''"
            class="media-image"
            mode="aspectFill"
          />
          <view v-else class="media-video">
            <video
              :src="media.remoteUrl || media.localPath || ''"
              class="video-player"
              controls
            />
          </view>
          <text v-if="media.remoteUrl" class="media-synced">已上传</text>
          <text v-else class="media-pending">未上传</text>
        </view>
      </view>
    </view>

    <view v-if="record.status === 'failed'" class="retry-section">
      <button class="retry-btn" @click="retryUpload">重试上传</button>
      <text v-if="record.failReason" class="fail-reason">失败原因：{{ record.failReason }}</text>
    </view>

    <view class="actions-section">
      <button class="delete-btn" @click="confirmDelete">删除记录</button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, onMounted } from "vue";
import { onLoad } from "@dcloudio/uni-app";
import { RecordRepository } from "@/services/RecordRepository";
import { UploadQueueService } from "@/services/UploadQueueService";
import type { GoodDeedRecord } from "@/types";

const recordId = ref("");
const record = ref<GoodDeedRecord | null>(null);

onLoad((options) => {
  if (options?.id) {
    recordId.value = options.id;
  }
});

onMounted(() => {
  loadRecord();
});

function loadRecord() {
  const found = RecordRepository.getById(recordId.value);
  if (found) {
    record.value = found;
  } else {
    uni.showToast({ title: "记录不存在", icon: "none" });
    setTimeout(() => uni.navigateBack(), 1000);
  }
}

function previewMedia(index: number) {
  if (!record.value) return;
  const media = record.value.media[index];
  const urls = record.value.media
    .map((m) => m.remoteUrl || m.localPath)
    .filter(Boolean) as string[];
  
  if (urls.length > 0) {
    uni.previewImage({
      urls,
      current: urls[index]
    });
  }
}

function retryUpload() {
  if (!record.value) return;
  
  UploadQueueService.retryRecordTasks(record.value.id);
  uni.showToast({ title: "开始重试上传", icon: "none" });
  
  setTimeout(() => {
    loadRecord();
  }, 1000);
}

function confirmDelete() {
  uni.showModal({
    title: "确认删除",
    content: "删除后无法恢复，确定要删除这条记录吗？",
    success: (res) => {
      if (res.confirm && record.value) {
        RecordRepository.delete(record.value.id);
        uni.showToast({ title: "已删除", icon: "success" });
        setTimeout(() => uni.navigateBack(), 1000);
      }
    }
  });
}

function getRecordTypeText(type: string): string {
  const map: Record<string, string> = {
    photo: "图片",
    video: "视频",
    text: "文字"
  };
  return map[type] || type;
}

function getStatusText(status: string): string {
  const map: Record<string, string> = {
    draft: "草稿",
    queued: "等待上传",
    uploading: "上传中",
    synced: "已同步",
    failed: "失败"
  };
  return map[status] || status;
}

function formatFullTime(isoString: string): string {
  const date = new Date(isoString);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${year}-${month}-${day} ${hours}:${minutes}`;
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #f5f5f5;
  padding: 20rpx;
}

.header-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
}

.header-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12rpx;
}

.record-type {
  font-size: 28rpx;
  color: #666666;
}

.record-status {
  font-size: 24rpx;
  padding: 4rpx 12rpx;
  border-radius: 8rpx;
}

.status-draft {
  background-color: #f0f0f0;
  color: #999999;
}

.status-queued,
.status-uploading {
  background-color: #e6f7ff;
  color: #1890ff;
}

.status-synced {
  background-color: #f6ffed;
  color: #52c41a;
}

.status-failed {
  background-color: #fff1f0;
  color: #ff4d4f;
}

.record-title {
  font-size: 36rpx;
  font-weight: bold;
  color: #333333;
  margin-bottom: 8rpx;
  display: block;
}

.record-time {
  font-size: 24rpx;
  color: #999999;
  display: block;
}

.record-location {
  font-size: 24rpx;
  color: #1890ff;
  margin-top: 8rpx;
  display: block;
}

.content-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
}

.content-text {
  font-size: 30rpx;
  color: #333333;
  line-height: 1.6;
}

.tags-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
}

.tag {
  background-color: #f0f0f0;
  border-radius: 8rpx;
  padding: 8rpx 16rpx;
}

.tag-text {
  font-size: 24rpx;
  color: #666666;
}

.media-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
}

.section-title {
  font-size: 28rpx;
  font-weight: bold;
  color: #333333;
  margin-bottom: 16rpx;
  display: block;
}

.media-grid {
  display: flex;
  flex-direction: column;
  gap: 16rpx;
}

.media-item {
  position: relative;
}

.media-image {
  width: 100%;
  height: 400rpx;
  border-radius: 12rpx;
}

.media-video {
  width: 100%;
}

.video-player {
  width: 100%;
  height: 400rpx;
  border-radius: 12rpx;
}

.media-synced {
  position: absolute;
  top: 12rpx;
  right: 12rpx;
  background-color: rgba(82, 196, 26, 0.8);
  color: #ffffff;
  font-size: 22rpx;
  padding: 4rpx 12rpx;
  border-radius: 8rpx;
}

.media-pending {
  position: absolute;
  top: 12rpx;
  right: 12rpx;
  background-color: rgba(153, 153, 153, 0.8);
  color: #ffffff;
  font-size: 22rpx;
  padding: 4rpx 12rpx;
  border-radius: 8rpx;
}

.retry-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
  text-align: center;
}

.retry-btn {
  background-color: #faad14;
  color: #ffffff;
  border: none;
  border-radius: 12rpx;
  font-size: 30rpx;
  padding: 16rpx 0;
  margin-bottom: 12rpx;
}

.fail-reason {
  font-size: 24rpx;
  color: #999999;
}

.actions-section {
  padding: 20rpx 0;
}

.delete-btn {
  background-color: #ff4d4f;
  color: #ffffff;
  border: none;
  border-radius: 12rpx;
  font-size: 30rpx;
  padding: 20rpx 0;
}
</style>
