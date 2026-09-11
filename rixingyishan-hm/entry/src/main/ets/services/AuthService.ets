import { HttpClient } from './HttpClient';
import { RecordRepository } from './RecordRepository';
import { UploadQueueService } from './UploadQueueService';
import { KvStore } from './KvStore';
import { Constants } from '../common/Constants';
import { GoodDeedRecord } from '../model/Types';

/** 短信发送响应 */
export interface SmsSendResponse {
  expiresIn: number;
}

/** 短信验证响应 */
export interface SmsVerifyResponse {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  userId: number;
  phone: string;
}

/**
 * AuthService — 短信验证码登录、token 管理、退出
 */
export class AuthService {
  /** 登录成功回调 — 由 SyncMergeService 启动时注册（避免循环依赖） */
  static onLoggedIn: (() => void) | null = null;

  static async sendSmsCode(phone: string): Promise<SmsSendResponse> {
    const body: Record<string, string> = { 'phone': phone };
    const res = await HttpClient.post<SmsSendResponse>('/auth/sms/send', body, true);
    return res.data;
  }

  static async verifySmsCode(phone: string, code: string): Promise<SmsVerifyResponse> {
    const body: Record<string, string> = { 'phone': phone, 'code': code };
    const res = await HttpClient.post<SmsVerifyResponse>('/auth/sms/verify', body, true);
    const data = res.data;
    KvStore.setString(Constants.KEY_ACCESS_TOKEN, data.accessToken);
    KvStore.setString(Constants.KEY_REFRESH_TOKEN, data.refreshToken);
    KvStore.setString(Constants.KEY_USER_PHONE, data.phone);
    KvStore.setString(Constants.KEY_USER_ID, String(data.userId));

    // 登录成功 → 自动推送未绑定记录（钩子在 EntryAbility 启动时注册）
    if (AuthService.onLoggedIn !== null) {
      try {
        AuthService.onLoggedIn();
      } catch (e) {
        // 推送失败不阻塞登录流程
      }
    }
    return data;
  }

  static isLoggedIn(): boolean {
    return KvStore.getString(Constants.KEY_ACCESS_TOKEN) !== '';
  }

  static getAccessToken(): string {
    return KvStore.getString(Constants.KEY_ACCESS_TOKEN);
  }

  static getRefreshToken(): string {
    return KvStore.getString(Constants.KEY_REFRESH_TOKEN);
  }

  static getPhone(): string {
    return KvStore.getString(Constants.KEY_USER_PHONE);
  }

  static getUserId(): string {
    return KvStore.getString(Constants.KEY_USER_ID);
  }

  /**
   * 退出登录 — 暂停上传队列 + 调后端（尽力而为）+ 未同步记录标记 needsAccountBind + 清会话
   */
  static async logout(): Promise<void> {
    UploadQueueService.pause();
    try {
      await HttpClient.post('/auth/logout', null);
    } catch (e) {
      // 接口失败也继续本地清理
    }
    AuthService.markUnsyncedForBind();
    AuthService.logoutLocal();
  }

  /** 未同步且无 userId 的记录标记 needsAccountBind，再次登录后自动推送 */
  private static markUnsyncedForBind(): void {
    const records = RecordRepository.getAll();
    let changed = false;
    for (const r of records) {
      if (r.status !== 'synced' && !r.userId) {
        r.needsAccountBind = true;
        r.updatedAt = new Date().toISOString();
        changed = true;
      }
    }
    if (changed) {
      RecordRepository.replaceAll(records);
    }
  }

  static logoutLocal(): void {
    KvStore.remove(Constants.KEY_ACCESS_TOKEN);
    KvStore.remove(Constants.KEY_REFRESH_TOKEN);
    KvStore.remove(Constants.KEY_USER_PHONE);
  }
}
