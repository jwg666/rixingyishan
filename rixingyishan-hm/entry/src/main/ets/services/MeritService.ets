import { HttpClient } from './HttpClient';
import { MeritTag, UserMerit, RankingItem, UserProfile } from '../model/Types';

export type RankingType = 'total' | 'daily';

/** GET /rankings/:type 响应（后端 service.RankingResult） */
export interface RankingResponse {
  items: RankingItem[];
  myRank?: RankingItem;
}

/** POST /merit/match 响应（后端返回 { tag } 形状） */
export interface MatchTagData {
  tag: MeritTag | null;
}

/** GET /merit/tags 响应 */
export interface TagsData {
  tags: MeritTag[];
}

/**
 * MeritService — 功德体系：标签、智能匹配、统计、排行、资料
 * 注意：排行走后端 /rankings/total|daily 路由（非 /merit/ranking）。
 */
export class MeritService {
  private static tagsCache: MeritTag[] | null = null;

  static async getTags(): Promise<MeritTag[]> {
    if (MeritService.tagsCache !== null) {
      return MeritService.tagsCache;
    }
    const res = await HttpClient.get<TagsData>('/merit/tags', true);
    const tags = res.data.tags || [];
    MeritService.tagsCache = tags;
    return tags;
  }

  static async matchTag(content: string): Promise<MeritTag | null> {
    const trimmed = content.trim();
    if (!trimmed) {
      return null;
    }
    try {
      const body: Record<string, string> = { 'content': trimmed };
      const res = await HttpClient.post<MatchTagData>('/merit/match', body, true);
      return res.data.tag;
    } catch (e) {
      return null;
    }
  }

  static async getUserMerit(): Promise<UserMerit | null> {
    try {
      const res = await HttpClient.get<UserMerit>('/merit/my');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  static async getRanking(type: RankingType, page: number = 1, pageSize: number = 50): Promise<RankingResponse> {
    const res = await HttpClient.get<RankingResponse>(`/rankings/${type}?page=${page}&pageSize=${pageSize}`);
    return res.data;
  }

  static async getProfile(): Promise<UserProfile | null> {
    try {
      const res = await HttpClient.get<UserProfile>('/users/profile');
      return res.data;
    } catch (e) {
      return null;
    }
  }

  static async updateNickname(nickname: string): Promise<void> {
    const body: Record<string, string> = { 'nickname': nickname };
    await HttpClient.patch('/users/profile', body);
  }

  static async updateShowInRanking(showInRanking: boolean): Promise<void> {
    const body: Record<string, boolean> = { 'showInRanking': showInRanking };
    await HttpClient.patch('/users/profile', body);
  }
}
