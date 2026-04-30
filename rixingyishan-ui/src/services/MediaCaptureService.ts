import { uniAppMediaAdapter } from "@/platform-adapter";
import type { MediaItem } from "@/types";

export interface CaptureResult {
  media: MediaItem;
  type: "photo" | "video";
}

export const MediaCaptureService = {
  async takePhoto(): Promise<CaptureResult> {
    const result = await uniAppMediaAdapter.takePhoto();
    return {
      type: "photo",
      media: {
        localPath: result.localPath,
        mimeType: "image/jpeg",
        width: result.width,
        height: result.height,
      },
    };
  },

  async recordVideo(): Promise<CaptureResult> {
    const result = await uniAppMediaAdapter.recordVideo();
    return {
      type: "video",
      media: {
        localPath: result.localPath,
        mimeType: "video/mp4",
        durationMs: result.durationMs,
        sizeBytes: result.sizeBytes,
      },
    };
  },

  async chooseFromAlbum(): Promise<CaptureResult> {
    const result = await uniAppMediaAdapter.chooseFromAlbum();
    const isVideo = result.mimeType.startsWith("video");
    return {
      type: isVideo ? "video" : "photo",
      media: {
        localPath: result.localPath,
        mimeType: result.mimeType,
        width: result.width,
        height: result.height,
        sizeBytes: result.sizeBytes,
      },
    };
  },

  async checkCameraPermission(): Promise<boolean> {
    const canPhoto = await uniAppMediaAdapter.canTakePhoto();
    return canPhoto;
  },
};
