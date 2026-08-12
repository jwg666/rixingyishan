/**
 * AuthService — 认证服务
 * 提供短信验证码登录、token 管理、登录状态查询
 * P1: 登录后合并上传、退出调用后端API
 */

import { request } from "./request";
import { RecordRepository } from "./RecordRepository";
import { UploadQueueService } from "./UploadQueueService";

const ACCESS_TOKEN_KEY = "accessToken";
const REFRESH_TOKEN_KEY = "refreshToken";
const USER_PHONE_KEY = "userPhone";

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

/** 刷新 token 响应 */
export interface RefreshTokenResponse {
  accessToken: string;
  refreshToken: string;
}

export const AuthService = {
  /**
   * 发送短信验证码
   * @param phone 手机号 (11位)
   */
  async sendSmsCode(phone: string): Promise<SmsSendResponse> {
    const res = await request<SmsSendResponse>({
      url: "/auth/sms/send",
      method: "POST",
      data: { phone },
      skipAuth: true,
    });
    return res.data;
  },

  /**
   * 验证短信验证码并登录
   * @param phone 手机号
   * @param code  6位验证码
   */
  async verifySmsCode(phone: string, code: string): Promise<SmsVerifyResponse> {
    const res = await request<SmsVerifyResponse>({
      url: "/auth/sms/verify",
      method: "POST",
      data: { phone, code },
      skipAuth: true,
    });

    // 保存 token 与用户信息
    const data = res.data;
    uni.setStorageSync(ACCESS_TOKEN_KEY, data.accessToken);
    uni.setStorageSync(REFRESH_TOKEN_KEY, data.refreshToken);
    uni.setStorageSync(USER_PHONE_KEY, data.phone);
    uni.setStorageSync("userId", data.userId);

    // 登录成功后检测是否有未同步记录需要合并
    await this.mergeLocalRecords();

    return data;
  },

  /**
   * 刷新 token
   */
  async refreshToken(): Promise<RefreshTokenResponse | null> {
    const refreshToken = uni.getStorageSync(REFRESH_TOKEN_KEY);
    if (!refreshToken) return null;

    try {
      const res = await request<RefreshTokenResponse>({
        url: "/auth/refresh",
        method: "POST",
        data: { refreshToken },
        skipAuth: true,
      });
      uni.setStorageSync(ACCESS_TOKEN_KEY, res.data.accessToken);
      uni.setStorageSync(REFRESH_TOKEN_KEY, res.data.refreshToken);
      return res.data;
    } catch {
      this.logoutLocal();
      return null;
    }
  },

  /** 是否已登录 */
  isLoggedIn(): boolean {
    const token = uni.getStorageSync(ACCESS_TOKEN_KEY);
    return !!token;
  },

  /** 获取 accessToken */
  getAccessToken(): string {
    return uni.getStorageSync(ACCESS_TOKEN_KEY) || "";
  },

  /** 获取 refreshToken */
  getRefreshToken(): string {
    return uni.getStorageSync(REFRESH_TOKEN_KEY) || "";
  },

  /** 获取当前用户手机号 */
  getUserPhone(): string {
    return uni.getStorageSync(USER_PHONE_KEY) || "";
  },

  /**
   * 退出登录 — 调用后端API + 清除本地token + 暂停上传队列
   */
  async logout(): Promise<void> {
    // 调后端退出接口
    try {
      await request({
        url: "/auth/logout",
        method: "POST",
      });
    } catch {
      // 即使接口失败也继续本地清理
    }

    // 清除本地 token
    this.logoutLocal();
  },

  /** 仅本地清理 token */
  logoutLocal(): void {
    uni.removeStorageSync(ACCESS_TOKEN_KEY);
    uni.removeStorageSync(REFRESH_TOKEN_KEY);
    uni.removeStorageSync(USER_PHONE_KEY);
  },

  /**
   * 需要登录 — 未登录跳转到登录页
   * @returns true 已登录，false 已跳转登录
   */
  needLogin(): boolean {
    if (this.isLoggedIn()) return true;
    const pages = getCurrentPages();
    const currentPage = pages[pages.length - 1];
    const currentRoute = currentPage ? `/${currentPage.route}` : "";
    const redirectParam = currentRoute ? `?redirect=${encodeURIComponent(currentRoute)}` : "";
    uni.navigateTo({
      url: `/pages/login/login${redirectParam}`,
    });
    return false;
  },

  /**
   * 登录后合并本地未同步记录
   * - 检测 needsAccountBind 标记的记录
   * - 弹窗确认后批量绑定 userId 并入队上传
   */
  async mergeLocalRecords(): Promise<void> {
    const records = RecordRepository.getAll();
    const unboundRecords = records.filter(
      (r) => (r as any).needsAccountBind === true || !r.userId
    );

    if (unboundRecords.length === 0) return;

    // 弹窗确认
    return new Promise<void>((resolve) => {
      uni.showModal({
        title: "合并记录",
        content: `发现 ${unboundRecords.length} 条未同步记录，是否合并到云端？`,
        confirmText: "合并",
        cancelText: "跳过",
        success: async (res) => {
          if (res.confirm) {
            const userId = uni.getStorageSync("userId") || "";
            for (const record of unboundRecords) {
              record.userId = userId;
              delete (record as any).needsAccountBind;
              record.status = "queued";
              record.updatedAt = new Date().toISOString();
              RecordRepository.update(record);

              // 入队上传
              if (record.media.length > 0) {
                record.media.forEach((media, index) => {
                  if (media.localPath) {
                    UploadQueueService.enqueue(record.id, index, media.localPath);
                  }
                });
              } else {
                // 无媒体的记录，直接同步元数据
                try {
                  await UploadQueueService.syncRecordMetadata(record);
                  record.status = "synced";
                  record.updatedAt = new Date().toISOString();
                  RecordRepository.update(record);
                } catch {
                  record.status = "failed";
                  record.failReason = "元数据同步失败";
                  record.updatedAt = new Date().toISOString();
                  RecordRepository.update(record);
                }
              }
            }
            uni.showToast({ title: "记录已合并", icon: "success" });
          }
          resolve();
        },
        fail: () => resolve(),
      });
    });
  },
};
