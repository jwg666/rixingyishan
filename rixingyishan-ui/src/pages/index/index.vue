<template>
  <view class="container">
    <!-- 功德展示区 -->
    <view class="merit-card" @click="goToRanking">
      <view v-if="isLoggedIn" class="merit-content">
        <view class="merit-main">
          <text class="merit-icon">✨</text>
          <text class="merit-number">{{ totalMerit }}</text>
          <text class="merit-label">功德</text>
        </view>
        <view class="merit-daily">
          <text class="daily-text">今日 +{{ dailyMerit }}</text>
        </view>
      </view>
      <view v-else class="merit-login-hint" @click.stop="goToLogin">
        <text class="merit-icon">✨</text>
        <text class="login-hint-text">登录后查看功德</text>
        <text class="login-hint-arrow">→</text>
      </view>
    </view>

    <view class="calendar-section">
      <view class="calendar-header">
        <text class="month-text">{{ currentMonthText }}</text>
        <view class="nav-buttons">
          <button class="nav-btn" @click="prevMonth">◀</button>
          <button class="nav-btn" @click="nextMonth">▶</button>
        </view>
      </view>
      <view class="calendar-grid">
        <view class="weekday-row">
          <text class="weekday-text" v-for="day in weekdays" :key="day">{{ day }}</text>
        </view>
        <view class="days-grid">
          <view
            v-for="day in calendarDays"
            :key="day.dateString"
            class="day-cell"
            :class="{
              'other-month': !day.isCurrentMonth,
              'today': day.isToday,
              'selected': day.dateString === selectedDayKey,
              'has-records': day.hasRecords
            }"
            @click="selectDay(day.dateString)"
          >
            <text class="day-text">{{ day.day }}</text>
            <view v-if="day.hasRecords" class="record-dot"></view>
          </view>
        </view>
      </view>
    </view>

    <view class="records-section">
      <view class="records-header">
        <text class="records-title">{{ selectedDayKey }}</text>
        <button class="add-btn" @click="goToCreate">+</button>
      </view>
      <view v-if="currentRecords.length === 0" class="empty-state">
        <text class="empty-text">暂无记录</text>
        <text class="empty-hint">点击下方按钮创建今日记录</text>
      </view>
      <view v-else class="records-list">
        <view
          v-for="record in currentRecords"
          :key="record.id"
          class="record-card"
          @click="goToDetail(record.id)"
        >
          <view class="record-header">
            <text class="record-type">{{ getRecordTypeText(record.type) }}</text>
            <text class="record-status" :class="'status-' + record.status">
              {{ getStatusText(record.status) }}
            </text>
          </view>
          <text class="record-content">{{ record.content || "无内容" }}</text>
          <view v-if="record.media.length > 0" class="record-media-preview">
            <image
              v-for="(media, index) in record.media.slice(0, 3)"
              :key="index"
              :src="media.localPath || media.remoteUrl || ''"
              class="media-thumb"
              mode="aspectFill"
            />
          </view>
          <view class="record-footer">
            <text class="record-time">{{ formatTime(record.createdAt) }}</text>
            <text v-if="record.meritValue" class="record-merit">+{{ record.meritValue }} ✨</text>
          </view>
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
import { MeritService } from "@/services/MeritService";

const weekdays = ["日", "一", "二", "三", "四", "五", "六"];

const currentDate = ref(new Date());
const selectedDayKey = ref(getDayKey(new Date()));
const isLoggedIn = ref(false);
const totalMerit = ref(0);
const dailyMerit = ref(0);

const currentMonthText = computed(() => {
  const date = currentDate.value;
  return `${date.getFullYear()}年${date.getMonth() + 1}月`;
});

const calendarDays = computed(() => {
  const date = currentDate.value;
  const year = date.getFullYear();
  const month = date.getMonth();
  
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const startDate = new Date(firstDay);
  startDate.setDate(startDate.getDate() - startDate.getDay());
  
  const days: Array<{
    date: Date;
    dateString: string;
    day: number;
    isCurrentMonth: boolean;
    isToday: boolean;
    hasRecords: boolean;
  }> = [];
  
  const today = new Date();
  const todayKey = getDayKey(today);
  
  let current = new Date(startDate);
  for (let i = 0; i < 42; i++) {
    const dateString = getDayKey(current);
    const records = RecordRepository.getByDayKey(dateString);
    
    days.push({
      date: new Date(current),
      dateString,
      day: current.getDate(),
      isCurrentMonth: current.getMonth() === month,
      isToday: dateString === todayKey,
      hasRecords: records.length > 0
    });
    
    current.setDate(current.getDate() + 1);
    if (current > new Date(year, month + 1, 0) && current.getDay() === 0) {
      break;
    }
  }
  
  return days;
});

const currentRecords = ref<GoodDeedRecord[]>([]);

onMounted(() => {
  loadRecordsForSelectedDay();
  refreshMeritData();
  refreshAuthState();
});

// P1-01: onShow 时也刷新选中日的列表 + 功德数据
onShow(() => {
  loadRecordsForSelectedDay();
  refreshMeritData();
  refreshAuthState();
});

function refreshAuthState() {
  isLoggedIn.value = AuthService.isLoggedIn();
}

async function refreshMeritData() {
  if (!AuthService.isLoggedIn()) return;
  try {
    const merit = await MeritService.getUserMerit();
    if (merit) {
      totalMerit.value = merit.totalMerit;
      dailyMerit.value = merit.dailyMerit;
    }
  } catch {
    // 静默失败
  }
}

function getDayKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function prevMonth() {
  const date = new Date(currentDate.value);
  date.setMonth(date.getMonth() - 1);
  currentDate.value = date;
}

