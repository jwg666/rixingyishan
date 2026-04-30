export type RecordType = "photo" | "video" | "text";

export type SyncStatus = "draft" | "queued" | "uploading" | "synced" | "failed";

export interface MediaItem {
  localPath?: string;
  remoteUrl?: string;
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
