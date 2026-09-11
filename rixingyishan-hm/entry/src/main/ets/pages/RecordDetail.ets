import { router, promptAction } from '@kit.ArkUI';
import { RecordRepository } from '../services/RecordRepository';
import { RecordApiService } from '../services/RecordApiService';
import { UploadQueueService } from '../services/UploadQueueService';
import { GoodDeedRecord, MediaItem } from '../model/Types';
import { Theme } from '../common/Theme';
import { recordTypeTextDetail, statusText, statusBgColor, statusFgColor, formatFullTime, errorMessage } from '../common/Utils';

/**
 * 记录详情页 — 详情 / 媒体预览 / 失败重试 / 删除（含服务端删除同步）
 */
@Entry
@Component
struct RecordDetail {
  @State record: GoodDeedRecord | null = null;
  @State previewSrc: string = '';
  @State playingVideoSrc: string = '';
  private recordId: string = '';
  private videoController: VideoController = new VideoController();

  aboutToAppear(): void {
    const params = router.getParams();
    if (params !== undefined && params !== null) {
      const p = params as Record<string, string>;
      if (p['id']) {
        this.recordId = p['id'];
      }
    }
    this.loadRecord();
  }

  private loadRecord(): void {
    const found = RecordRepository.getById(this.recordId);
    if (found !== null) {
      this.record = found;
    } else {
      promptAction.showToast({ message: '记录不存在', duration: 2000 });
      setTimeout(() => {
        router.back();
      }, 800);
    }
  }

  private mediaSrc(m: MediaItem): string {
    return m.remoteUrl || m.localPath || '';
  }

  /** 失败重试：纯文本重推元数据；带媒体重新置 queued（上传队列恢复处理） */
  private async retryPush(): Promise<void> {
    const rec = this.record;
    if (rec === null) {
      return;
    }
    if (rec.media.length > 0) {
      UploadQueueService.retryRecordTasks(rec.id);
      this.record = RecordRepository.getById(rec.id);
      promptAction.showToast({ message: '已重新排队上传', duration: 2000 });
      return;
    }
    try {
      const resp = await RecordApiService.create({
        type: rec.type,
        content: rec.content,
        tag: rec.tags && rec.tags.length > 0 ? rec.tags[0] : '其他善行',
        meritValue: rec.meritValue || 0,
        recordDate: rec.dayKey,
        media: []
      });
      rec.serverRecordId = String(resp.data.serverRecordId);
      rec.syncVersion = resp.data.syncVersion || 1;
      rec.serverUpdatedAt = resp.data.record && resp.data.record.updatedAt
        ? resp.data.record.updatedAt : new Date().toISOString();
      if (resp.data.meritValue) {
        rec.meritValue = resp.data.meritValue;
      }
      rec.status = 'synced';
      rec.failReason = undefined;
      rec.needsAccountBind = false;
      rec.updatedAt = new Date().toISOString();
      RecordRepository.update(rec);
      this.record = rec;
      promptAction.showToast({ message: '同步成功', duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: errorMessage(e, '重试失败'), duration: 2000 });
    }
  }

