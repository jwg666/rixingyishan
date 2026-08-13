<template>
  <view class="container">
    <!-- 记录归属日期提示 -->
    <view class="date-banner" :class="{ 'date-banner-other': !isToday }">
      <text class="date-banner-icon">📅</text>
      <text class="date-banner-text">{{ isToday ? "记录日期：今天" : "记录日期：" + targetDayKey }}</text>
    </view>

    <view class="form-section">
      <view class="input-group">
        <text class="label">内容 *</text>
        <textarea
          class="textarea"
          v-model="formData.content"
          placeholder="记录今天的好事..."
          maxlength="500"
          @input="onContentInput"
        />
      </view>

      <!-- 功德标签选择器 -->
      <view class="input-group">
        <text class="label">功德标签</text>
        <scroll-view scroll-x class="tags-scroll">
          <view class="tags-pill-list">
            <view
              v-for="tag in meritTags"
              :key="tag.id"
              class="tag-pill"
              :class="{ 'tag-pill-selected': selectedTagId === tag.id }"
              @click="selectTag(tag)"
            >
              <text class="tag-pill-icon">{{ tag.icon }}</text>
              <text class="tag-pill-name">{{ tag.name }}</text>
              <text class="tag-pill-merit">+{{ tag.meritValue }}</text>
            </view>
          </view>
        </scroll-view>
        <view v-if="matchHint" class="match-hint">
          <text class="match-hint-text">🤖 {{ matchHint }}</text>
        </view>
      </view>

      <!-- 旧版手动标签保留 -->
      <view class="input-group">
        <text class="label">自定义标签</text>
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

    <!-- 功德预览 -->
    <view v-if="currentMeritValue > 0" class="merit-preview">
      <text class="merit-preview-text">本次功德 +{{ currentMeritValue }} ✨</text>
    </view>

    <view class="submit-section">
      <button class="submit-btn" @click="submitRecord" :disabled="isSubmitting">
        {{ isSubmitting ? "保存中..." : "保存记录" }}
      </button>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from "vue";
import { onLoad } from "@dcloudio/uni-app";
import { MediaCaptureService } from "@/services/MediaCaptureService";
import { MediaValidationService } from "@/services/MediaValidationService";
import { RecordRepository } from "@/services/RecordRepository";
import { UploadQueueService } from "@/services/UploadQueueService";
import { MeritService } from "@/services/MeritService";
import { AuthService } from "@/services/AuthService";
import { request } from "@/services/request";
import type { GoodDeedRecord, MediaItem, MeritTag } from "@/types";

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

// 功德标签相关
const meritTags = ref<MeritTag[]>([]);
const selectedTagId = ref<number | null>(null);
const matchHint = ref("");

// 防抖定时器
let matchDebounceTimer: ReturnType<typeof setTimeout> | null = null;

// 记录归属日期：从首页日历选中日传入，缺省为今天
function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
const targetDayKey = ref(todayKey());
const isToday = computed(() => targetDayKey.value === todayKey());

onLoad((options) => {
  const dayKey = options?.dayKey;
  // 校验 YYYY-MM-DD 格式，防止脏参数
  if (dayKey && /^\d{4}-\d{2}-\d{2}$/.test(dayKey)) {
    targetDayKey.value = dayKey;
  }
});

const currentMeritValue = computed(() => {
  if (!selectedTagId.value) return 0;
  const tag = meritTags.value.find((t) => t.id === selectedTagId.value);
  return tag ? tag.meritValue : 0;
});

onMounted(() => {
  loadMeritTags();
});

async function loadMeritTags() {
  try {
    meritTags.value = await MeritService.getTags();
  } catch {
    // 静默失败
  }
}

function selectTag(tag: MeritTag) {
  if (selectedTagId.value === tag.id) {
    selectedTagId.value = null;
  } else {
    selectedTagId.value = tag.id;
  }
}

/** 内容输入防抖智能匹配 */
function onContentInput() {
  if (matchDebounceTimer) {
    clearTimeout(matchDebounceTimer);
  }
  matchDebounceTimer = setTimeout(async () => {
    const content = formData.content.trim();
    if (!content) {
      matchHint.value = "";
      return;
    }
    try {
      const match = await MeritService.matchTag(content);
      if (match && match.recommendedTagId) {
        const tag = meritTags.value.find((t) => t.id === match.recommendedTagId);
        if (tag) {
          matchHint.value = `推荐标签：${tag.icon} ${tag.name}`;
          // 自动选中推荐标签（如果用户未手动选择）
          if (!selectedTagId.value) {
            selectedTagId.value = tag.id;
          }
        }
      } else {
        matchHint.value = "";
      }
    } catch {
      matchHint.value = "";
    }
  }, 300);
}

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
    // 使用日历选中日期（onLoad 已接收），而非当前日期
    const dayKey = targetDayKey.value;
    
    // P0-05 修复：扫描全部媒体 mimeType，任一包含 "video" 则 type="video"
    let recordType: "photo" | "video" | "text" = "text";
    if (formData.media.length > 0) {
      const hasVideo = formData.media.some((m) => m.mimeType.includes("video"));
      const hasImage = formData.media.some((m) => m.mimeType.startsWith("image"));
      if (hasVideo) {
        recordType = "video";
      } else if (hasImage) {
        recordType = "photo";
      }
    }

    // 标题：自动从内容前 15 个字生成
    const contentTrim = formData.content.trim();
    const autoTitle = contentTrim.length > 15 ? contentTrim.slice(0, 15) + "…" : contentTrim;

    const record: GoodDeedRecord = {
      id: Date.now().toString(36) + Math.random().toString(36).slice(2),
      type: recordType,
      title: autoTitle,
      content: formData.content,
      media: formData.media,
      dayKey,
      createdAt: now.toISOString(),
      updatedAt: now.toISOString(),
      status: "draft",
      tags: formData.tags.length > 0 ? formData.tags : undefined,
      meritTagId: selectedTagId.value || undefined,
      meritValue: currentMeritValue.value || undefined,
    };

    // 未登录时标记 needsAccountBind
    if (!AuthService.isLoggedIn()) {
      (record as any).needsAccountBind = true;
    }

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

    // 登录状态下同步到后端（纯文本记录不走上传队列，需手动同步）
    if (AuthService.isLoggedIn() && record.meritValue) {
      syncToServer(record);
    }

    uni.showToast({ title: "保存成功", icon: "success" });
    // 首次创建记录智能引导提示
    showSmartLoginTip();
    
    setTimeout(() => {
      uni.navigateBack();
    }, 1000);
  } catch (error) {
    uni.showToast({ title: "保存失败", icon: "none" });
  } finally {
    isSubmitting.value = false;
  }
}

