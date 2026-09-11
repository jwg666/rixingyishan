import { GoodDeedRecord, UploadTask, MeritSum } from '../model/Types';
import { KvStore } from './KvStore';
import { Constants } from '../common/Constants';
import { todayKey } from '../common/Utils';

/**
 * RecordRepository — 本地记录 + 上传任务的仓储（镜像 H5 RecordRepository.ts）
 * 全部同步操作，底层 preferences JSON。
 */
export class RecordRepository {
  // ---------- 记录 ----------

  static getAll(): GoodDeedRecord[] {
    return KvStore.getJson<GoodDeedRecord[]>(Constants.KEY_RECORDS, []);
  }

  static getById(id: string): GoodDeedRecord | null {
    const all = RecordRepository.getAll();
    for (const r of all) {
      if (r.id === id) {
        return r;
      }
    }
    return null;
  }

  static getByDayKey(dayKey: string): GoodDeedRecord[] {
    return RecordRepository.getAll().filter((r) => r.dayKey === dayKey);
  }

  /** 当月有记录的 dayKey 列表（本地打点用） */
  static getDayKeysWithRecords(month: string): string[] {
    const prefix = month + '-';
    const set = new Set<string>();
    for (const r of RecordRepository.getAll()) {
      if (r.dayKey.startsWith(prefix)) {
        set.add(r.dayKey);
      }
    }
    return Array.from(set);
  }

  static insert(record: GoodDeedRecord): void {
    const all = RecordRepository.getAll();
    all.push(record);
    RecordRepository.saveAll(all);
  }

  static update(record: GoodDeedRecord): void {
    const all = RecordRepository.getAll();
    const index = all.findIndex((r) => r.id === record.id);
    if (index !== -1) {
      all[index] = record;
      RecordRepository.saveAll(all);
    }
  }

  static delete(id: string): void {
    const all = RecordRepository.getAll().filter((r) => r.id !== id);
    RecordRepository.saveAll(all);
    RecordRepository.deleteUploadTasksByRecord(id);
  }

  /** 用一份完整列表替换存储（合并后持久化用） */
  static replaceAll(records: GoodDeedRecord[]): void {
    RecordRepository.saveAll(records);
  }

  private static saveAll(records: GoodDeedRecord[]): void {
    KvStore.setJson(Constants.KEY_RECORDS, records);
  }

  // ---------- 上传任务 ----------

  private static getUploadTasks(): UploadTask[] {
    return KvStore.getJson<UploadTask[]>(Constants.KEY_UPLOAD_TASKS, []);
  }

  private static saveUploadTasks(tasks: UploadTask[]): void {
    KvStore.setJson(Constants.KEY_UPLOAD_TASKS, tasks);
  }

  static getPendingUploadTasks(): UploadTask[] {
    return RecordRepository.getUploadTasks().filter((t) => t.status === 'queued' || t.status === 'uploading');
  }

  static getUploadTaskByRecord(recordId: string): UploadTask[] {
    return RecordRepository.getUploadTasks().filter((t) => t.recordId === recordId);
  }

  static getUploadTaskById(taskId: string): UploadTask | null {
    const tasks = RecordRepository.getUploadTasks();
    for (const t of tasks) {
      if (t.id === taskId) {
        return t;
      }
    }
    return null;
  }

  static insertUploadTask(task: UploadTask): void {
    const tasks = RecordRepository.getUploadTasks();
    tasks.push(task);
    RecordRepository.saveUploadTasks(tasks);
  }

  static updateUploadTask(task: UploadTask): void {
    const tasks = RecordRepository.getUploadTasks();
    const index = tasks.findIndex((t) => t.id === task.id);
    if (index !== -1) {
      tasks[index] = task;
      RecordRepository.saveUploadTasks(tasks);
    }
  }

  /** 该记录某媒体位是否已有未完成任务，避免重复入队 */
  static hasActiveUploadTask(recordId: string, mediaIndex: number): boolean {
    const tasks = RecordRepository.getUploadTaskByRecord(recordId);
    for (const t of tasks) {
      if (t.mediaIndex === mediaIndex && t.status !== 'success' && t.status !== 'failed') {
        return true;
      }
    }
    return false;
  }

  static deleteUploadTasksByRecord(recordId: string): void {
    const tasks = RecordRepository.getUploadTasks().filter((t) => t.recordId !== recordId);
    RecordRepository.saveUploadTasks(tasks);
  }

  /** 清理已完成任务（清理缓存用） */
  static clearCompletedUploadTasks(): void {
    const tasks = RecordRepository.getUploadTasks().filter((t) => t.status !== 'success');
    RecordRepository.saveUploadTasks(tasks);
  }

  /** 清理上传任务队列 — 仅保留进行中（queued/uploading）的任务，不删记录 */
  static clearUploadTasks(): void {
    const tasks = RecordRepository.getUploadTasks().filter((t) => t.status === 'queued' || t.status === 'uploading');
    RecordRepository.saveUploadTasks(tasks);
  }

  // ---------- 缓存 / 数据清理（行为分离，防止误删） ----------

  static clearTempMedia(): void {
    KvStore.remove(Constants.KEY_TEMP_MEDIA);
  }

  /** 危险操作：删除所有本地记录 + 上传任务 */
  static clearAllRecords(): void {
    KvStore.remove(Constants.KEY_RECORDS);
    KvStore.remove(Constants.KEY_UPLOAD_TASKS);
  }

  // ---------- 功德本地兜底 ----------

  static sumMeritLocal(): MeritSum {
    const all = RecordRepository.getAll();
    let total = 0;
    let daily = 0;
    const tk = todayKey();
    for (const r of all) {
      const v = r.meritValue || 0;
      total += v;
      if (r.dayKey === tk) {
        daily += v;
      }
    }
    const sum: MeritSum = { total: total, daily: daily };
    return sum;
  }
}
