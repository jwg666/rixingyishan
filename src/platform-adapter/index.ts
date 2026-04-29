import type { PlatformMediaAdapter } from "./types";

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
    return new Promise((resolve, reject) => {
      uni.chooseVideo({
        sourceType: ["camera"],
        maxDuration: 30,
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
