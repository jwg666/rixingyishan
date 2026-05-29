/**
 * AuthService — 认证服务
 * 提供短信验证码登录、token 管理、登录状态查询
 */

import { request } from "./request";

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
  userId: string;
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

    // 保存 token 与手机号
    const data = res.data;
    uni.setStorageSync(ACCESS_TOKEN_KEY, data.accessToken);
    uni.setStorageSync(REFRESH_TOKEN_KEY, data.refreshToken);
    uni.setStorageSync(USER_PHONE_KEY, data.phone);

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
      this.logout();
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

  /** 退出登录，清除本地 token */
  logout(): void {
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
};
