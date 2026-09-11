import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MediaCaptureService } from '../services/MediaCaptureService';
import { MediaValidationService, ValidationResult } from '../services/MediaValidationService';
import { RecordRepository } from '../services/RecordRepository';
import { RecordApiService } from '../services/RecordApiService';
import { MeritService } from '../services/MeritService';
import { AuthService } from '../services/AuthService';
import { KvStore } from '../services/KvStore';
import { GoodDeedRecord, MediaItem, MeritTag, RecordType } from '../model/Types';
import { Theme } from '../common/Theme';
import { todayKey, autoTitle, generateId, errorMessage } from '../common/Utils';

/**
 * 新建记录页 — 内容 + 功德标签/智能匹配 + 自定义标签 + 拍照/录像/相册
 */
@Entry
@Component
struct CreateRecord {
  @State targetDayKey: string = todayKey();
  @State content: string = '';
  @State customTags: string[] = [];
  @State newTag: string = '';
  @State media: MediaItem[] = [];
  @State meritTags: MeritTag[] = [];
  @State selectedTagId: number = -1;
  @State matchHint: string = '';
  @State isSubmitting: boolean = false;
  private matchTimerId: number = -1;
  private smartTipShown: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams();
    if (params !== undefined && params !== null) {
      const p = params as Record<string, string>;
      const dayKey = p['dayKey'];
      if (dayKey && /^\d{4}-\d{2}-\d{2}$/.test(dayKey)) {
        this.targetDayKey = dayKey;
      }
    }
    this.smartTipShown = KvStore.getString('smartLoginTipShown') === 'true';
    this.loadMeritTags();
  }

  aboutToDisappear(): void {
    if (this.matchTimerId >= 0) {
      clearTimeout(this.matchTimerId);
      this.matchTimerId = -1;
    }
  }

  private isToday(): boolean {
    return this.targetDayKey === todayKey();
  }

  private currentMeritValue(): number {
    for (const t of this.meritTags) {
      if (t.id === this.selectedTagId) {
        return t.meritValue;
      }
    }
    return 0;
  }

  private async loadMeritTags(): Promise<void> {
    try {
      this.meritTags = await MeritService.getTags();
    } catch (e) {
      // 静默失败
    }
  }

  /** 内容输入防抖智能匹配标签 */
  private onContentChanged(v: string): void {
    this.content = v;
    if (this.matchTimerId >= 0) {
      clearTimeout(this.matchTimerId);
    }
    this.matchTimerId = setTimeout(() => {
      this.doMatchTag();
    }, 300);
  }

  private async doMatchTag(): Promise<void> {
    const trimmed = this.content.trim();
    if (!trimmed) {
      this.matchHint = '';
      return;
    }
    const tag = await MeritService.matchTag(trimmed);
    if (tag !== null) {
      this.matchHint = `推荐标签：${tag.icon} ${tag.name}`;
      if (this.selectedTagId < 0) {
        this.selectedTagId = tag.id;
      }
    } else {
      this.matchHint = '';
    }
  }

  private selectTag(id: number): void {
    this.selectedTagId = this.selectedTagId === id ? -1 : id;
  }

  private addCustomTag(): void {
    const tag = this.newTag.trim();
    if (tag && !this.customTags.includes(tag)) {
      this.customTags.push(tag);
      this.customTags = this.customTags.slice();
    }
    this.newTag = '';
  }

  private removeCustomTag(index: number): void {
    this.customTags.splice(index, 1);
    this.customTags = this.customTags.slice();
  }

  private async takePhoto(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const item = await MediaCaptureService.takePhoto(ctx);
      const vr: ValidationResult = MediaValidationService.validateMedia(item, 'photo');
      if (vr.valid) {
        this.media = this.media.concat([item]);
      } else {
        promptAction.showToast({ message: vr.error || '校验失败', duration: 2000 });
      }
    } catch (e) {
      // 用户取消不提示
    }
  }

  private async recordVideo(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const item = await MediaCaptureService.recordVideo(ctx);
      const vr: ValidationResult = MediaValidationService.validateMedia(item, 'video');
      if (vr.valid) {
        this.media = this.media.concat([item]);
      } else {
        promptAction.showToast({ message: vr.error || '校验失败', duration: 2000 });
      }
    } catch (e) {
      // 用户取消不提示
    }
  }

  private async chooseFromAlbum(): Promise<void> {
    try {
      const items = await MediaCaptureService.chooseFromAlbum();
      const accepted: MediaItem[] = [];
      for (const item of items) {
        const isVideo = item.mimeType.includes('video');
        const vr: ValidationResult = MediaValidationService.validateMedia(item, isVideo ? 'video' : 'photo');
        if (vr.valid) {
          accepted.push(item);
        } else {
          promptAction.showToast({ message: vr.error || '校验失败', duration: 2000 });
        }
      }
      if (accepted.length > 0) {
        this.media = this.media.concat(accepted);
      }
    } catch (e) {
      promptAction.showToast({ message: errorMessage(e, '选择失败'), duration: 2000 });
    }
  }

  private removeMedia(index: number): void {
    this.media.splice(index, 1);
    this.media = this.media.slice();
  }

  private recordTypeOf(): RecordType {
    if (this.media.length === 0) {
      return 'text';
    }
    const hasVideo = this.media.some((m) => m.mimeType.includes('video'));
    const hasImage = this.media.some((m) => m.mimeType.startsWith('image'));
    if (hasVideo) {
      return 'video';
    }
    if (hasImage) {
      return 'photo';
    }
    return 'text';
  }

  private async submitRecord(): Promise<void> {
    if (!this.content.trim()) {
      promptAction.showToast({ message: '请输入内容', duration: 2000 });
      return;
    }
    this.isSubmitting = true;
    try {
      const now = new Date().toISOString();
      const tags = this.customTags.length > 0 ? this.customTags.slice() : undefined;
      const record: GoodDeedRecord = {
        id: generateId(),
        type: this.recordTypeOf(),
        title: autoTitle(this.content),
        content: this.content,
        media: this.media.slice(),
        dayKey: this.targetDayKey,
        createdAt: now,
        updatedAt: now,
        status: 'draft',
        tags: tags,
        meritTagId: this.selectedTagId > 0 ? this.selectedTagId : undefined,
        meritValue: this.currentMeritValue() || undefined
      };
      if (!AuthService.isLoggedIn()) {
        record.needsAccountBind = true;
      }
      RecordRepository.insert(record);

      if (record.media.length > 0) {
        // 带媒体：置 queued，由上传队列完成媒体上传后推送元数据（Task 8 接管入队）
        record.status = 'queued';
        RecordRepository.update(record);
      } else if (AuthService.isLoggedIn()) {
        // 纯文本 + 已登录：直接同步
        try {
          const resp = await RecordApiService.create({
            type: record.type,
            content: record.content,
            tag: record.tags && record.tags.length > 0 ? record.tags[0] : '其他善行',
            meritValue: record.meritValue || 0,
            recordDate: record.dayKey,
            media: []
          });
          record.serverRecordId = String(resp.data.serverRecordId);
          record.syncVersion = resp.data.syncVersion || 1;
          record.serverUpdatedAt = resp.data.record && resp.data.record.updatedAt
            ? resp.data.record.updatedAt : now;
          if (resp.data.meritValue) {
            record.meritValue = resp.data.meritValue;
          }
          record.status = 'synced';
          RecordRepository.update(record);
        } catch (e) {
          record.status = 'failed';
          record.failReason = '同步失败，可稍后重试';
          RecordRepository.update(record);
        }
      }

      promptAction.showToast({ message: '保存成功', duration: 2000 });
      if (!this.smartTipShown) {
        KvStore.setString('smartLoginTipShown', 'true');
        if (!AuthService.isLoggedIn()) {
          setTimeout(() => {
            promptAction.showToast({ message: '登录可云端保存，不怕丢失', duration: 3000 });
          }, 800);
        }
      }
      setTimeout(() => {
        router.back();
      }, 600);
    } catch (e) {
      promptAction.showToast({ message: '保存失败', duration: 2000 });
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Column() {
      // 顶栏
      Row() {
        Text('←')
          .fontSize(22)
          .fontColor(Theme.text)
          .onClick(() => {
            router.back();
          })
        Text('新建记录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .margin({ left: 12 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column() {
          // 日期提示
          Row({ space: 8 }) {
            Text('📅').fontSize(14)
            Text(this.isToday() ? '记录日期：今天' : `记录日期：${this.targetDayKey}`)
              .fontSize(13)
              .fontColor('#8B5A2B')
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .backgroundColor(this.isToday() ? '#FFF0E5' : '#FFE8D6')
          .borderRadius(10)
          .margin({ bottom: 12 })

          // 表单
          Column() {
            Text('内容 *')
              .fontSize(14)
              .fontColor('#333333')
              .width('100%')
              .margin({ bottom: 8 })
            TextArea({ text: this.content, placeholder: '记录今天的好事...', placeholderColor: '#C7B29C' })
              .maxLength(500)
              .fontSize(15)
              .fontColor(Theme.text)
              .backgroundColor('#FFF8F0')
              .borderRadius(10)
              .width('100%')
              .height(100)
              .padding(10)
              .onChange((v: string) => {
                this.onContentChanged(v);
              })

            Text('功德标签')
              .fontSize(14)
              .fontColor('#333333')
              .width('100%')
              .margin({ top: 16, bottom: 8 })
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.meritTags, (t: MeritTag) => {
                  Row({ space: 4 }) {
                    Text(t.icon).fontSize(13)
                    Text(t.name)
                      .fontSize(12)
                      .fontColor(this.selectedTagId === t.id ? Color.White : Theme.accent)
                    Text(`+${t.meritValue}`)
                      .fontSize(11)
                      .fontColor('#D4A017')
                      .fontWeight(FontWeight.Medium)
                  }
                  .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                  .borderRadius(16)
                  .backgroundColor(this.selectedTagId === t.id ? Theme.accent : '#FFF0E5')
                  .onClick(() => {
                    this.selectTag(t.id);
                  })
                }, (t: MeritTag) => `${t.id}`)
              }
              .padding({ top: 2, bottom: 2 })
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')

            if (this.matchHint) {
              Text(`🤖 ${this.matchHint}`)
                .fontSize(12)
                .fontColor('#8B7E74')
                .width('100%')
                .margin({ top: 6 })
            }

            Text('自定义标签')
              .fontSize(14)
              .fontColor('#333333')
              .width('100%')
              .margin({ top: 16, bottom: 8 })
            Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
              ForEach(this.customTags, (t: string, idx: number) => {
                Row({ space: 4 }) {
                  Text(t).fontSize(12).fontColor(Theme.accent)
                  Text('×')
                    .fontSize(14)
                    .fontColor(Theme.accent)
                    .onClick(() => {
                      this.removeCustomTag(idx);
                    })
                }
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .backgroundColor('#FFF0E5')
                .borderRadius(6)
                .margin({ right: 8, bottom: 6 })
              }, (t: string) => t)
              TextInput({ text: this.newTag, placeholder: '输入标签后回车', placeholderColor: '#C7B29C' })
                .fontSize(12)
                .height(32)
                .width(150)
                .backgroundColor(Color.Transparent)
                .padding(0)
                .onChange((v: string) => {
                  this.newTag = v;
                })
                .onSubmit(() => {
                  this.addCustomTag();
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 12 })

          // 媒体
          Column() {
            Text('媒体')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .width('100%')
              .margin({ bottom: 10 })
            Row({ space: 10 }) {
              Button('拍照')
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(Theme.accent)
                .backgroundColor('#FFF0E5')
                .borderRadius(8)
                .onClick(() => {
                  this.takePhoto();
                })
              Button('录像')
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(Theme.accent)
                .backgroundColor('#FFF0E5')
                .borderRadius(8)
                .onClick(() => {
                  this.recordVideo();
                })
              Button('相册')
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(Theme.accent)
                .backgroundColor('#FFF0E5')
                .borderRadius(8)
                .onClick(() => {
                  this.chooseFromAlbum();
                })
            }
            .width('100%')

            if (this.media.length > 0) {
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.media, (m: MediaItem, idx: number) => {
                  Column({ space: 4 }) {
                    if (m.mimeType.includes('video')) {
                      Stack() {
                        Text('▶')
                          .fontSize(26)
                          .fontColor('#999999')
                      }
                      .width(84)
                      .height(84)
                      .backgroundColor('#F0F0F0')
                      .borderRadius(8)
                      .justifyContent(FlexAlign.Center)
                    } else {
                      Image(m.localPath || m.remoteUrl || '')
                        .width(84)
                        .height(84)
                        .borderRadius(8)
                        .objectFit(ImageFit.Cover)
                    }
                    Text('删除')
                      .fontSize(12)
                      .fontColor('#FF4D4F')
                      .onClick(() => {
                        this.removeMedia(idx);
                      })
                  }
                  .margin({ right: 10, top: 8 })
                }, (m: MediaItem, idx: number) => `media-${idx}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 90 })

          // 功德预览 + 提交
          if (this.currentMeritValue() > 0) {
            Text(`本次功德 +${this.currentMeritValue()} ✨`)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#D4A017')
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding(12)
              .linearGradient({ angle: 135, colors: [['#FFF0E5', 0], ['#FFE4CC', 1]] })
              .borderRadius(10)
          }

          Button(this.isSubmitting ? '保存中...' : '保存记录')
            .width('100%')
            .height(48)
            .fontSize(17)
            .fontColor(Color.White)
            .backgroundColor(this.isSubmitting ? '#CCCCCC' : Theme.accent)
            .borderRadius(10)
            .margin({ top: 12 })
            .enabled(!this.isSubmitting)
            .onClick(() => {
              this.submitRecord();
            })
        }
        .width('100%')
        .padding(12)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
