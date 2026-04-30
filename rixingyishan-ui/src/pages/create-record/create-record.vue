<template>
  <view class="container">
    <view class="form-section">
      <view class="input-group">
        <text class="label">标题（可选）</text>
        <input
          class="input"
          v-model="formData.title"
          placeholder="输入标题"
          maxlength="50"
        />
      </view>

      <view class="input-group">
        <text class="label">内容 *</text>
        <textarea
          class="textarea"
          v-model="formData.content"
          placeholder="记录今天的好事..."
          maxlength="500"
        />
      </view>

      <view class="input-group">
        <text class="label">标签</text>
        <view class="tags-input">
          <view v-for="(tag, index) in formData.tags" :key="index" class="tag">
            <text class="tag-text">{{ tag }}</text>
            <text class="tag-remove" @click="removeTag(index)">×</text>
          </view>
          <input
            class="tag-input"
            v-model="newTag"
            placeholder="输入标签后按回车"
            @confirm="addTag"
          />
        </view>
      </view>
    </view>

    <view class="media-section">
      <text class="section-title">媒体</text>
      <view class="media-actions">
        <button class="action-btn" @click="takePhoto">拍照</button>
        <button class="action-btn" @click="recordVideo">录像</button>
        <button class="action-btn" @click="chooseFromAlbum">相册</button>
      </view>

      <view v-if="formData.media.length > 0" class="media-preview">
        <view v-for="(media, index) in formData.media" :key="index" class="media-item">
          <image
            v-if="media.mimeType.startsWith('image')"
            :src="media.localPath || ''"
            class="media-thumb"
            mode="aspectFill"
          />
          <view v-else class="media-thumb video-thumb">
            <text class="video-icon">▶</text>
          </view>
          <text class="remove-media" @click="removeMedia(index)">删除</text>
        </view>
      </view>
    </view>

    <view class="submit-section">
      <button class="submit-btn" @click="submitRecord" :disabled="isSubmitting">
        {{ isSubmitting ? "保存中..." : "保存记录" }}
      </button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive } from "vue";
import { MediaCaptureService } from "@/services/MediaCaptureService";
import { MediaValidationService } from "@/services/MediaValidationService";
import { RecordRepository } from "@/services/RecordRepository";
import { UploadQueueService } from "@/services/UploadQueueService";
import type { GoodDeedRecord, MediaItem } from "@/types";

const formData = reactive<{
  title: string;
  content: string;
  tags: string[];
  media: MediaItem[];
}>({
  title: "",
  content: "",
  tags: [],
  media: []
});

const newTag = ref("");
const isSubmitting = ref(false);

function addTag() {
  const tag = newTag.value.trim();
  if (tag && !formData.tags.includes(tag)) {
    formData.tags.push(tag);
  }
  newTag.value = "";
}

function removeTag(index: number) {
  formData.tags.splice(index, 1);
}

async function takePhoto() {
  try {
    const result = await MediaCaptureService.takePhoto();
    const validation = MediaValidationService.validateMedia(result.media, result.type);
    
    if (validation.valid) {
      formData.media.push(result.media);
    } else {
      uni.showToast({ title: validation.error || "验证失败", icon: "none" });
    }
  } catch (error: any) {
    if (error.errMsg && !error.errMsg.includes("cancel")) {
      uni.showToast({ title: "拍照失败", icon: "none" });
    }
  }
}

async function recordVideo() {
  try {
    const result = await MediaCaptureService.recordVideo();
    const validation = MediaValidationService.validateMedia(result.media, result.type);
    
    if (validation.valid) {
      formData.media.push(result.media);
    } else {
      uni.showToast({ title: validation.error || "验证失败", icon: "none" });
    }
  } catch (error: any) {
    if (error.errMsg && !error.errMsg.includes("cancel")) {
      uni.showToast({ title: "录像失败", icon: "none" });
    }
  }
}