/** 同步记录到后端（登录状态下） */
async function syncToServer(record: GoodDeedRecord) {
  try {
    // 从标签列表中找到标签名
    const tag = meritTags.value.find((t) => t.id === record.meritTagId);
    await request({
      url: "/records",
      method: "POST",
      data: {
        type: record.type,
        content: record.content,
        tag: tag?.name || "其他善行",
        meritValue: record.meritValue || 0,
        recordDate: record.dayKey,
        media: record.media.map((m) => ({
          remoteUrl: m.remoteUrl,
          objectKey: m.objectKey,
          mimeType: m.mimeType,
          size: m.sizeBytes || 0,
        })),
      },
    });
    // 同步成功，更新本地状态
    record.status = "synced";
    record.updatedAt = new Date().toISOString();
    RecordRepository.update(record);
  } catch (err) {
    // 同步失败不影响本地保存，记录保持 draft/queued 状态
    console.error("同步记录到后端失败:", err);
  }
}

/** 首次创建记录后弹出引导提示 */
function showSmartLoginTip() {
  const shown = uni.getStorageSync("smartLoginTipShown");
  if (shown) return;
  uni.setStorageSync("smartLoginTipShown", true);
  
  setTimeout(() => {
    uni.showToast({
      title: "登录可云端保存，不怕丢失",
      icon: "none",
      duration: 3000,
    });
  }, 500);
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 20rpx;
  padding-bottom: 160rpx;
}

.date-banner {
  display: flex;
  align-items: center;
  gap: 12rpx;
  background-color: #FFF0E5;
  border-radius: 12rpx;
  padding: 16rpx 24rpx;
  margin-bottom: 20rpx;
}

.date-banner-other {
  background-color: #FFE8D6;
  border: 1rpx solid #E8733A;
}

.date-banner-icon {
  font-size: 28rpx;
}

.date-banner-text {
  font-size: 26rpx;
  color: #8B5A2B;
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
  border-radius: 12rpx;
  padding: 16rpx;
  font-size: 28rpx;
  background-color: #FFF8F0;
}

.textarea {
  border: 1rpx solid #e8e8e8;
  border-radius: 12rpx;
  padding: 16rpx;
  font-size: 28rpx;
  background-color: #FFF8F0;
  min-height: 200rpx;
  width: 100%;
}

/* 功德标签选择器 */
.tags-scroll {
  white-space: nowrap;
  margin-bottom: 8rpx;
}

.tags-pill-list {
  display: flex;
  gap: 16rpx;
  padding: 8rpx 0;
}

.tag-pill {
  display: inline-flex;
  align-items: center;
  gap: 8rpx;
  padding: 12rpx 20rpx;
  border-radius: 32rpx;
  background-color: #FFF0E5;
  flex-shrink: 0;
}

.tag-pill-selected {
  background-color: #E8733A;
}

.tag-pill-icon {
  font-size: 28rpx;
}

.tag-pill-name {
  font-size: 24rpx;
  color: #E8733A;
}

.tag-pill-selected .tag-pill-name {
  color: #ffffff;
}

.tag-pill-merit {
  font-size: 22rpx;
  color: #FFD700;
  font-weight: 500;
}

.tag-pill-selected .tag-pill-merit {
  color: #FFD700;
}

.match-hint {
  margin-top: 8rpx;
}

.match-hint-text {
  font-size: 24rpx;
  color: #8B7E74;
}

/* 自定义标签 */
.tags-input {
  display: flex;
  flex-wrap: wrap;
  gap: 12rpx;
  align-items: center;
}

.tag {
  background-color: #FFF0E5;
  border-radius: 8rpx;
  padding: 8rpx 16rpx;
  display: flex;
  align-items: center;
  gap: 8rpx;
}

.tag-text {
  font-size: 24rpx;
  color: #E8733A;
}

.tag-remove {
  font-size: 28rpx;
  color: #E8733A;
  padding: 0 4rpx;
}

.tag-input {
  flex: 1;
  min-width: 200rpx;
  font-size: 24rpx;
}

/* 媒体 */
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
  background-color: #FFF0E5;
  border: none;
  border-radius: 12rpx;
  font-size: 26rpx;
  color: #E8733A;
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
  border-radius: 12rpx;
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

/* 功德预览 */
.merit-preview {
  position: fixed;
  bottom: 140rpx;
  left: 20rpx;
  right: 20rpx;
  background: linear-gradient(135deg, #FFF0E5 0%, #FFE4CC 100%);
  border-radius: 12rpx;
  padding: 20rpx;
  text-align: center;
}

.merit-preview-text {
  font-size: 32rpx;
  color: #FFD700;
  font-weight: bold;
}

/* 提交 */
.submit-section {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 20rpx;
  background-color: #FFF8F0;
}

.submit-btn {
  background-color: #E8733A;
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
