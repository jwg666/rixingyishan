/**
 * MeritService — 功德体系服务
 * 提供标签获取、智能匹配、功德统计、排行榜、用户资料管理
 */

import { request } from "./request";
import type { MeritTag, UserMerit, RankingItem, UserProfile } from "@/types";

/** 排行榜类型 */
export type RankingType = "total" | "daily";

/** 排行榜响应 */
export interface RankingResponse {
  list: RankingItem[];
  myRank?: RankingItem;
}

/** 智能匹配响应 */
export interface MatchResponse {
  recommendedTagId: number;
  recommendedTag?: MeritTag;
  confidence: number;
}

export const MeritService = {
  /**
   * 获取所有功德标签
   */
  async getTags(): Promise<MeritTag[]> {
    const res = await request<{ tags: MeritTag[] } | MeritTag[]>({
      url: "/merit/tags",
      method: "GET",
      skipAuth: true,
    });
    const data = res.data as { tags: MeritTag[] } | MeritTag[];
    return Array.isArray(data) ? data : (data.tags || []);
  },

  /**
   * 内容智能匹配标签
   */
  async matchTag(content: string): Promise<MatchResponse | null> {
    if (!content || !content.trim()) return null;
    try {
      const res = await request<MatchResponse>({
        url: "/merit/match",
        method: "POST",
        data: { content },
        skipAuth: true,
      });
      return res.data;
    } catch {
      return null;
    }
  },

  /**
   * 获取当前用户功德统计
   */
  async getUserMerit(): Promise<UserMerit | null> {
    try {
      const res = await request<UserMerit>({
        url: "/merit/my",
        method: "GET",
      });
      return res.data;
    } catch {
      return null;
    }
  },

  /**
   * 获取排行榜
   */
  async getRanking(type: RankingType = "total"): Promise<RankingResponse> {
    const res = await request<RankingResponse>({
      url: `/merit/ranking?type=${type}`,
      method: "GET",
    });
    return res.data;
  },

  /**
   * 获取当前用户资料
   */
  async getProfile(): Promise<UserProfile | null> {
    try {
      const res = await request<UserProfile>({
        url: "/users/profile",
        method: "GET",
      });
      return res.data;
    } catch {
      return null;
    }
  },

  /**
   * 更新昵称
   */
  async updateNickname(nickname: string): Promise<void> {
    await request({
      url: "/users/profile",
      method: "PATCH",
      data: { nickname },
    });
  },

  /**
   * 更新排名可见性
   */
  async updateShowInRanking(showInRanking: boolean): Promise<void> {
    await request({
      url: "/users/profile",
      method: "PATCH",
      data: { showInRanking },
    });
  },
};

/**
 * 根据 avatarSeed 生成柔和背景色
 */
export function getAvatarColor(seed: string): string {
  if (!seed) return "#FFD7B5";
  const colors = [
    "#FFD7B5", // 浅橙
    "#FFE0B2", // 米杏
    "#FFCCBC", // 浅珊瑚
    "#FFE4C4", // 米黄
    "#FFDAB9", // 桃色
    "#FFDDC1", // 浅蜜桃
    "#F5D5AE", // 暖沙
    "#FFE5B4", // 蛋白
  ];
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return colors[hash % colors.length];
}

/**
 * 从昵称取首字
 */
export function getNicknameInitial(nickname: string | null | undefined): string {
  if (!nickname) return "?";
  return nickname.trim().charAt(0).toUpperCase();
}

/**
 * 手机号脱敏
 */
export function maskPhone(phone: string): string {
  if (!phone || phone.length < 7) return phone || "";
  return `${phone.slice(0, 3)}****${phone.slice(-4)}`;
}
