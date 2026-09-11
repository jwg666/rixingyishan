import { http, connection } from '@kit.NetworkKit';
import { fs } from '@kit.CoreFileKit';
import { RecordRepository } from './RecordRepository';
import { HttpClient } from './HttpClient';
import { KvStore } from './KvStore';
import { Constants } from '../common/Constants';
import { GoodDeedRecord, UploadTask } from '../model/Types';
import { generateId, sleep } from '../common/Utils';
import { RecordApiService, buildCreatePayload } from './RecordApiService';

/** POST /upload/policy 响应 data */
interface UploadPolicyData {
  uploadUrl: string;
  objectKey: string;
  remoteUrl: string;
}

/**
 * UploadQueueService — 媒体上传流水线（对齐 H5 UploadQueueService + 设计规格 §4.3）
 * 1) POST /upload/policy → uploadUrl/objectKey/remoteUrl
 * 2) multipart 上传二进制 → 回写 media.remoteUrl/objectKey
 * 3) 该记录全部媒体成功 → POST /records 元数据 → synced
 * 重试 3 次（2s/5s/10s），并发 1，支持仅 Wi-Fi 开关、暂停/恢复、回前台恢复。
 */
export class UploadQueueService {
  private static processing: boolean = false;
  private static paused: boolean = false;

  /** 退出登录时暂停自动上传 */
  static pause(): void {
    UploadQueueService.paused = true;
  }

  /** 登录后恢复 */
  static resume(): void {
    UploadQueueService.paused = false;
    UploadQueueService.processQueue();
  }

  static enqueue(recordId: string, mediaIndex: number, localPath: string): string {
    const now = new Date().toISOString();
    const task: UploadTask = {
      id: generateId(),
      recordId: recordId,
      mediaIndex: mediaIndex,
      localPath: localPath,
      status: 'queued',
      retryCount: 0,
      createdAt: now,
      updatedAt: now
    };
    RecordRepository.insertUploadTask(task);
    UploadQueueService.processQueue();
    return task.id;
  }

