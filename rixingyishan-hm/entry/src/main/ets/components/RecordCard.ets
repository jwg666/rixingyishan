import { GoodDeedRecord, MediaItem } from '../model/Types';
import { Theme } from '../common/Theme';
import { recordTypeText, statusText, statusBgColor, statusFgColor, formatTime } from '../common/Utils';

/**
 * RecordCard — 首页记录卡片（类型/状态/标题/缩略图/时间/功德）
 */
@Component
export struct RecordCard {
  record: GoodDeedRecord = {
    id: '',
    type: 'text',
    content: '',
    media: [],
    dayKey: '',
    createdAt: '',
    updatedAt: '',
    status: 'draft'
  };
  onCardClick: () => void = () => {};

  private thumbSrc(m: MediaItem | undefined): string {
    if (m === undefined) {
      return '';
    }
    return m.localPath || m.remoteUrl || '';
  }

  build() {
    Column() {
      Row() {
        Text(recordTypeText(this.record.type))
          .fontSize(12)
          .fontColor('#8B7E74')
        Blank()
        if (this.record.status !== 'draft') {
          Text(statusText(this.record.status))
            .fontSize(11)
            .fontColor(statusFgColor(this.record.status))
            .backgroundColor(statusBgColor(this.record.status))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(6)
        }
      }
      .width('100%')
      .margin({ bottom: 8 })

      Text(this.record.title || this.record.content || '无内容')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3A2A1A')
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.record.title && this.record.content !== this.record.title) {
        Text(this.record.content)
          .fontSize(13)
          .fontColor('#8B7E74')
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
      }

      if (this.record.media.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.record.media.slice(0, 3), (m: MediaItem) => {
            if (m.mimeType.startsWith('image') || !m.mimeType.includes('video')) {
              Image(this.thumbSrc(m))
                .width(56)
                .height(56)
                .borderRadius(6)
                .objectFit(ImageFit.Cover)
            } else {
              Stack() {
                Column() {
                  Text('▶')
                    .fontSize(20)
                    .fontColor('#999999')
                }
                .width(56)
                .height(56)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#F0F0F0')
                .borderRadius(6)
              }
            }
          }, (m: MediaItem, idx: number) => `thumb-${idx}`)
        }
        .width('100%')
        .margin({ top: 8 })
      }

      Row() {
        Text(formatTime(this.record.createdAt))
          .fontSize(12)
          .fontColor('#999999')
        Blank()
        if (this.record.meritValue) {
          Text(`+${this.record.meritValue} ✨`)
            .fontSize(12)
            .fontColor('#D4A017')
            .fontWeight(FontWeight.Medium)
        }
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor(Theme.bg)
    .borderRadius(10)
    .onClick(() => {
      this.onCardClick();
    })
  }
}