  private confirmDelete(): void {
    AlertDialog.show({
      title: '确认删除',
      message: '删除后无法恢复，确定要删除这条记录吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: () => {
          this.doDelete();
        }
      }
    });
  }

  private async doDelete(): Promise<void> {
    const rec = this.record;
    if (rec === null) {
      return;
    }
    if (rec.serverRecordId && rec.serverRecordId !== '') {
      try {
        await RecordApiService.remove(rec.serverRecordId);
      } catch (e) {
        // 服务端删除失败仍删除本地副本，远端会随下次合并清理
      }
    }
    RecordRepository.delete(rec.id);
    promptAction.showToast({ message: '已删除', duration: 2000 });
    setTimeout(() => {
      router.back();
    }, 600);
  }

  build() {
    Stack() {
      Column() {
        // 顶栏
        Row() {
          Text('←')
            .fontSize(22)
            .fontColor(Theme.text)
            .onClick(() => {
              router.back();
            })
          Text('记录详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.text)
            .margin({ left: 12 })
        }
        .width('100%')
        .height(48)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        if (this.record !== null) {
          Scroll() {
            Column() {
              // 头部信息
              Column() {
                Row() {
                  Text(recordTypeTextDetail(this.record.type))
                    .fontSize(14)
                    .fontColor('#8B7E74')
                  Blank()
                  Text(statusText(this.record.status))
                    .fontSize(12)
                    .fontColor(statusFgColor(this.record.status))
                    .backgroundColor(statusBgColor(this.record.status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(6)
                }
                .width('100%')
                .margin({ bottom: 8 })

                if (this.record.title) {
                  Text(this.record.title)
                    .fontSize(19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333333')
                    .width('100%')
                    .margin({ bottom: 6 })
                }
                Text(formatFullTime(this.record.createdAt))
                  .fontSize(12)
                  .fontColor('#999999')
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })

              // 内容
              Column() {
                Text(this.record.content)
                  .fontSize(15)
                  .fontColor('#333333')
                  .lineHeight(24)
                  .width('100%')
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })

              // 功德
              if (this.record.meritValue) {
                Text(`本次功德 +${this.record.meritValue} ✨`)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#D4A017')
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding(14)
                  .linearGradient({ angle: 135, colors: [['#FFF0E5', 0], ['#FFE4CC', 1]] })
                  .borderRadius(12)
                  .margin({ bottom: 12 })
              }

              // 自定义标签
              if (this.record.tags && this.record.tags.length > 0) {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(this.record.tags, (t: string) => {
                    Text(`#${t}`)
                      .fontSize(12)
                      .fontColor(Theme.accent)
                      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                      .backgroundColor('#FFF0E5')
                      .borderRadius(6)
                      .margin({ right: 8, bottom: 6 })
                  }, (t: string) => t)
                }
                .width('100%')
                .padding(14)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 12 })
              }

              // 媒体
              if (this.record.media.length > 0) {
                Column() {
                  Text('媒体')
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#333333')
                    .width('100%')
                    .margin({ bottom: 10 })
                  Column({ space: 10 }) {
                    ForEach(this.record.media, (m: MediaItem, idx: number) => {
                      Stack({ alignContent: Alignment.TopEnd }) {
                        if (m.mimeType.includes('video')) {
                          Column() {
                            Text('▶')
                              .fontSize(40)
                              .fontColor('#FFFFFF')
                          }
                          .width('100%')
                          .height(200)
                          .justifyContent(FlexAlign.Center)
                          .backgroundColor('#000000')
                          .borderRadius(10)
                          .onClick(() => {
                            this.playingVideoSrc = this.mediaSrc(m);
                          })
                        } else {
                          Image(this.mediaSrc(m))
                            .width('100%')
                            .height(200)
                            .borderRadius(10)
                            .objectFit(ImageFit.Cover)
                            .onClick(() => {
                              this.previewSrc = this.mediaSrc(m);
                            })
                        }
                        Text(m.remoteUrl ? '已上传' : '未上传')
                          .fontSize(11)
                          .fontColor(Color.White)
                          .backgroundColor(m.remoteUrl ? 'rgba(82,196,26,0.8)' : 'rgba(153,153,153,0.8)')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .borderRadius(6)
                          .margin(8)
                      }
                      .width('100%')
                    }, (m: MediaItem, idx: number) => `detail-media-${idx}`)
                  }
                  .width('100%')
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .padding(14)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 12 })
              }

              // 失败重试
              if (this.record.status === 'failed') {
                Column() {
                  Button('重试上传')
                    .width('100%')
                    .height(44)
                    .fontSize(15)
                    .fontColor(Color.White)
                    .backgroundColor('#FAAD14')
                    .borderRadius(10)
                    .onClick(() => {
                      this.retryPush();
                    })
                  if (this.record.failReason) {
                    Text(`失败原因：${this.record.failReason}`)
                      .fontSize(12)
                      .fontColor('#999999')
                      .margin({ top: 8 })
                  }
                }
                .width('100%')
                .padding(14)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 12 })
              }

              // 删除
              Button('删除记录')
                .width('100%')
                .height(48)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor('#FF4D4F')
                .borderRadius(10)
                .margin({ bottom: 20 })
                .onClick(() => {
                  this.confirmDelete();
                })
            }
            .width('100%')
            .padding(12)
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      // 图片全屏预览
      if (this.previewSrc !== '') {
        Column() {
          Image(this.previewSrc)
            .width('100%')
            .height('80%')
            .objectFit(ImageFit.Contain)
          Text('点击关闭')
            .fontSize(13)
            .fontColor(Color.White)
            .margin({ top: 16 })
            .onClick(() => {
              this.previewSrc = '';
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.92)')
        .onClick(() => {
          this.previewSrc = '';
        })
      }

      // 视频播放
      if (this.playingVideoSrc !== '') {
        Column() {
          Video({
            src: this.playingVideoSrc,
            controller: this.videoController
          })
            .width('100%')
            .height('40%')
            .autoPlay(true)
            .controls(true)
          Text('关闭')
            .fontSize(14)
            .fontColor(Color.White)
            .padding({ left: 20, right: 20, top: 8, bottom: 8 })
            .margin({ top: 16 })
            .borderRadius(16)
            .backgroundColor('rgba(255,255,255,0.2)')
            .onClick(() => {
              this.playingVideoSrc = '';
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.95)')
      }
    }
    .width('100%')
    .height('100%')
  }
}
