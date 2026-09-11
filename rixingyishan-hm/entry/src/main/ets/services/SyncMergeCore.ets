import { GoodDeedRecord, SyncStatus } from '../model/Types';

/**
 * SyncMergeCore — 纯逻辑 LWW 合并（不依赖任何 ohos Kit，便于本地单测）
 * 合并规则见 docs/superpowers/specs/2026-08-21-harmony-client-design.md §4.2
 */

export interface MergeResult {
  merged: GoodDeedRecord[];
  toPushIds: string[];
}

/** 匹配键：有 serverRecordId 用之，否则用本地 id */
export function matchKeyOf(r: GoodDeedRecord): string {
  if (r.serverRecordId !== undefined && r.serverRecordId !== '') {
    return r.serverRecordId;
  }
  return r.id;
}

/** LWW 分数：syncVersion 优先，其次 serverUpdatedAt / updatedAt 时间戳 */
export function lwwScore(r: GoodDeedRecord): number {
  if (r.syncVersion !== undefined && r.syncVersion !== null) {
    return r.syncVersion;
  }
  const t = r.serverUpdatedAt || r.updatedAt || '';
  return Date.parse(t) || 0;
}

export function pickWinner(local: GoodDeedRecord, remote: GoodDeedRecord): 'local' | 'remote' | 'equal' {
  const ls = lwwScore(local);
  const rs = lwwScore(remote);
  if (ls > rs) {
    return 'local';
  }
  if (rs > ls) {
    return 'remote';
  }
  return 'equal';
}

/** 本地进行中状态（不可被远端覆盖） */
export function isInFlight(status: SyncStatus): boolean {
  return status === 'draft' || status === 'queued' || status === 'uploading' || status === 'failed';
}

/**
 * 合并同一天的本地与远端记录：
 * - 仅远端有 → 写入合并结果，不推送
 * - 仅本地有 → 保留本地，进入 toPush
 * - 两端都有 → LWW 胜者胜出；本地进行中状态（draft/queued/uploading/failed）不被覆盖
 */
export function mergeDayRecords(local: GoodDeedRecord[], remote: GoodDeedRecord[]): MergeResult {
  const remoteByKey = new Map<string, GoodDeedRecord>();
  for (const r of remote) {
    remoteByKey.set(matchKeyOf(r), r);
  }

  const merged: GoodDeedRecord[] = [];
  const toPushIds: string[] = [];
  const consumedRemoteKeys = new Set<string>();

  for (const l of local) {
    const key = matchKeyOf(l);
    const r = remoteByKey.get(key);
    if (r === undefined) {
      merged.push(l);
      toPushIds.push(l.id);
      continue;
    }
    consumedRemoteKeys.add(key);
    if (isInFlight(l.status)) {
      // 本地任务进行中，保留本地；任务完成后再对齐
      merged.push(l);
      continue;
    }
    const winner = pickWinner(l, r);
    if (winner === 'local') {
      merged.push(l);
      toPushIds.push(l.id);
    } else if (winner === 'remote') {
      merged.push(r);
    } else {
      merged.push(l);
    }
  }

  for (const r of remote) {
    if (!consumedRemoteKeys.has(matchKeyOf(r))) {
      merged.push(r);
    }
  }

  const result: MergeResult = { merged: merged, toPushIds: toPushIds };
  return result;
}
