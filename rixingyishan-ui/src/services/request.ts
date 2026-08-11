/**
 * 统一请求封装 — 基于 uni.request
 * - 自动附带 Authorization: Bearer <accessToken>
 * - 401 时自动用 refreshToken 刷新，刷新失败跳登录
 * - 基础 URL: /rxys/api（nginx 反代到后端 :8866）
 */

const BASE_URL = "/rxys/api";

/** 后端统一响应格式 */
export interface ApiResponse<T = unknown> {
  code: number;
  message: string;
  data: T;
}

/** 请求方法类型 */
type HttpMethod = "GET" | "POST" | "PUT" | "DELETE";

/** 请求选项 */
export interface RequestOptions {
  url: string;
  method?: HttpMethod;
  data?: Record<string, unknown>;
  header?: Record<string, string>;
  /** 是否跳过自动附加 token（登录接口等） */
  skipAuth?: boolean;
}

/** token 刷新锁，防止并发刷新 */
let isRefreshing = false;
let refreshSubscribers: Array<(token: string) => void> = [];

function onRefreshed(token: string): void {
  refreshSubscribers.forEach((cb) => cb(token));
  refreshSubscribers = [];
}

function addRefreshSubscriber(cb: (token: string) => void): void {
  refreshSubscribers.push(cb);
}

/** 发起 uni.request 的底层 Promise 封装 */
function uniRequest<T = unknown>(options: {
  url: string;
  method: HttpMethod;
  data?: Record<string, unknown>;
  header?: Record<string, string>;
}): Promise<ApiResponse<T>> {
  return new Promise((resolve, reject) => {
    uni.request({
      url: options.url,
      method: options.method,
      data: options.data,
      header: options.header,
      success: (res) => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          const body = res.data as ApiResponse<T>;
          if (body.code === 0) {
            resolve(body);
          } else {
            reject(new Error(body.message || "请求失败"));
          }
        } else if (res.statusCode === 401) {
          reject({ isAuthError: true, message: "未授权" });
        } else {
          const body = res.data as ApiResponse<T> | null;
          reject(new Error(body?.message || `请求失败 (${res.statusCode})`));
        }
      },
      fail: (err) => {
        reject(new Error(err.errMsg || "网络请求失败"));
      },
    });
  });
}

/**
 * 刷新 accessToken
 * 返回新的 accessToken，失败返回 null
 */
async function doRefreshToken(): Promise<string | null> {
  const refreshToken = uni.getStorageSync("refreshToken");
  if (!refreshToken) return null;

  try {
    const res = await uniRequest<{ accessToken: string; refreshToken: string }>({
      url: `${BASE_URL}/auth/refresh`,
      method: "POST",
      data: { refreshToken },
    });
    const newAccess = res.data.accessToken;
    const newRefresh = res.data.refreshToken;
    uni.setStorageSync("accessToken", newAccess);
    uni.setStorageSync("refreshToken", newRefresh);
    return newAccess;
  } catch {
    // 刷新失败，清除 token
    uni.removeStorageSync("accessToken");
    uni.removeStorageSync("refreshToken");
    return null;
  }
}

/** 跳转到登录页 */
function navigateToLogin(): void {
  const pages = getCurrentPages();
  const currentPage = pages[pages.length - 1];
  const currentRoute = currentPage ? `/${currentPage.route}` : "";
  const redirectParam = currentRoute ? `?redirect=${encodeURIComponent(currentRoute)}` : "";
  uni.navigateTo({
    url: `/pages/login/login${redirectParam}`,
  });
}

/**
 * 统一请求方法
 */
export async function request<T = unknown>(options: RequestOptions): Promise<ApiResponse<T>> {
  const { url, method = "GET", data, header = {}, skipAuth = false } = options;

  // 附加 Authorization
  if (!skipAuth) {
    const token = uni.getStorageSync("accessToken");
    if (token) {
      header["Authorization"] = `Bearer ${token}`;
    }
  }

  try {
    return await uniRequest<T>({
      url: `${BASE_URL}${url}`,
      method,
      data,
      header,
    });
  } catch (error: unknown) {
    // 401 — 尝试刷新 token
    if (error && typeof error === "object" && "isAuthError" in error) {
      if (skipAuth) {
        navigateToLogin();
        throw new Error("未登录");
      }

      if (isRefreshing) {
        // 等待刷新完成
        return new Promise<ApiResponse<T>>((resolve, reject) => {
          addRefreshSubscriber((newToken: string) => {
            header["Authorization"] = `Bearer ${newToken}`;
            uniRequest<T>({
              url: `${BASE_URL}${url}`,
              method,
              data,
              header,
            })
              .then(resolve)
              .catch(reject);
          });
        });
      }

      isRefreshing = true;
      const newToken = await doRefreshToken();
      isRefreshing = false;

      if (newToken) {
        onRefreshed(newToken);
        header["Authorization"] = `Bearer ${newToken}`;
        return uniRequest<T>({
          url: `${BASE_URL}${url}`,
          method,
          data,
          header,
        });
      } else {
        navigateToLogin();
        throw new Error("登录已过期，请重新登录");
      }
    }

    throw error;
  }
}

/** GET 便捷方法 */
export function get<T = unknown>(url: string, data?: Record<string, unknown>): Promise<ApiResponse<T>> {
  return request<T>({ url, method: "GET", data });
}

/** POST 便捷方法 */
export function post<T = unknown>(url: string, data?: Record<string, unknown>): Promise<ApiResponse<T>> {
  return request<T>({ url, method: "POST", data });
}

/** PUT 便捷方法 */
export function put<T = unknown>(url: string, data?: Record<string, unknown>): Promise<ApiResponse<T>> {
  return request<T>({ url, method: "PUT", data });
}

/** DELETE 便捷方法 */
export function del<T = unknown>(url: string, data?: Record<string, unknown>): Promise<ApiResponse<T>> {
  return request<T>({ url, method: "DELETE", data });
}
