export interface PlatformMediaAdapter {
  canTakePhoto(): Promise<boolean>;
  canRecordVideo(): Promise<boolean>;
  takePhoto(): Promise<{ localPath: string; width?: number; height?: number }>;
  recordVideo(): Promise<{
    localPath: string;
    durationMs?: number;
    sizeBytes?: number;
  }>;
  chooseFromAlbum(): Promise<{
    localPath: string;
    mimeType: string;
    width?: number;
    height?: number;
    sizeBytes?: number;
  }>;
}
