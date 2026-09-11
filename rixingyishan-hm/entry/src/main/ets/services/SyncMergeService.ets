import { RecordRepository } from './RecordRepository';
import { RecordApiService, mapRemoteToLocal, buildCreatePayload } from './RecordApiService';
import { AuthService } from './AuthService';
import { mergeDayRecords } from './SyncMergeCore';
import { GoodDeedRecord } from '../model/Types';

export interface SyncHomeResult {
  /** 合并后当日记录 */
  dayRecords: GoodDeedRecord[];
  /** 远端当月有记录的 dayKey（日历打点用，未登录时为空） */
  remoteDays: string[];
  /** 处理的本地领先记录数（推送成功或入队） */
  pushed: number;
  pushFailed: number;
}

/**
 * SyncMergeService — 登录后首页双向同步（LWW 合并 + 自动回推）
 * 设计决策：仅本地有的记录自动入队推送，无需弹窗确认。
 */
export class SyncMergeService {
  /** EntryAbility 启动时调用：注册“登录成功 → 自动推送未绑定记录”钩子 */
  static init(): void {
    AuthService.onLoggedIn = () => {
      SyncMergeService.afterLoginAutoPush();
    };
  }

  /**
   * 首页同步：
   * 1. 未登录 → 仅返回本地
   * 2. 拉远端当日列表 + 当月 days 打点
   * 3. LWW 合并并持久化
   * 4. 本地领先 → 自动推送（文本直接 create；带媒体置 queued 由上传队列处理）
   */
  static async syncHome(dayKey: string, month: string): Promise<SyncHomeResult> {
    const localRecords = RecordRepository.getByDayKey(dayKey);
    if (!AuthService.isLoggedIn()) {
      const localOnly: SyncHomeResult = {
        dayRecords: localRecords,
        remoteDays: [],
        pushed: 0,
        pushFailed: 0
      };
      return localOnly;
    }

    const remoteList = await RecordApiService.listByDay(dayKey);
    const remoteRecords: GoodDeedRecord[] = [];
    if (remoteList.records !== undefined && remoteList.records !== null) {
      for (const r of remoteList.records) {
        remoteRecords.push(mapRemoteToLocal(r));
      }
    }

    const mergeResult = mergeDayRecords(localRecords, remoteRecords);
    SyncMergeService.persistDay(dayKey, mergeResult.merged);

    let pushed = 0;
    let pushFailed = 0;
    for (const id of mergeResult.toPushIds) {
      const rec = RecordRepository.getById(id);
      if (rec === null) {
        continue;
      }
      if (rec.serverRecordId !== undefined && rec.serverRecordId !== '') {
        // 已有服务端副本且本地胜出：后端暂无更新接口，跳过避免重复创建
        continue;
      }
      if (rec.media.length > 0) {
        // 带媒体记录：由上传队列完成媒体上传后再推元数据（Task 8 接入）
        rec.status = 'queued';
        rec.updatedAt = new Date().toISOString();
        RecordRepository.update(rec);
        pushed++;
        continue;
      }
      try {
        const resp = await RecordApiService.create(buildCreatePayload(rec));
        rec.serverRecordId = String(resp.data.serverRecordId);
        rec.syncVersion = resp.data.syncVersion || 1;
        rec.serverUpdatedAt = resp.data.record && resp.data.record.updatedAt
          ? resp.data.record.updatedAt
          : new Date().toISOString();
        if (resp.data.meritValue) {
          rec.meritValue = resp.data.meritValue;
        }
        rec.status = 'synced';
        rec.needsAccountBind = false;
        rec.userId = AuthService.getUserId();
        rec.updatedAt = new Date().toISOString();
        rec.failReason = undefined;
        RecordRepository.update(rec);
        pushed++;
      } catch (e) {
        rec.status = 'failed';
        rec.failReason = '同步失败';
        rec.updatedAt = new Date().toISOString();
        RecordRepository.update(rec);
        pushFailed++;
      }
    }

    // 当月远端打点
    let remoteDays: string[] = [];
    try {
      const daysData = await RecordApiService.listDays(month);
      remoteDays = daysData.days || [];
    } catch (e) {
      // 打点拉取失败不影响当日列表
    }

    const result: SyncHomeResult = {
      dayRecords: RecordRepository.getByDayKey(dayKey),
      remoteDays: remoteDays,
      pushed: pushed,
      pushFailed: pushFailed
    };
    return result;
  }

  /** 登录成功钩子：全部未绑定记录（needsAccountBind）自动推送 */
  static async afterLoginAutoPush(): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    const records = RecordRepository.getAll();
    let changed = false;
    for (const rec of records) {
      if (rec.needsAccountBind !== true) {
        continue;
      }
      rec.userId = AuthService.getUserId();
      rec.needsAccountBind = false;
      changed = true;
      if (rec.media.length > 0) {
        rec.status = 'queued';
        rec.updatedAt = new Date().toISOString();
        continue;
      }
      try {
        const resp = await RecordApiService.create(buildCreatePayload(rec));
        rec.serverRecordId = String(resp.data.serverRecordId);
        rec.syncVersion = resp.data.syncVersion || 1;
        rec.serverUpdatedAt = resp.data.record && resp.data.record.updatedAt
          ? resp.data.record.updatedAt
          : new Date().toISOString();
        if (resp.data.meritValue) {
          rec.meritValue = resp.data.meritValue;
        }
        rec.status = 'synced';
        rec.updatedAt = new Date().toISOString();
      } catch (e) {
        rec.status = 'failed';
        rec.failReason = '自动推送失败';
        rec.updatedAt = new Date().toISOString();
      }
    }
    if (changed) {
      RecordRepository.replaceAll(records);
    }
  }

  /** 将合并后的当日记录写回存储（先移除该日全部旧记录） */
  private static persistDay(dayKey: string, merged: GoodDeedRecord[]): void {
    const others = RecordRepository.getAll().filter((r) => r.dayKey !== dayKey);
    RecordRepository.replaceAll(others.concat(merged));
  }
}
