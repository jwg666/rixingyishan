import type { MediaItem } from "@/types";

const MAX_IMAGE_SIZE = 10 * 1024 * 1024;
const MAX_VIDEO_SIZE = 50 * 1024 * 1024;

const ALLOWED_IMAGE_MIMES = ["image/jpeg", "image/png", "image/webp"];
const ALLOWED_VIDEO_MIMES = ["video/mp4", "video/quicktime"];

export interface ValidationResult {
  valid: boolean;
  error?: string;
}

/**
 * P1-03: 从 storage 读取 settings_video_duration（默认30秒）
 */
function getMaxVideoDuration(): number {
  const saved = uni.getStorageSync("settings_video_duration");
  if (saved) {
    const parsed = parseInt(saved, 10);
    if (parsed > 0 && parsed <= 300) return parsed * 1000;
  }
  return 30000; // 默认30秒
}

export const MediaValidationService = {
  validateMedia(media: MediaItem, type: "photo" | "video"): ValidationResult {
    if (type === "photo") {
      return this.validateImage(media);
    }
    return this.validateVideo(media);
  },

  validateImage(media: MediaItem): ValidationResult {
    if (!ALLOWED_IMAGE_MIMES.includes(media.mimeType)) {
      return {
        valid: false,
        error: `不支持的图片格式: ${media.mimeType}`,
      };
    }

    if (media.sizeBytes && media.sizeBytes > MAX_IMAGE_SIZE) {
      return {
        valid: false,
        error: `图片大小超过限制 (${MAX_IMAGE_SIZE / 1024 / 1024}MB)`,
      };
    }

    return { valid: true };
  },

  validateVideo(media: MediaItem): ValidationResult {
    if (!ALLOWED_VIDEO_MIMES.includes(media.mimeType)) {
      return {
        valid: false,
        error: `不支持的视频格式: ${media.mimeType}`,
      };
    }

    if (media.sizeBytes && media.sizeBytes > MAX_VIDEO_SIZE) {
      return {
        valid: false,
        error: `视频大小超过限制 (${MAX_VIDEO_SIZE / 1024 / 1024}MB)`,
      };
    }

    const maxDuration = getMaxVideoDuration();
    if (media.durationMs && media.durationMs > maxDuration) {
      return {
        valid: false,
        error: `视频时长超过限制 (${maxDuration / 1000}秒)`,
      };
    }

    return { valid: true };
  },
};
