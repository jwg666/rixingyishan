export class Constants {
  static readonly API_BASE: string = 'https://rxys.qdyhjz.cn/rxys/api';
  static readonly KEY_RECORDS: string = 'good_deeds_records';
  static readonly KEY_UPLOAD_TASKS: string = 'good_deeds_upload_tasks';
  static readonly KEY_TEMP_MEDIA: string = 'good_deeds_temp_media';
  static readonly KEY_ACCESS_TOKEN: string = 'accessToken';
  static readonly KEY_REFRESH_TOKEN: string = 'refreshToken';
  static readonly KEY_USER_PHONE: string = 'userPhone';
  static readonly KEY_USER_ID: string = 'userId';
  static readonly KEY_WIFI_ONLY: string = 'settings_wifi_only';
  static readonly KEY_VIDEO_DURATION: string = 'settings_video_duration';
  static readonly DEFAULT_VIDEO_DURATION: number = 30;
  static readonly UPLOAD_MAX_RETRY: number = 3;
  static readonly UPLOAD_RETRY_DELAYS_MS: number[] = [2000, 5000, 10000];
}
