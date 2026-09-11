import { router, promptAction } from '@kit.ArkUI';
import { CalendarMonth } from '../components/CalendarMonth';
import { RecordCard } from '../components/RecordCard';
import { RecordRepository } from '../services/RecordRepository';
import { AuthService } from '../services/AuthService';
import { SyncMergeService, SyncHomeResult } from '../services/SyncMergeService';
import { GoodDeedRecord } from '../model/Types';
import { Theme } from '../common/Theme';
import { maskPhone } from '../common/Utils';

/**
 * 首页 — 功德卡 + 月历打点 + 当日列表 + 登录后双向同步（onShow）
 */
@Entry
@Component
struct Index {
  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State selectedDayKey: string = '';
  @State dayRecords: GoodDeedRecord[] = [];
  @State localDayKeys: string[] = [];
  @State remoteDayKeys: string[] = [];
  @State totalMerit: number = 0;
  @State dailyMerit: number = 0;
  @State isLoggedIn: boolean = false;

  aboutToAppear(): void {
    this.selectedDayKey = this.currentDayKey();
    this.refreshLocal();
  }

  onPageShow(): void {
    this.refreshLocal();
    this.syncRemote();
  }

  private currentDayKey(): string {
    const now = new Date();
    const m = (now.getMonth() + 1).toString().padStart(2, '0');
    const d = now.getDate().toString().padStart(2, '0');
    return `${now.getFullYear()}-${m}-${d}`;
  }

  private monthKey(): string {
    return `${this.year}-${this.month.toString().padStart(2, '0')}`;
  }

  private refreshLocal(): void {
    this.dayRecords = RecordRepository.getByDayKey(this.selectedDayKey);
    this.localDayKeys = RecordRepository.getDayKeysWithRecords(this.monthKey());
    const sum = RecordRepository.sumMeritLocal();
    this.totalMerit = sum.total;
    this.dailyMerit = sum.daily;
    this.isLoggedIn = AuthService.isLoggedIn();
  }

  private dottedKeys(): string[] {
    const set = new Set<string>(this.localDayKeys);
    for (const k of this.remoteDayKeys) {
      set.add(k);
    }
    return Array.from(set);
  }

  /** 登录后拉远端合并（设计规格 §4.2 双向同步） */
  private async syncRemote(): Promise<void> {
    if (!AuthService.isLoggedIn()) {
      return;
    }
    try {
      const result: SyncHomeResult = await SyncMergeService.syncHome(this.selectedDayKey, this.monthKey());
      this.dayRecords = result.dayRecords;
      const prefix = this.monthKey() + '-';
      const remoteOfThisMonth: string[] = [];
      for (const k of result.remoteDays) {
        if (k.startsWith(prefix)) {
          remoteOfThisMonth.push(k);
        }
      }
      this.remoteDayKeys = remoteOfThisMonth;
      this.localDayKeys = RecordRepository.getDayKeysWithRecords(this.monthKey());
      const sum = RecordRepository.sumMeritLocal();
      this.totalMerit = sum.total;
      this.dailyMerit = sum.daily;
      this.isLoggedIn = AuthService.isLoggedIn();
    } catch (e) {
      promptAction.showToast({ message: '网络不稳定，展示本地数据', duration: 2000 });
    }
  }

  private goToCreate(): void {
    router.pushUrl({
      url: 'pages/CreateRecord',
      params: { dayKey: this.selectedDayKey } as Record<string, string>
    });
  }

