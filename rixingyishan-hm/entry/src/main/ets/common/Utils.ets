/** 通用工具 — id 生成、日期格式化、文案映射等 */

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).slice(2);
}

export function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}

/** 本地时区 YYYY-MM-DD */
export function dayKeyOf(d: Date): string {
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function todayKey(): string {
  return dayKeyOf(new Date());
}

export function formatTime(isoString: string): string {
  const d = new Date(isoString);
  if (isNaN(d.getTime())) {
    return '';
  }
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${h}:${m}`;
}

export function formatFullTime(isoString: string): string {
  const d = new Date(isoString);
  if (isNaN(d.getTime())) {
    return '';
  }
  const month = (d.getMonth() + 1).toString().padStart(2, '0');
  const day = d.getDate().toString().padStart(2, '0');
  const h = d.getHours().toString().padStart(2, '0');
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${d.getFullYear()}-${month}-${day} ${h}:${m}`;
}

/** 标题：自动从内容前 15 字生成 */
export function autoTitle(content: string): string {
  const t = content.trim();
  return t.length > 15 ? t.slice(0, 15) + '…' : t;
}

export function maskPhone(phone: string): string {
  if (!phone || phone.length < 7) {
    return phone || '';
  }
  return `${phone.slice(0, 3)}****${phone.slice(-4)}`;
}

const AVATAR_COLORS: string[] = [
  '#FFD7B5', '#FFE0B2', '#FFCCBC', '#FFE4C4',
  '#FFDAB9', '#FFDDC1', '#F5D5AE', '#FFE5B4'
];

/** 根据 avatarSeed 生成柔和背景色 */
export function getAvatarColor(seed: string): string {
  if (!seed) {
    return '#FFD7B5';
  }
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return AVATAR_COLORS[hash % AVATAR_COLORS.length];
}

/** 从昵称取首字 */
export function getNicknameInitial(nickname: string | null): string {
  if (!nickname) {
    return '?';
  }
  const t = nickname.trim();
  if (!t) {
    return '?';
  }
  return t.charAt(0).toUpperCase();
}

/** 类型文案（首页用：text → 功德） */
export function recordTypeText(type: string): string {
  const map: Record<string, string> = {
    'photo': '图片',
    'video': '视频',
    'text': '功德'
  };
  return map[type] || type;
}

/** 类型文案（详情页用：text → 文字） */
export function recordTypeTextDetail(type: string): string {
  const map: Record<string, string> = {
    'photo': '图片',
    'video': '视频',
    'text': '文字'
  };
  return map[type] || type;
}

export function statusText(status: string): string {
  const map: Record<string, string> = {
    'draft': '草稿',
    'queued': '等待上传',
    'uploading': '上传中',
    'synced': '已同步',
    'failed': '失败'
  };
  return map[status] || status;
}

/** 状态对应的标签底色 */
export function statusBgColor(status: string): string {
  const map: Record<string, string> = {
    'draft': '#F0F0F0',
    'queued': '#FFF0E5',
    'uploading': '#FFF0E5',
    'synced': '#F6FFED',
    'failed': '#FFF1F0'
  };
  return map[status] || '#F0F0F0';
}

/** 状态对应的文字色 */
export function statusFgColor(status: string): string {
  const map: Record<string, string> = {
    'draft': '#999999',
    'queued': '#E8733A',
    'uploading': '#E8733A',
    'synced': '#52C41A',
    'failed': '#FF4D4F'
  };
  return map[status] || '#999999';
}

/** 页面路由参数（router params 需为类实例，避免无类型字面量） */
export class RouteParams {
  type: string = '';
  dayKey: string = '';
  id: string = '';
}

/** 提取 Error 文案 */
export function errorMessage(e: Object | null | undefined, fallback: string): string {
  if (e instanceof Error) {
    return e.message || fallback;
  }
  return fallback;
}
