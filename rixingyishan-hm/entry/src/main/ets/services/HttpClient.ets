import { http } from '@kit.NetworkKit';
import { router } from '@kit.ArkUI';
import { ApiResponse } from '../model/Types';
import { KvStore } from './KvStore';
import { Constants } from '../common/Constants';

/**
 * HttpClient — 统一请求封装（对齐 H5 request.ts）
 * - 自动附带 Authorization: Bearer <accessToken>
 * - 401 → 单飞刷新（POST /auth/refresh）→ 重试一次；失败清会话并跳登录
 * - 成功 = HTTP 2xx 且 body.code === 0
 */

export interface HttpOptions {
  url: string;
  method: string;
  data?: object | null;
  skipAuth?: boolean;
}

export class HttpClient {
  private static refreshing: Promise<boolean> | null = null;

  static async get<T>(url: string, skipAuth: boolean = false): Promise<ApiResponse<T>> {
    const opts: HttpOptions = { url: url, method: 'GET', skipAuth: skipAuth };
    return HttpClient.request<T>(opts);
  }

  static async post<T>(url: string, data: object | null, skipAuth: boolean = false): Promise<ApiResponse<T>> {
    const opts: HttpOptions = { url: url, method: 'POST', data: data, skipAuth: skipAuth };
    return HttpClient.request<T>(opts);
  }

  static async patch<T>(url: string, data: object | null): Promise<ApiResponse<T>> {
    const opts: HttpOptions = { url: url, method: 'PATCH', data: data };
    return HttpClient.request<T>(opts);
  }

  static async del<T>(url: string): Promise<ApiResponse<T>> {
    const opts: HttpOptions = { url: url, method: 'DELETE' };
    return HttpClient.request<T>(opts);
  }

  static async request<T>(opts: HttpOptions): Promise<ApiResponse<T>> {
    try {
      return await HttpClient.raw<T>(opts);
    } catch (e) {
      if (e instanceof AuthError) {
        if (opts.skipAuth) {
          HttpClient.clearSessionAndRedirect();
          throw new Error('未授权');
        }
        const ok = await HttpClient.refreshOnce();
        if (ok) {
          return HttpClient.raw<T>(opts);
        }
        HttpClient.clearSessionAndRedirect();
        throw new Error('登录已过期，请重新登录');
      }
      throw e;
    }
  }

  private static async raw<T>(opts: HttpOptions): Promise<ApiResponse<T>> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json'
    };
    if (!opts.skipAuth) {
      const token = KvStore.getString(Constants.KEY_ACCESS_TOKEN);
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }

    const method = opts.method as http.HttpMethod;
    const options: http.HttpRequestOptions = {
      method: method,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 15000,
      readTimeout: 30000
    };
    if (opts.data !== null && opts.data !== undefined) {
      options.extraData = JSON.stringify(opts.data);
    }

    const req = http.createHttp();
    let statusCode = 0;
    let bodyText = '';
    try {
      const resp = await req.request(Constants.API_BASE + opts.url, options);
      statusCode = resp.responseCode;
      if (typeof resp.result === 'string') {
        bodyText = resp.result as string;
      } else {
        bodyText = JSON.stringify(resp.result);
      }
    } catch (e) {
      throw new Error('网络请求失败，请检查网络');
    } finally {
      req.destroy();
    }

    if (statusCode === 401) {
      throw new AuthError();
    }

    let body: ApiResponse<T> | null = null;
    try {
      body = JSON.parse(bodyText) as ApiResponse<T>;
    } catch (e) {
      body = null;
    }

    if (statusCode >= 200 && statusCode < 300) {
      if (body !== null && body.code === 0) {
        return body;
      }
      throw new Error((body && body.message) || '请求失败');
    }
    throw new Error((body && body.message) || `请求失败 (${statusCode})`);
  }

  /** 单飞刷新 token：并发 401 时只发起一次刷新 */
  private static refreshOnce(): Promise<boolean> {
    if (HttpClient.refreshing !== null) {
      return HttpClient.refreshing;
    }
    HttpClient.refreshing = HttpClient.doRefresh().finally(() => {
      HttpClient.refreshing = null;
    });
    return HttpClient.refreshing;
  }

  private static async doRefresh(): Promise<boolean> {
    const refreshToken = KvStore.getString(Constants.KEY_REFRESH_TOKEN);
    if (!refreshToken) {
      return false;
    }
    const body: Record<string, string> = { 'refreshToken': refreshToken };
    const opts: HttpOptions = { url: '/auth/refresh', method: 'POST', data: body, skipAuth: true };
    try {
      const resp = await HttpClient.raw<{ accessToken: string; refreshToken: string }>(opts);
      KvStore.setString(Constants.KEY_ACCESS_TOKEN, resp.data.accessToken);
      KvStore.setString(Constants.KEY_REFRESH_TOKEN, resp.data.refreshToken);
      return true;
    } catch (e) {
      return false;
    }
  }

  static clearSessionAndRedirect(): void {
    KvStore.remove(Constants.KEY_ACCESS_TOKEN);
    KvStore.remove(Constants.KEY_REFRESH_TOKEN);
    try {
      router.pushUrl({ url: 'pages/Login' });
    } catch (e) {
      // 非 UI 上下文时跳转失败，静默；页面会在自身 onShow 检查登录态
    }
  }
}

/** 401 内部标记错误 */
class AuthError extends Error {
  constructor() {
    super('未授权');
  }
}
