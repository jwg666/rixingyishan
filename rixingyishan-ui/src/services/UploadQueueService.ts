import { RecordRepository } from "./RecordRepository";
import { request } from "./request";
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

/** 从 localPath 推断文件名 */
function inferFileName(localPath: string, mimeType: string): string {
  const slash = localPath.lastIndexOf("/");
  let name = slash >= 0 ? localPath.slice(slash + 1) : localPath;
  // 去掉查询参数
  const q = name.indexOf("?");
  if (q >= 0) name = name.slice(0, q);
  if (!name || name.indexOf(".") === -1) {
    const ext = mimeType.includes("video") ? "mp4" : "jpg";
    name = `media_${Date.now()}.${ext}`;
  }
  return name;
}

/** 上传策略响应 */
interface UploadPolicy {
  uploadUrl: string;
  objectKey: string;
  remoteUrl: string;
  headers?: Record<string, string>;
}

/**
 * 检查 Wi-Fi 上传开关是否开启，并判断当前网络是否允许上传
 * P1-02: 仅 Wi-Fi 上传开关贯通队列
 */
function canUploadOverCurrentNetwork(): Promise<boolean> {
  const wifiOnly = uni.getStorageSync("settings_wifi_only");
  if (wifiOnly !== "true") {
    return Promise.resolve(true);
  }

  return new Promise((resolve) => {
    uni.getNetworkType({
      success: (res) => {
        if (res.networkType === "wifi") {
          resolve(true);
        } else {
          resolve(false);
        }
      },
      fail: () => {
        // 无法获取网络类型时，允许上传（容错）
        resolve(true);
      },
    });
  });
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

  /**
   * 重试单个任务（P0-04 修复：使用 getUploadTaskById）
   */
  async retryTask(taskId: string): Promise<void> {
    const task = RecordRepository.getUploadTaskById(taskId);
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

    // P1-02: Wi-Fi 上传开关检查
    const canUpload = await canUploadOverCurrentNetwork();
    if (!canUpload) {
      console.log("[UploadQueue] Wi-Fi only mode: non-Wi-Fi network, skipping queue processing");
      return;
    }

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
    } catch (error: unknown) {
      await this.handleTaskError(task, error);
    }
  },

  /**
   * 真实文件上传流程（P0-01）：
   * 1) 请求 /api/upload/policy 获取 uploadUrl + objectKey + remoteUrl
   * 2) 使用 uni.uploadFile 进行真实上传
   * 3) 回写 record.media[mediaIndex].remoteUrl 和 objectKey
   */
  async uploadFile(task: UploadTask): Promise<void> {
    const record = RecordRepository.getById(task.recordId);
    if (!record) {
      throw new Error("记录不存在");
    }
    const media = record.media[task.mediaIndex];
    if (!media) {
      throw new Error("媒体不存在");
    }

    // 1. 获取上传策略
    const filename = inferFileName(task.localPath, media.mimeType);
    const size = media.sizeBytes || 0;

    const policyRes = await request<UploadPolicy>({
      url: "/upload/policy",
      method: "POST",
      data: {
        filename,
        mimeType: media.mimeType,
        size,
      },
    });
    const policy = policyRes.data;

    // 2. 真实上传文件
    await new Promise<void>((resolve, reject) => {
      uni.uploadFile({
        url: policy.uploadUrl,
        filePath: task.localPath,
        name: "file",
        header: policy.headers || {},
        success: (res) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve();
          } else {
            reject(new Error(`上传失败 (${res.statusCode})`));
          }
        },
        fail: (err) => reject(new Error(err.errMsg || "上传失败")),
      });
    });

    // 3. 回写 remoteUrl 和 objectKey
    const latest = RecordRepository.getById(task.recordId);
    if (latest && latest.media[task.mediaIndex]) {
      latest.media[task.mediaIndex].remoteUrl = policy.remoteUrl;
      latest.media[task.mediaIndex].objectKey = policy.objectKey;
      latest.updatedAt = new Date().toISOString();
      RecordRepository.update(latest);
    }
  },

  /**
   * 单条任务成功后的处理：
   * - 若该记录所有媒体均成功，则同步元数据到服务端，并置 synced 状态
   */
  async onTaskSuccess(task: UploadTask): Promise<void> {
    const record = RecordRepository.getById(task.recordId);
    if (!record) return;

    const allTasks = RecordRepository.getUploadTaskByRecord(task.recordId);
    const allSuccess = allTasks.length > 0 && allTasks.every((t) => t.status === "success");

    if (allSuccess) {
      // 同步元数据到服务端
      try {
        await this.syncRecordMetadata(record);
        record.status = "synced";
        record.updatedAt = new Date().toISOString();
        record.failReason = undefined;
        RecordRepository.update(record);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : "元数据同步失败";
        record.status = "failed";
        record.failReason = message;
        record.updatedAt = new Date().toISOString();
        RecordRepository.update(record);
      }
    }
  },

  /**
   * 同步记录元数据到服务端（POST /api/records）
   */
  async syncRecordMetadata(record: GoodDeedRecord): Promise<void> {
    await request({
      url: "/records",
      method: "POST",
      data: {
        type: record.type,
        content: record.content,
        tag: record.tags?.[0] || "其他善行",
        meritValue: record.meritValue || 0,
        recordDate: record.dayKey,
        media: record.media.map((m) => ({
          remoteUrl: m.remoteUrl,
          objectKey: m.objectKey,
          mimeType: m.mimeType,
          size: m.sizeBytes || 0,
        })),
      },
    });
  },

  async handleTaskError(task: UploadTask, error: unknown): Promise<void> {
    task.retryCount += 1;
    const errMsg = error instanceof Error ? error.message : "上传失败";

    if (task.retryCount < MAX_RETRY) {
      task.status = "queued";
      task.failReason = errMsg;
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);

      const delay = RETRY_DELAYS[task.retryCount - 1] || RETRY_DELAYS[RETRY_DELAYS.length - 1];
      await sleep(delay);

      await this.executeTask(task);
    } else {
      task.status = "failed";
      task.failReason = errMsg || "上传失败，超过最大重试次数";
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