  /** 单任务重试 */
  static async retryTask(taskId: string): Promise<void> {
    const task = RecordRepository.getUploadTaskById(taskId);
    if (task !== null) {
      task.status = 'queued';
      task.retryCount = 0;
      task.failReason = undefined;
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);
      UploadQueueService.processQueue();
    }
  }

  /** 记录级重试：该记录全部失败任务重新入队 */
  static retryRecordTasks(recordId: string): void {
    const tasks = RecordRepository.getUploadTaskByRecord(recordId);
    for (const task of tasks) {
      if (task.status === 'failed') {
        task.status = 'queued';
        task.retryCount = 0;
        task.failReason = undefined;
        task.updatedAt = new Date().toISOString();
        RecordRepository.updateUploadTask(task);
      }
    }
    const record = RecordRepository.getById(recordId);
    if (record !== null && record.status === 'failed') {
      record.status = 'queued';
      record.updatedAt = new Date().toISOString();
      RecordRepository.update(record);
    }
    UploadQueueService.processQueue();
  }

  /** 仅 Wi-Fi 开关检查；取不到网络状态时容错放行 */
  private static canUploadNow(): boolean {
    const wifiOnly = KvStore.getString(Constants.KEY_WIFI_ONLY);
    if (wifiOnly !== 'true') {
      return true;
    }
    try {
      const netHandle = connection.getDefaultNetSync();
      if (netHandle.netId === 0) {
        return false;
      }
      const caps = connection.getNetCapabilitiesSync(netHandle);
      return caps.bearerTypes.includes(connection.NetBearType.BEARER_WIFI);
    } catch (e) {
      return true;
    }
  }

  /** 串行消费队列（并发 1），直到无 queued 任务或被暂停 */
  static async processQueue(): Promise<void> {
    if (UploadQueueService.processing || UploadQueueService.paused) {
      return;
    }
    if (!UploadQueueService.canUploadNow()) {
      return;
    }
    UploadQueueService.processing = true;
    try {
      while (!UploadQueueService.paused) {
        const pending = RecordRepository.getPendingUploadTasks().filter((t) => t.status === 'queued');
        if (pending.length === 0) {
          break;
        }
        await UploadQueueService.executeTask(pending[0]);
      }
    } finally {
      UploadQueueService.processing = false;
    }
  }

  private static async executeTask(task: UploadTask): Promise<void> {
    task.status = 'uploading';
    task.updatedAt = new Date().toISOString();
    RecordRepository.updateUploadTask(task);
    try {
      await UploadQueueService.uploadFile(task);
      task.status = 'success';
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);
      await UploadQueueService.onTaskSuccess(task);
    } catch (e) {
      await UploadQueueService.handleTaskError(task, e);
    }
  }

  /** 从 localPath 读取整个文件 */
  private static readFileBuffer(localPath: string): ArrayBuffer {
    const file = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
    try {
      const stat = fs.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buf);
      return buf;
    } finally {
      fs.closeSync(file);
    }
  }

  /** 从 localPath 推断文件名 */
  private static inferFileName(localPath: string, mimeType: string): string {
    let name = localPath;
    const slash = localPath.lastIndexOf('/');
    if (slash >= 0) {
      name = localPath.slice(slash + 1);
    }
    const q = name.indexOf('?');
    if (q >= 0) {
      name = name.slice(0, q);
    }
    if (!name || name.indexOf('.') === -1) {
      const ext = mimeType.includes('video') ? 'mp4' : 'jpg';
      return `media_${Date.now()}.${ext}`;
    }
    return name;
  }

  private static async uploadFile(task: UploadTask): Promise<void> {
    const record = RecordRepository.getById(task.recordId);
    if (record === null) {
      throw new Error('记录不存在');
    }
    const media = record.media[task.mediaIndex];
    if (media === undefined) {
      throw new Error('媒体不存在');
    }

    // 1. 上传策略
    const filename = UploadQueueService.inferFileName(task.localPath, media.mimeType);
    const policyBody: Record<string, string | number> = {
      'filename': filename,
      'mimeType': media.mimeType,
      'size': media.sizeBytes || 0
    };
    const policyRes = await HttpClient.post<UploadPolicyData>('/upload/policy', policyBody);
    const policy = policyRes.data;

    // 2. multipart 上传二进制
    const buf = UploadQueueService.readFileBuffer(task.localPath);
    const req = http.createHttp();
    let statusCode = 0;
    try {
      const options: http.HttpRequestOptions = {
        method: http.HttpMethod.POST,
        header: { 'Content-Type': 'multipart/form-data' },
        multiFormDataList: [
          { name: 'file', data: buf, remoteFileName: filename }
        ],
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 120000
      };
      const resp = await req.request(policy.uploadUrl, options);
      statusCode = resp.responseCode;
    } catch (e) {
      throw new Error('上传失败');
    } finally {
      req.destroy();
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(`上传失败 (${statusCode})`);
    }

    // 3. 回写 remoteUrl / objectKey
    const latest = RecordRepository.getById(task.recordId);
    if (latest !== null && latest.media[task.mediaIndex] !== undefined) {
      latest.media[task.mediaIndex].remoteUrl = policy.remoteUrl;
      latest.media[task.mediaIndex].objectKey = policy.objectKey;
      latest.updatedAt = new Date().toISOString();
      RecordRepository.update(latest);
    }
  }

  private static async onTaskSuccess(task: UploadTask): Promise<void> {
    const record = RecordRepository.getById(task.recordId);
    if (record === null) {
      return;
    }
    const allTasks = RecordRepository.getUploadTaskByRecord(task.recordId);
    const allSuccess = allTasks.length > 0 && allTasks.every((t) => t.status === 'success');
    if (!allSuccess) {
      return;
    }
    try {
      const resp = await RecordApiService.create(buildCreatePayload(record));
      record.serverRecordId = String(resp.data.serverRecordId);
      record.syncVersion = resp.data.syncVersion || 1;
      record.serverUpdatedAt = resp.data.record && resp.data.record.updatedAt
        ? resp.data.record.updatedAt : new Date().toISOString();
      if (resp.data.meritValue) {
        record.meritValue = resp.data.meritValue;
      }
      record.status = 'synced';
      record.failReason = undefined;
      record.needsAccountBind = false;
      record.updatedAt = new Date().toISOString();
      RecordRepository.update(record);
    } catch (e) {
      record.status = 'failed';
      record.failReason = '元数据同步失败';
      record.updatedAt = new Date().toISOString();
      RecordRepository.update(record);
    }
  }

  private static async handleTaskError(task: UploadTask, e: Object | null): Promise<void> {
    task.retryCount += 1;
    let message = '上传失败';
    if (e instanceof Error) {
      message = e.message || message;
    }

    if (task.retryCount < Constants.UPLOAD_MAX_RETRY) {
      task.status = 'queued';
      task.failReason = message;
      task.updatedAt = new Date().toISOString();
      RecordRepository.updateUploadTask(task);
      const delay = Constants.UPLOAD_RETRY_DELAYS_MS[task.retryCount - 1]
        || Constants.UPLOAD_RETRY_DELAYS_MS[Constants.UPLOAD_RETRY_DELAYS_MS.length - 1];
      await sleep(delay);
      return; // 队列循环会继续拾取该任务
    }

    task.status = 'failed';
    task.failReason = message;
    task.updatedAt = new Date().toISOString();
    RecordRepository.updateUploadTask(task);

    const record = RecordRepository.getById(task.recordId);
    if (record !== null) {
      record.status = 'failed';
      record.failReason = task.failReason;
      record.updatedAt = new Date().toISOString();
      RecordRepository.update(record);
    }
  }

  /** 回前台恢复：uploading → queued，再启动队列 */
  static recoverPendingTasks(): void {
    const pendingTasks = RecordRepository.getPendingUploadTasks();
    for (const task of pendingTasks) {
      if (task.status === 'uploading') {
        task.status = 'queued';
        task.updatedAt = new Date().toISOString();
        RecordRepository.updateUploadTask(task);
      }
    }
    if (pendingTasks.length > 0) {
      UploadQueueService.processQueue();
    }
  }
}
