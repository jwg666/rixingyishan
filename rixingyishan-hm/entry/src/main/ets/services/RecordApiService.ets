import { HttpClient } from './HttpClient';
import { ApiResponse, GoodDeedRecord, MediaItem, RecordType, RemoteMedia, RemoteRecord } from '../model/Types';
import { autoTitle } from '../common/Utils';

/** GET /records 响应 data */
export interface ListRecordsData {
  records: RemoteRecord[];
  total: number;
  page: number;
  pageSize: number;
}

/** GET /records/days 响应 data */
export interface DaysData {
  days: string[];
}

/** POST /records 响应 data */
export interface CreateRecordData {
  serverRecordId: number;
  syncVersion: number;
  meritValue: number;
  record: RemoteRecord;
}

export interface CreateMediaInput {
  remoteUrl?: string;
  objectKey?: string;
  mimeType: string;
  size: number;
}

export interface CreateRecordPayload {
  type: string;
  content: string;
  tag: string;
  meritValue: number;
  recordDate: string;
  media: CreateMediaInput[];
}

/** 远端记录 → 本地模型（status 恒为 synced） */
export function mapRemoteToLocal(r: RemoteRecord): GoodDeedRecord {
  const media: MediaItem[] = [];
  if (r.media !== undefined && r.media !== null) {
    for (const m of r.media) {
      const item: MediaItem = {
        remoteUrl: m.remoteUrl || '',
        objectKey: m.objectKey || '',
        mimeType: m.mimeType || 'image/jpeg',
        sizeBytes: m.size || 0
      };
      media.push(item);
    }
  }
  const content = r.content || '';
  let recordType: RecordType = 'text';
  if (r.type === 'video' || r.type === 'photo') {
    recordType = r.type;
  }
  const record: GoodDeedRecord = {
    id: `srv-${r.id}`,
    userId: String(r.userId),
    serverRecordId: String(r.id),
    syncVersion: r.syncVersion || 1,
    serverUpdatedAt: r.updatedAt || '',
    type: recordType,
    title: autoTitle(content),
    content: content,
    media: media,
    dayKey: r.recordDate,
    createdAt: r.createdAt || r.updatedAt || '',
    updatedAt: r.updatedAt || r.createdAt || '',
    status: 'synced',
    tags: r.tag ? [r.tag] : undefined,
    meritValue: r.meritValue || 0
  };
  return record;
}

/** 本地记录 → POST /records 载荷 */
export function buildCreatePayload(record: GoodDeedRecord): CreateRecordPayload {
  const mediaInputs: CreateMediaInput[] = [];
  for (const m of record.media) {
    const input: CreateMediaInput = {
      remoteUrl: m.remoteUrl || '',
      objectKey: m.objectKey || '',
      mimeType: m.mimeType,
      size: m.sizeBytes || 0
    };
    mediaInputs.push(input);
  }
  const payload: CreateRecordPayload = {
    type: record.type,
    content: record.content,
    tag: record.tags && record.tags.length > 0 ? record.tags[0] : '其他善行',
    meritValue: record.meritValue || 0,
    recordDate: record.dayKey,
    media: mediaInputs
  };
  return payload;
}

/**
 * RecordApiService — 记录云端接口
 */
export class RecordApiService {
  static async listByDay(dayKey: string, page: number = 1, pageSize: number = 50): Promise<ListRecordsData> {
    const res = await HttpClient.get<ListRecordsData>(
      `/records?dayKey=${encodeURIComponent(dayKey)}&page=${page}&pageSize=${pageSize}`);
    return res.data;
  }

  static async listDays(month: string): Promise<DaysData> {
    const res = await HttpClient.get<DaysData>(`/records/days?month=${encodeURIComponent(month)}`);
    return res.data;
  }

  static async create(payload: CreateRecordPayload): Promise<ApiResponse<CreateRecordData>> {
    const res = await HttpClient.post<CreateRecordData>('/records', payload);
    return res;
  }

  static async remove(serverRecordId: string): Promise<void> {
    await HttpClient.del<object>(`/records/${serverRecordId}`);
  }
}
