import type { MediaItem } from "@/types";

const MAX_IMAGE_SIZE = 10 * 1024 * 1024;
const MAX_VIDEO_SIZE = 50 * 1024 * 1024;
const MAX_VIDEO_DURATION = 60000;

const ALLOWED_IMAGE_MIMES = ["image/jpeg", "image/png", "image/webp"];
const ALLOWED_VIDEO_MIMES = ["video/mp4", "video/quicktime"];

export interface ValidationResult {
  valid: boolean;
  error?: string;
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

    if (media.durationMs && media.durationMs > MAX_VIDEO_DURATION) {
      return {
        valid: false,
        error: `视频时长超过限制 (${MAX_VIDEO_DURATION / 1000}秒)`,
      };
    }

    return { valid: true };
  },
};