async function chooseFromAlbum() {
  try {
    const result = await MediaCaptureService.chooseFromAlbum();
    const validation = MediaValidationService.validateMedia(result.media, result.type);
    
    if (validation.valid) {
      formData.media.push(result.media);
    } else {
      uni.showToast({ title: validation.error || "验证失败", icon: "none" });
    }
  } catch (error: any) {
    if (error.errMsg && !error.errMsg.includes("cancel")) {
      uni.showToast({ title: "选择失败", icon: "none" });
    }
  }
}

function removeMedia(index: number) {
  formData.media.splice(index, 1);
}

async function submitRecord() {
  if (!formData.content.trim()) {
    uni.showToast({ title: "请输入内容", icon: "none" });
    return;
  }

  isSubmitting.value = true;

  try {
    const now = new Date();
    const dayKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    
    const record: GoodDeedRecord = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2),
      type: formData.media.length === 0 ? "text" : formData.media[0].mimeType.startsWith("video") ? "video" : "photo",
      title: formData.title || undefined,
      content: formData.content,
      media: formData.media,
      dayKey,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      status: "draft",
      tags: formData.tags.length > 0 ? formData.tags : undefined
    };

    RecordRepository.insert(record);

    if (formData.media.length > 0) {
      record.status = "queued";
      RecordRepository.update(record);
      
      formData.media.forEach((media, index) => {
        if (media.localPath) {
          UploadQueueService.enqueue(record.id, index, media.localPath);
        }
      });
    }

    uni.showToast({ title: "保存成功", icon: "success" });
    
    setTimeout(() => {
      uni.navigateBack();
    }, 1000);
  } catch (error) {
    uni.showToast({ title: "保存失败", icon: "none" });
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #f5f5f5;
  padding: 20rpx;
}

.form-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
}

.input-group {
  margin-bottom: 24rpx;
}

.label {
  font-size: 28rpx;
  color: #333333;
  margin-bottom: 12rpx;
  display: block;
}

.input {
  border: 1rpx solid #e8e8e8;
  border-radius: 8rpx;
  padding: 16rpx;
  font-size: 28rpx;
  background-color: #fafafa;
}

.textarea {
  border: 1rpx solid #e8e8e8;
  border-radius: 8rpx;
  padding: 16rpx;
  font-size: 28rpx;
  background-color: #fafafa;
  min-height: 200rpx;
  width: 100%;
}

.tags-input {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  align-items: center;
}

.tag {
  background-color: #e6f7ff;
  border-radius: 8rpx;
  padding: 8rpx 16rpx;
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.tag-text {
  font-size: 24rpx;
  color: #1890ff;
}

.tag-remove {
  font-size: 28rpx;
  color: #1890ff;
  padding: 0 4rpx;
}

.tag-input {
  flex: 1;
  min-width: 200rpx;
  font-size: 24rpx;
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

.media-actions {
  display: flex;
  gap: 16rpx;
  margin-bottom: 20rpx;
}

.action-btn {
  flex: 1;
  background-color: #f0f0f0;
  border: none;
  border-radius: 8rpx;
  font-size: 26rpx;
  color: #666666;
  padding: 16rpx 0;
}

.media-preview {
  display: flex;
  flex-wrap: wrap;
  gap: 16rpx;
}

.media-item {
  width: 200rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.media-thumb {
  width: 200rpx;
  height: 200rpx;
  border-radius: 8rpx;
  background-color: #f0f0f0;
}

.video-thumb {
  display: flex;
  align-items: center;
  justify-content: center;
}

.video-icon {
  font-size: 48rpx;
  color: #999999;
}

.remove-media {
  font-size: 24rpx;
  color: #ff4d4f;
  margin-top: 8rpx;
}

.submit-section {
  padding: 20rpx 0;
}

.submit-btn {
  background-color: #1890ff;
  color: #ffffff;
  border: none;
  border-radius: 12rpx;
  font-size: 32rpx;
  padding: 20rpx 0;
}

.submit-btn[disabled] {
  background-color: #cccccc;
}
</style>
