/**
 * 数据模型 — 与 H5 (rixingyishan-ui/src/types/index.ts) 对齐
 * 云同步扩展字段: serverRecordId / syncVersion / serverUpdatedAt / needsAccountBind
 */

export type RecordType = 'photo' | 'video' | 'text';

export type SyncStatus = 'draft' | 'queued' | 'uploading' | 'synced' | 'failed';

export type UploadTaskStatus = 'queued' | 'uploading' | 'success' | 'failed';

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
  /** 服务端记录 ID（字符串化的数字），推送成功后回写 */
  serverRecordId?: string;
  /** 服务端同步版本号，LWW 优先比较字段 */
  syncVersion?: number;
  /** 服务端 updatedAt */
  serverUpdatedAt?: string;
  /** 未登录时创建、待登录后合并推送 */
  needsAccountBind?: boolean;
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
}

export interface UploadTask {
  id: string;
  recordId: string;
  mediaIndex: number;
  localPath: string;
  status: UploadTaskStatus;
  retryCount: number;
  failReason?: string;
  createdAt: string;
  updatedAt: string;
}

/** 功德标签（keywords 为后端返回的逗号分隔字符串） */
export interface MeritTag {
  id: number;
  name: string;
  icon: string;
  meritValue: number;
  keywords: string;
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

/** 后端统一响应格式 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

/** 本地功德汇总（用于功德卡兜底展示） */
export interface MeritSum {
  total: number;
  daily: number;
}

// ---------- 服务端记录形状（映射前的远端 JSON） ----------

export interface RemoteMedia {
  id: number;
  recordId: number;
  objectKey?: string;
  remoteUrl?: string;
  mimeType?: string;
  size?: number;
  sortOrder?: number;
}

export interface RemoteRecord {
  id: number;
  userId: number;
  type: string;
  content?: string;
  tag?: string;
  meritValue?: number;
  recordDate: string;
  syncVersion?: number;
  createdAt?: string;
  updatedAt?: string;
  media?: RemoteMedia[] | null;
}
