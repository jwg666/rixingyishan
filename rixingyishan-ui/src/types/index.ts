export type RecordType = "photo" | "video" | "text";

export type SyncStatus = "draft" | "queued" | "uploading" | "synced" | "failed";

export interface MediaItem {
  localPath?: string;
  remoteUrl?: string;
  objectKey?: string;
  mimeType: string;
  width?: number;
  height?: number;
  durationMs?: number;
  sizeBytes?: number;
  checksum?: string;
}

export interface GoodDeedRecord {
  id: string;
  userId?: string;
  type: RecordType;
  title?: string;
  content: string;
  media: MediaItem[];
  dayKey: string;
  createdAt: string;
  updatedAt: string;
  status: SyncStatus;
  failReason?: string;
  tags?: string[];
  meritTagId?: number;
  meritValue?: number;
  location?: {
    name?: string;
    lat?: number;
    lng?: number;
  };
}

export interface UploadTask {
  id: string;
  recordId: string;
  mediaIndex: number;
  localPath: string;
  status: "queued" | "uploading" | "success" | "failed";
  retryCount: number;
  failReason?: string;
  createdAt: string;
  updatedAt: string;
}

/** 功德标签 */
export interface MeritTag {
  id: number;
  name: string;
  icon: string;
  meritValue: number;
  keywords: string[];
}

/** 用户功德统计 */
export interface UserMerit {
  totalMerit: number;
  dailyMerit: number;
}

/** 排行榜条目 */
export interface RankingItem {
  rankPosition: number;
  nickname: string;
  avatarSeed: string;
  meritValue: number;
  isMe?: boolean;
}

/** 用户资料 */
export interface UserProfile {
  id: number;
  phone: string;
  nickname: string | null;
  avatarSeed: string;
  totalMerit: number;
  showInRanking: boolean;
}
