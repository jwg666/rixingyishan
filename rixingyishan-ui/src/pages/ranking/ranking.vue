<template>
  <view class="container">
    <!-- 未登录提示 -->
    <view v-if="!isLoggedIn" class="login-hint-card" @click="goToLogin">
      <text class="login-hint-icon">✨</text>
      <text class="login-hint-text">登录后查看排行</text>
      <text class="login-hint-arrow">→</text>
    </view>

    <!-- Tab 切换 -->
    <view class="tab-bar">
      <view
        class="tab-item"
        :class="{ 'tab-active': activeTab === 'total' }"
        @click="switchTab('total')"
      >
        <text class="tab-text" :class="{ 'tab-text-active': activeTab === 'total' }">总功德榜</text>
      </view>
      <view
        class="tab-item"
        :class="{ 'tab-active': activeTab === 'daily' }"
        @click="switchTab('daily')"
      >
        <text class="tab-text" :class="{ 'tab-text-active': activeTab === 'daily' }">日行一善榜</text>
      </view>
    </view>

    <!-- 排行列表 -->
    <scroll-view
      scroll-y
      class="ranking-list"
      refresher-enabled
      :refresher-triggered="isRefreshing"
      @refresherrefresh="onRefresh"
    >
      <view v-if="rankingList.length === 0 && !isLoading" class="empty-state">
        <text class="empty-text">暂无排行数据</text>
      </view>

      <view
        v-for="item in rankingList"
        :key="item.rankPosition"
        class="rank-item"
        :class="{ 'rank-item-me': item.isMe }"
      >
        <view class="rank-position">
          <text v-if="item.rankPosition === 1" class="rank-medal">🥇</text>
          <text v-else-if="item.rankPosition === 2" class="rank-medal">🥈</text>
          <text v-else-if="item.rankPosition === 3" class="rank-medal">🥉</text>
          <text v-else class="rank-number">{{ item.rankPosition }}</text>
        </view>
        <view class="rank-avatar" :style="{ backgroundColor: avatarColor(item.avatarSeed) }">
          <text class="rank-avatar-text">{{ nicknameInitial(item.nickname) }}</text>
        </view>
        <view class="rank-info">
          <text class="rank-nickname">{{ item.nickname || '善心人士' }}</text>
          <text v-if="item.isMe" class="rank-me-tag">我</text>
        </view>
        <text class="rank-merit">{{ item.meritValue }} ✨</text>
      </view>
    </scroll-view>

    <!-- 我的排名固定底部 -->
    <view v-if="myRank && !myRankInList" class="my-rank-bar">
      <view class="rank-position">
        <text class="rank-number">{{ myRank.rankPosition }}</text>
      </view>
      <view class="rank-avatar" :style="{ backgroundColor: avatarColor(myRank.avatarSeed) }">
        <text class="rank-avatar-text">{{ nicknameInitial(myRank.nickname) }}</text>
      </view>
      <view class="rank-info">
        <text class="rank-nickname">{{ myRank.nickname || '我' }}</text>
        <text class="rank-me-tag">我</text>
      </view>
      <text class="rank-merit">{{ myRank.meritValue }} ✨</text>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue";
import { AuthService } from "@/services/AuthService";
import { MeritService, getAvatarColor, getNicknameInitial } from "@/services/MeritService";
import type { RankingItem } from "@/types";

const isLoggedIn = ref(false);
const activeTab = ref<"total" | "daily">("total");
const rankingList = ref<RankingItem[]>([]);
const myRank = ref<RankingItem | null>(null);
const isLoading = ref(false);
const isRefreshing = ref(false);

const myRankInList = computed(() => {
  if (!myRank.value) return false;
  return rankingList.value.some((item) => item.isMe);
});

onMounted(() => {
  isLoggedIn.value = AuthService.isLoggedIn();
  loadRanking();
});

function avatarColor(seed: string): string {
  return getAvatarColor(seed);
}

function nicknameInitial(nickname: string | null): string {
  return getNicknameInitial(nickname);
}

async function loadRanking() {
  if (!AuthService.isLoggedIn()) return;
  isLoading.value = true;
  try {
    const res = await MeritService.getRanking(activeTab.value);
    rankingList.value = res.list || [];
    myRank.value = res.myRank || null;
  } catch {
    // 静默失败
  } finally {
    isLoading.value = false;
  }
}

function switchTab(tab: "total" | "daily") {
  activeTab.value = tab;
  loadRanking();
}

async function onRefresh() {
  isRefreshing.value = true;
  await loadRanking();
  isRefreshing.value = false;
}

function goToLogin() {
  uni.navigateTo({ url: "/pages/login/login" });
}
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  display: flex;
  flex-direction: column;
}

/* 未登录提示 */
.login-hint-card {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12rpx;
  padding: 32rpx;
  margin: 20rpx;
  background-color: #ffffff;
  border-radius: 16rpx;
}

.login-hint-icon {
  font-size: 36rpx;
}

.login-hint-text {
  font-size: 30rpx;
  color: #8B7E74;
}

.login-hint-arrow {
  font-size: 30rpx;
  color: #E8733A;
}

/* Tab 切换 */
.tab-bar {
  display: flex;
  margin: 20rpx 20rpx 0;
  background-color: #ffffff;
  border-radius: 16rpx;
  overflow: hidden;
}

.tab-item {
  flex: 1;
  text-align: center;
  padding: 20rpx 0;
  position: relative;
}

.tab-active {
  background-color: #FFF0E5;
}

.tab-active::after {
  content: "";
  position: absolute;
  bottom: 0;
  left: 30%;
  right: 30%;
  height: 4rpx;
  background-color: #E8733A;
  border-radius: 2rpx;
}

.tab-text {
  font-size: 28rpx;
  color: #8B7E74;
}

.tab-text-active {
  color: #E8733A;
  font-weight: bold;
}

/* 排行列表 */
.ranking-list {
  flex: 1;
  padding: 16rpx 20rpx;
}

.empty-state {
  text-align: center;
  padding: 120rpx 0;
}

.empty-text {
  font-size: 30rpx;
  color: #999999;
}

.rank-item {
  display: flex;
  align-items: center;
  padding: 20rpx 16rpx;
  background-color: #ffffff;
  border-radius: 12rpx;
  margin-bottom: 12rpx;
  gap: 16rpx;
}

.rank-item-me {
  background: linear-gradient(135deg, #FFF0E5 0%, #ffffff 100%);
  border: 2rpx solid #E8733A;
}

.rank-position {
  width: 60rpx;
  text-align: center;
  flex-shrink: 0;
}

.rank-medal {
  font-size: 40rpx;
}

.rank-number {
  font-size: 28rpx;
  color: #8B7E74;
  font-weight: bold;
}

.rank-avatar {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.rank-avatar-text {
  font-size: 28rpx;
  color: #ffffff;
  font-weight: bold;
}

.rank-info {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 8rpx;
  min-width: 0;
}

.rank-nickname {
  font-size: 28rpx;
  color: #333333;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.rank-me-tag {
  font-size: 20rpx;
  color: #ffffff;
  background-color: #E8733A;
  padding: 2rpx 10rpx;
  border-radius: 8rpx;
  flex-shrink: 0;
}

.rank-merit {
  font-size: 28rpx;
  color: #FFD700;
  font-weight: bold;
  flex-shrink: 0;
}

/* 底部我的排名 */
.my-rank-bar {
  display: flex;
  align-items: center;
  padding: 20rpx 24rpx;
  background: linear-gradient(135deg, #FFF0E5 0%, #ffffff 100%);
  border-top: 2rpx solid #FFE4CC;
  gap: 16rpx;
}
</style>
