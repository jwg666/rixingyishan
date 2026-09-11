import { cameraPicker, camera } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';
import fs from '@ohos.file.fs';
import { MediaItem } from '../model/Types';

/**
 * MediaCaptureService — 拍照 / 录像 / 相册选择
 * cameraPicker 与 PhotoViewPicker 均为系统 Picker，无需申请相机/媒体权限。
 */

function statSize(uri: string): number {
  try {
    const st = fs.statSync(uri);
    return st.size;
  } catch (e) {
    return 0;
  }
}

function mimeFromUri(uri: string, isVideo: boolean): string {
  const lower = uri.toLowerCase();
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.mp4')) {
    return 'video/mp4';
  }
  if (lower.endsWith('.mov')) {
    return 'video/quicktime';
  }
  return isVideo ? 'video/mp4' : 'image/jpeg';
}

export class MediaCaptureService {
  /** 拍照（后摄） */
  static async takePhoto(context: common.UIAbilityContext): Promise<MediaItem> {
    const profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
    };
    const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile);
    const uri = result.resultUri;
    if (!uri) {
      throw new Error('取消');
    }
    const item: MediaItem = {
      localPath: uri,
      mimeType: mimeFromUri(uri, false),
      sizeBytes: statSize(uri)
    };
    return item;
  }

  /** 录像（后摄），时长由 MediaValidationService 依据设置校验 */
  static async recordVideo(context: common.UIAbilityContext): Promise<MediaItem> {
    const profile: cameraPicker.PickerProfile = {
      cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
    };
    const result = await cameraPicker.pick(context, [cameraPicker.PickerMediaType.VIDEO], profile);
    const uri = result.resultUri;
    if (!uri) {
      throw new Error('取消');
    }
    const item: MediaItem = {
      localPath: uri,
      mimeType: mimeFromUri(uri, true),
      sizeBytes: statSize(uri)
    };
    return item;
  }

  /** 相册选择（图/视频混合，最多 9 项） */
  static async chooseFromAlbum(): Promise<MediaItem[]> {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const opts: photoAccessHelper.PhotoSelectOptions = {
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE,
      maxSelectNumber: 9
    };
    const result: photoAccessHelper.PhotoSelectResult = await picker.select(opts);
    const items: MediaItem[] = [];
    if (!result.photoUris || result.photoUris.length === 0) {
      return items;
    }
    for (const uri of result.photoUris) {
      const isVideo = uri.toLowerCase().includes('video');
      const item: MediaItem = {
        localPath: uri,
        mimeType: mimeFromUri(uri, isVideo),
        sizeBytes: statSize(uri)
      };
      items.push(item);
    }
    return items;
  }
}
