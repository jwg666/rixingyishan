import { RecordRepository } from "./RecordRepository";
import type { UploadTask, GoodDeedRecord } from "@/types";

const MAX_RETRY = 3;
const RETRY_DELAYS = [2000, 5000, 10000];
const CONCURRENT_LIMIT = 1;

let isProcessing = false;

function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2);
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export const UploadQueueService = {
  enqueue(recordId: string, mediaIndex: number, localPath: string): string {
    const taskId = generateId();
    const task: UploadTask = {
      id: taskId,
      recordId,
      mediaIndex,
      localPath,
      status: "queued",
      retryCount: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    RecordRepository.insertUploadTask(task);
    this.processQueue();
    return taskId;
  },

  async retryTask(taskId: string): Promise<void> {
    const tasks = RecordRepository.getUploadTaskByRecord("");
    const task = tasks.find((t) => t.id === taskId);
    if (task) {
      task.status = "queued";
      task.retryCount = 0;
      task.failReason = undefined;
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);
      this.processQueue();
    }
  },

  retryRecordTasks(recordId: string): void {
    const tasks = RecordRepository.getUploadTaskByRecord(recordId);
    tasks.forEach((task) => {
      if (task.status === "failed") {
        task.status = "queued";
        task.retryCount = 0;
        task.failReason = undefined;
        task.updatedAt = new Date().toISOString();
        RecordRepository.updateUploadTask(task);
      }
    });
    this.processQueue();
  },

  async processQueue(): Promise<void> {
    if (isProcessing) return;
    isProcessing = true;

    try {
      const pendingTasks = RecordRepository.getPendingUploadTasks();
      
      for (let i = 0; i < Math.min(pendingTasks.length, CONCURRENT_LIMIT); i++) {
        const task = pendingTasks[i];
        if (task.status === "queued") {
          await this.executeTask(task);
        }
      }
    } finally {
      isProcessing = false;
    }
  },

  async executeTask(task: UploadTask): Promise<void> {
    task.status = "uploading";
    task.updatedAt = new Date().toISOString();
    RecordRepository.updateUploadTask(task);

    try {
      await this.uploadFile(task);
      
      task.status = "success";
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);

      await this.onTaskSuccess(task);
    } catch (error: any) {
      await this.handleTaskError(task, error);
    }
  },

  async uploadFile(task: UploadTask): Promise<void> {
    return new Promise((resolve, reject) => {
      const uploadTask = uni.uploadFile({
        url: "https://example.com/upload",
        filePath: task.localPath,
        name: "file",
        success: () => resolve(),
        fail: (err) => reject(err),
      });
    });
  },

  async onTaskSuccess(task: UploadTask): Promise<void> {
    const record = RecordRepository.getById(task.recordId);
    if (record) {
      const allTasks = RecordRepository.getUploadTaskByRecord(task.recordId);
      const allSuccess = allTasks.every((t) => t.status === "success");
      
      if (allSuccess) {
        record.status = "synced";
        record.updatedAt = new Date().toISOString();
        RecordRepository.update(record);
      }
    }
  },

  async handleTaskError(task: UploadTask, error: any): Promise<void> {
    task.retryCount += 1;

    if (task.retryCount < MAX_RETRY) {
      task.status = "queued";
      task.failReason = error?.errMsg || "上传失败";
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);

      const delay = RETRY_DELAYS[task.retryCount - 1] || RETRY_DELAYS[RETRY_DELAYS.length - 1];
      await sleep(delay);
      
      await this.executeTask(task);
    } else {
      task.status = "failed";
      task.failReason = error?.errMsg || "上传失败，超过最大重试次数";
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);

      const record = RecordRepository.getById(task.recordId);
      if (record) {
        record.status = "failed";
        record.failReason = task.failReason;
        record.updatedAt = new Date().toISOString();
        RecordRepository.update(record);
      }
    }
  },

  recoverPendingTasks(): void {
    const pendingTasks = RecordRepository.getPendingUploadTasks();
    pendingTasks.forEach((task) => {
      if (task.status === "uploading") {
        task.status = "queued";
        task.updatedAt = new Date().toISOString();
        RecordRepository.updateUploadTask(task);
      }
    });
    
    if (pendingTasks.length > 0) {
      this.processQueue();
    }
  },
};