function nextMonth() {
  const date = new Date(currentDate.value);
  date.setMonth(date.getMonth() + 1);
  currentDate.value = date;
}

function selectDay(dayKey: string) {
  selectedDayKey.value = dayKey;
  loadRecordsForSelectedDay();
}

function loadRecordsForSelectedDay() {
  currentRecords.value = RecordRepository.getByDayKey(selectedDayKey.value);
}

function goToCreate() {
  uni.navigateTo({ url: "/pages/create-record/create-record" });
}

function goToDetail(id: string) {
  uni.navigateTo({ url: `/pages/record-detail/record-detail?id=${id}` });
}

function goToRanking() {
  uni.navigateTo({ url: "/pages/ranking/ranking" });
}

function goToLogin() {
  uni.navigateTo({ url: "/pages/login/login" });
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

function formatTime(isoString: string): string {
  const date = new Date(isoString);
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${hours}:${minutes}`;
}
</script>

<script lang="ts">
import type { GoodDeedRecord } from "@/types";
export default { name: "IndexPage" };
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 20rpx;
}

/* 功德卡片 */
.merit-card {
  background: linear-gradient(135deg, #FFF0E5 0%, #FFE4CC 100%);
  border-radius: 16rpx;
  padding: 32rpx 24rpx;
  margin-bottom: 20rpx;
  box-shadow: 0 4rpx 12rpx rgba(232, 115, 58, 0.15);
}

.merit-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.merit-main {
  display: flex;
  align-items: baseline;
  gap: 8rpx;
}

.merit-icon {
  font-size: 40rpx;
}

.merit-number {
  font-size: 56rpx;
  font-weight: bold;
  color: #FFD700;
  text-shadow: 0 2rpx 8rpx rgba(255, 215, 0, 0.3);
}

.merit-label {
  font-size: 28rpx;
  color: #8B7E74;
  margin-left: 8rpx;
}

.merit-daily {
  background-color: rgba(232, 115, 58, 0.15);
  border-radius: 20rpx;
  padding: 8rpx 20rpx;
}

.daily-text {
  font-size: 24rpx;
  color: #E8733A;
  font-weight: 500;
}

.merit-login-hint {
  display: flex;
  align-items: center;
  gap: 12rpx;
}

.login-hint-text {
  font-size: 30rpx;
  color: #8B7E74;
}

.login-hint-arrow {
  font-size: 30rpx;
  color: #E8733A;
}

/* 日历 */
.calendar-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
  margin-bottom: 20rpx;
}

.calendar-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20rpx;
}

.month-text {
  font-size: 32rpx;
  font-weight: bold;
  color: #333333;
}

.nav-buttons {
  display: flex;
  gap: 16rpx;
}

.nav-btn {
  background: none;
  border: none;
  font-size: 28rpx;
  padding: 8rpx 16rpx;
  color: #666666;
}

.calendar-grid {
  padding-top: 16rpx;
}

.weekday-row {
  display: flex;
  justify-content: space-around;
  margin-bottom: 12rpx;
}

.weekday-text {
  font-size: 24rpx;
  color: #999999;
  width: 14.28%;
  text-align: center;
}

.days-grid {
  display: flex;
  flex-wrap: wrap;
}

.day-cell {
  width: 14.28%;
  height: 80rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  position: relative;
}

.day-cell.other-month .day-text {
  color: #cccccc;
}

.day-cell.today .day-text {
  color: #E8733A;
  font-weight: bold;
}

.day-cell.selected {
  background-color: #E8733A;
  border-radius: 8rpx;
}

.day-cell.selected .day-text {
  color: #ffffff;
}

.day-text {
  font-size: 28rpx;
  color: #333333;
}

.record-dot {
  width: 8rpx;
  height: 8rpx;
  background-color: #E8733A;
  border-radius: 50%;
  margin-top: 4rpx;
}

/* 记录列表 */
.records-section {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 24rpx;
}

.records-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24rpx;
}

.records-title {
  font-size: 32rpx;
  font-weight: bold;
  color: #333333;
}

.add-btn {
  background-color: #E8733A;
  color: #ffffff;
  border: none;
  border-radius: 50%;
  width: 56rpx;
  height: 56rpx;
  font-size: 40rpx;
  line-height: 56rpx;
  padding: 0;
}

.empty-state {
  text-align: center;
  padding: 80rpx 0;
}

.empty-text {
  font-size: 32rpx;
  color: #999999;
  display: block;
  margin-bottom: 16rpx;
}

.empty-hint {
  font-size: 24rpx;
  color: #cccccc;
}

.records-list {
  display: flex;
  flex-direction: column;
  gap: 20rpx;
}

.record-card {
  background-color: #FFF8F0;
  border-radius: 12rpx;
  padding: 20rpx;
}

.record-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 12rpx;
}

.record-type {
  font-size: 24rpx;
  color: #8B7E74;
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
  background-color: #FFF0E5;
  color: #E8733A;
}

.status-synced {
  background-color: #f6ffed;
  color: #52c41a;
}

.status-failed {
  background-color: #fff1f0;
  color: #ff4d4f;
}

.record-content {
  font-size: 28rpx;
  color: #333333;
  margin-bottom: 12rpx;
  display: block;
}

.record-media-preview {
  display: flex;
  gap: 12rpx;
  margin-bottom: 12rpx;
}

.media-thumb {
  width: 120rpx;
  height: 120rpx;
  border-radius: 8rpx;
}

.record-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.record-time {
  font-size: 24rpx;
  color: #999999;
}

.record-merit {
  font-size: 24rpx;
  color: #FFD700;
  font-weight: 500;
}
</style>
