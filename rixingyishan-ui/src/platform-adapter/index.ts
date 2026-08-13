import type { PlatformMediaAdapter } from "./types";

/**
 * P1-03: 从 storage 读取 settings_video_duration 作为录像时长限制
 */
function getVideoMaxDuration(): number {
  const saved = uni.getStorageSync("settings_video_duration");
  if (saved) {
    const parsed = parseInt(saved, 10);
    if (parsed > 0 && parsed <= 300) return parsed;
  }
  return 30; // 默认30秒
}

export const uniAppMediaAdapter: PlatformMediaAdapter = {
  async canTakePhoto(): Promise<boolean> {
    return new Promise((resolve) => {
      uni.authorize({
        scope: "scope.camera",
        success: () => resolve(true),
        fail: () => resolve(false),
      });
    });
  },

  async canRecordVideo(): Promise<boolean> {
    return new Promise((resolve) => {
      uni.authorize({
        scope: "scope.camera",
        success: () => resolve(true),
        fail: () => resolve(false),
      });
    });
  },

  async takePhoto(): Promise<{ localPath: string; width?: number; height?: number }> {
    return new Promise((resolve, reject) => {
      uni.chooseImage({
        count: 1,
        sourceType: ["camera"],
        sizeType: ["compressed"],
        success: (res) => {
          const tempFilePath = res.tempFilePaths[0];
          resolve({
            localPath: tempFilePath,
          });
        },
        fail: (err) => reject(err),
      });
    });
  },

  async recordVideo(): Promise<{
    localPath: string;
    durationMs?: number;
    sizeBytes?: number;
  }> {
    const maxDuration = getVideoMaxDuration();
    return new Promise((resolve, reject) => {
      uni.chooseVideo({
        sourceType: ["camera"],
        maxDuration,
        camera: "back",
        success: (res) => {
          resolve({
            localPath: res.tempFilePath,
            durationMs: res.duration * 1000,
            sizeBytes: res.size,
          });
        },
        fail: (err) => reject(err),
      });
    });
  },

  async chooseFromAlbum(): Promise<{
    localPath: string;
    mimeType: string;
    width?: number;
    height?: number;
    sizeBytes?: number;
  }> {
    return new Promise((resolve, reject) => {
      uni.chooseMedia({
        count: 1,
        mediaType: ["image", "video"],
        sourceType: ["album"],
        success: (res) => {
          const file = res.tempFiles[0];
          resolve({
            localPath: file.tempFilePath,
            mimeType: file.fileType === "video" ? "video/mp4" : "image/jpeg",
            sizeBytes: file.size,
          });
        },
        fail: (err) => reject(err),
      });
    });
  },
};
