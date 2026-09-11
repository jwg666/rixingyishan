import { MediaItem } from '../model/Types';
import { KvStore } from './KvStore';
import { Constants } from '../common/Constants';

export interface ValidationResult {
  valid: boolean;
  error?: string;
}

const MAX_IMAGE_SIZE: number = 10 * 1024 * 1024;
const MAX_VIDEO_SIZE: number = 50 * 1024 * 1024;

const ALLOWED_IMAGE_MIMES: string[] = ['image/jpeg', 'image/png', 'image/webp'];
const ALLOWED_VIDEO_MIMES: string[] = ['video/mp4', 'video/quicktime'];

/**
 * MediaValidationService — 媒体校验（对齐 H5 MediaValidationService）
 * 图片: jpeg/png/webp ≤ 10MB；视频: mp4/quicktime ≤ 50MB，时长 ≤ 设置上限
 */
export class MediaValidationService {
  /** 设置项 settings_video_duration（秒），默认 30s */
  static getMaxVideoDurationMs(): number {
    const saved = KvStore.getString(Constants.KEY_VIDEO_DURATION);
    if (saved) {
      const parsed = parseInt(saved);
      if (parsed > 0 && parsed <= 300) {
        return parsed * 1000;
      }
    }
    return Constants.DEFAULT_VIDEO_DURATION * 1000;
  }

  static validateMedia(media: MediaItem, type: 'photo' | 'video'): ValidationResult {
    if (type === 'photo') {
      return MediaValidationService.validateImage(media);
    }
    return MediaValidationService.validateVideo(media);
  }

  static validateImage(media: MediaItem): ValidationResult {
    if (!ALLOWED_IMAGE_MIMES.includes(media.mimeType)) {
      const invalid: ValidationResult = { valid: false, error: `不支持的图片格式: ${media.mimeType}` };
      return invalid;
    }
    if (media.sizeBytes && media.sizeBytes > MAX_IMAGE_SIZE) {
      const tooBig: ValidationResult = { valid: false, error: '图片大小超过限制 (10MB)' };
      return tooBig;
    }
    const ok: ValidationResult = { valid: true };
    return ok;
  }

  static validateVideo(media: MediaItem): ValidationResult {
    if (!ALLOWED_VIDEO_MIMES.includes(media.mimeType)) {
      const invalid: ValidationResult = { valid: false, error: `不支持的视频格式: ${media.mimeType}` };
      return invalid;
    }
    if (media.sizeBytes && media.sizeBytes > MAX_VIDEO_SIZE) {
      const tooBig: ValidationResult = { valid: false, error: '视频大小超过限制 (50MB)' };
      return tooBig;
    }
    const maxDuration = MediaValidationService.getMaxVideoDurationMs();
    if (media.durationMs && media.durationMs > maxDuration) {
      const tooLong: ValidationResult = {
        valid: false,
        error: `视频时长超过限制 (${Math.floor(maxDuration / 1000)}秒)`
      };
      return tooLong;
    }
    const ok: ValidationResult = { valid: true };
    return ok;
  }
}