  private goToDetail(id: string): void {
    router.pushUrl({ url: 'pages/RecordDetail', params: { id: id } as Record<string, string> });
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // ---------- 顶栏 ----------
          Row() {
            Text('日行一善')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#5A3A22')
            Blank()
            if (this.isLoggedIn) {
              Text(maskPhone(AuthService.getPhone()))
                .fontSize(13)
                .fontColor(Theme.textSecondary)
            } else {
              Text('去登录')
                .fontSize(13)
                .fontColor(Color.White)
                .backgroundColor(Theme.accent)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/Login' });
                })
            }
          }
          .width('100%')
          .margin({ bottom: 12 })

          // ---------- 功德卡 ----------
          Column() {
            Row() {
              Row({ space: 6 }) {
                Text('✨').fontSize(24)
                Text(`${this.totalMerit}`)
                  .fontSize(34)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#D4A017')
                Text('功德')
                  .fontSize(14)
                  .fontColor('#8B7E74')
              }
              .alignItems(VerticalAlign.Bottom)
              Blank()
              Text(`今日 +${this.dailyMerit}`)
                .fontSize(13)
                .fontColor(Theme.accent)
                .fontWeight(FontWeight.Medium)
                .backgroundColor('rgba(232,115,58,0.15)')
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
            }
            .width('100%')

            if (!this.isLoggedIn) {
              Text('登录后可云同步功德 →')
                .fontSize(14)
                .fontColor('#8B7E74')
                .margin({ top: 10 })
                .onClick(() => {
                  router.pushUrl({ url: 'pages/Login' });
                })
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(18)
          .linearGradient({
            angle: 135,
            colors: [['#FFF0E5', 0], ['#FFE4CC', 1]]
          })
          .borderRadius(12)
          .shadow({ radius: 8, color: 'rgba(232,115,58,0.15)', offsetY: 3 })
          .margin({ bottom: 12 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/Ranking' });
          })

          // ---------- 月历 ----------
          CalendarMonth({
            year: this.year,
            month: this.month,
            selectedDayKey: this.selectedDayKey,
            dottedDayKeys: this.dottedKeys(),
            onSelect: (dayKey: string) => {
              this.selectedDayKey = dayKey;
              this.dayRecords = RecordRepository.getByDayKey(dayKey);
            },
            onMonthChange: (y: number, m: number) => {
              this.year = y;
              this.month = m;
              this.remoteDayKeys = [];
              this.refreshLocal();
            }
          })
          .margin({ bottom: 12 })

          // ---------- 当日记录 ----------
          Column() {
            Row() {
              Text(this.selectedDayKey)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333333')
              Blank()
              Text('+')
                .fontSize(22)
                .fontColor(Color.White)
                .width(34)
                .height(34)
                .textAlign(TextAlign.Center)
                .backgroundColor(Theme.accent)
                .borderRadius(17)
                .onClick(() => {
                  this.goToCreate();
                })
            }
            .width('100%')
            .margin({ bottom: 14 })

            if (this.dayRecords.length === 0) {
              Column() {
                Text('暂无记录')
                  .fontSize(16)
                  .fontColor('#999999')
                  .margin({ bottom: 8 })
                Text('点击 + 按钮创建记录')
                  .fontSize(12)
                  .fontColor('#CCCCCC')
              }
              .width('100%')
              .padding({ top: 40, bottom: 40 })
            } else {
              Column({ space: 10 }) {
                ForEach(this.dayRecords, (r: GoodDeedRecord) => {
                  RecordCard({
                    record: r,
                    onCardClick: () => {
                      this.goToDetail(r.id);
                    }
                  })
                }, (r: GoodDeedRecord) => `${r.id}-${r.status}-${r.updatedAt}`)
              }
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor(Color.White)
          .borderRadius(12)
          .margin({ bottom: 12 })
        }
        .width('100%')
        .padding(12)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // ---------- 底部 Tab ----------
      Row() {
        Column({ space: 2 }) {
          Text('🏠').fontSize(20)
          Text('首页')
            .fontSize(11)
            .fontColor(Theme.accent)
            .fontWeight(FontWeight.Medium)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text('⚙️').fontSize(20)
          Text('设置')
            .fontSize(11)
            .fontColor('#999999')
        }
        .layoutWeight(1)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Settings' });
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)
      .border({ width: { top: 0.5 }, color: Theme.divider })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
