import type { GoodDeedRecord, UploadTask } from "@/types";

const RECORD_STORAGE_KEY = "good_deeds_records";
const UPLOAD_TASK_STORAGE_KEY = "good_deeds_upload_tasks";
const TEMP_MEDIA_KEY = "good_deeds_temp_media";

function getRecords(): GoodDeedRecord[] {
  try {
    const data = uni.getStorageSync(RECORD_STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  } catch (e) {
    console.error("Failed to get records from storage", e);
    return [];
  }
}

function saveRecords(records: GoodDeedRecord[]): void {
  try {
    uni.setStorageSync(RECORD_STORAGE_KEY, JSON.stringify(records));
  } catch (e) {
    console.error("Failed to save records to storage", e);
  }
}

function getUploadTasks(): UploadTask[] {
  try {
    const data = uni.getStorageSync(UPLOAD_TASK_STORAGE_KEY);
    return data ? JSON.parse(data) : [];
  } catch (e) {
    console.error("Failed to get upload tasks from storage", e);
    return [];
  }
}

function saveUploadTasks(tasks: UploadTask[]): void {
  try {
    uni.setStorageSync(UPLOAD_TASK_STORAGE_KEY, JSON.stringify(tasks));
  } catch (e) {
    console.error("Failed to save upload tasks to storage", e);
  }
}

export const RecordRepository = {
  getAll(): GoodDeedRecord[] {
    return getRecords();
  },

  getById(id: string): GoodDeedRecord | undefined {
    return getRecords().find((r) => r.id === id);
  },

  getByDayKey(dayKey: string): GoodDeedRecord[] {
    return getRecords().filter((r) => r.dayKey === dayKey);
  },

  insert(record: GoodDeedRecord): void {
    const records = getRecords();
    records.push(record);
    saveRecords(records);
  },

  update(record: GoodDeedRecord): void {
    const records = getRecords();
    const index = records.findIndex((r) => r.id === record.id);
    if (index !== -1) {
      records[index] = record;
      saveRecords(records);
    }
  },

  delete(id: string): void {
    const records = getRecords().filter((r) => r.id !== id);
    saveRecords(records);
  },

  getPendingUploadTasks(): UploadTask[] {
    return getUploadTasks().filter(
      (t) => t.status === "queued" || t.status === "uploading"
    );
  },

  getUploadTaskByRecord(recordId: string): UploadTask[] {
    return getUploadTasks().filter((t) => t.recordId === recordId);
  },

  /**
   * 按 taskId 获取上传任务（P0-04 修复）
   */
  getUploadTaskById(taskId: string): UploadTask | null {
    return getUploadTasks().find((t) => t.id === taskId) || null;
  },

  insertUploadTask(task: UploadTask): void {
    const tasks = getUploadTasks();
    tasks.push(task);
    saveUploadTasks(tasks);
  },

  updateUploadTask(task: UploadTask): void {
    const tasks = getUploadTasks();
    const index = tasks.findIndex((t) => t.id === task.id);
    if (index !== -1) {
      tasks[index] = task;
      saveUploadTasks(tasks);
    }
  },

  clearCompletedUploadTasks(): void {
    const tasks = getUploadTasks().filter((t) => t.status !== "success");
    saveUploadTasks(tasks);
  },

  /**
   * 清理上传任务队列（P0-02）— 仅清理已完成与失败的任务，保留正在进行的
   */
  clearUploadTasks(): void {
    const tasks = getUploadTasks().filter(
      (t) => t.status === "queued" || t.status === "uploading"
    );
    saveUploadTasks(tasks);
  },

  /**
   * 清理临时媒体缓存（P0-02）
   */
  clearTempMedia(): void {
    try {
      uni.removeStorageSync(TEMP_MEDIA_KEY);
    } catch (e) {
      console.error("Failed to clear temp media", e);
    }
  },

  /**
   * 删除所有本地记录（P0-02）— 危险操作，需强二次确认
   */
  clearAllRecords(): void {
    try {
      uni.removeStorageSync(RECORD_STORAGE_KEY);
      uni.removeStorageSync(UPLOAD_TASK_STORAGE_KEY);
    } catch (e) {
      console.error("Failed to clear all records", e);
    }
  },
};
