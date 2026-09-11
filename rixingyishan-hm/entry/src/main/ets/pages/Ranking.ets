import { router, promptAction } from '@kit.ArkUI';
import { MeritService, RankingType, RankingResponse } from '../services/MeritService';
import { AuthService } from '../services/AuthService';
import { RankingItem } from '../model/Types';
import { Theme } from '../common/Theme';
import { getAvatarColor, getNicknameInitial } from '../common/Utils';

/**
 * 排行榜页 — 总功德榜 / 日行一善榜，下拉刷新，我的名次固定底部
 */
@Entry
@Component
struct Ranking {
  @State isLoggedIn: boolean = false;
  @State activeTab: RankingType = 'total';
  @State rankingList: RankingItem[] = [];
  @State myRank: RankingItem | null = null;
  @State isRefreshing: boolean = false;
  @State isLoading: boolean = false;

  aboutToAppear(): void {
    this.refreshAuthAndLoad();
  }

  onPageShow(): void {
    this.refreshAuthAndLoad();
  }

  private refreshAuthAndLoad(): void {
    this.isLoggedIn = AuthService.isLoggedIn();
    this.loadRanking();
  }

  private async loadRanking(): Promise<void> {
    if (!this.isLoggedIn) {
      return;
    }
    this.isLoading = true;
    try {
      const res: RankingResponse = await MeritService.getRanking(this.activeTab);
      this.rankingList = res.items || [];
      this.myRank = res.myRank || null;
    } catch (e) {
      promptAction.showToast({ message: '排行加载失败', duration: 2000 });
    } finally {
      this.isLoading = false;
      this.isRefreshing = false;
    }
  }

  private switchTab(tab: RankingType): void {
    if (this.activeTab === tab) {
      return;
    }
    this.activeTab = tab;
    this.rankingList = [];
    this.loadRanking();
  }

  private myRankInList(): boolean {
    if (this.myRank === null) {
      return true;
    }
    return this.rankingList.some((i) => i.isMe === true);
  }

  @Builder
  rankRow(item: RankingItem, showMeTag: boolean) {
    Row({ space: 10 }) {
      Text(item.rankPosition === 1 ? '🥇' : item.rankPosition === 2 ? '🥈' : item.rankPosition === 3 ? '🥉' : `${item.rankPosition}`)
        .fontSize(item.rankPosition <= 3 ? 22 : 15)
        .fontColor('#8B7E74')
        .width(36)
        .textAlign(TextAlign.Center)
      Text(getNicknameInitial(item.nickname))
        .fontSize(16)
        .fontColor('#5A3A22')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(getAvatarColor(item.avatarSeed))
        .borderRadius(20)
      Text(item.nickname || '善心人士')
        .fontSize(15)
        .fontColor('#333333')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (showMeTag && item.isMe) {
        Text('我')
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor(Theme.accent)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(6)
      }
      Text(`${item.meritValue} ✨`)
        .fontSize(14)
        .fontColor('#D4A017')
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor(item.isMe ? '#FFF0E5' : Color.White)
    .borderRadius(10)
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
        Text('功德排行榜')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.text)
          .margin({ left: 12 })
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      if (!this.isLoggedIn) {
        // 未登录提示
        Row({ space: 8 }) {
          Text('✨').fontSize(18)
          Text('登录后查看排行')
            .fontSize(15)
            .fontColor('#8B7E74')
          Text('→')
            .fontSize(15)
            .fontColor(Theme.accent)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding(26)
        .margin({ left: 12, right: 12, top: 12 })
        .backgroundColor(Color.White)
        .borderRadius(12)
        .onClick(() => {
          router.pushUrl({ url: 'pages/Login' });
        })
        .layoutWeight(1)
      } else {
        // Tab 切换
        Row() {
          Text('总功德榜')
            .fontSize(15)
            .fontColor(this.activeTab === 'total' ? Theme.accent : '#999999')
            .fontWeight(this.activeTab === 'total' ? FontWeight.Bold : FontWeight.Normal)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(this.activeTab === 'total' ? '#FFF0E5' : Color.Transparent)
            .onClick(() => {
              this.switchTab('total');
            })
          Text('日行一善榜')
            .fontSize(15)
            .fontColor(this.activeTab === 'daily' ? Theme.accent : '#999999')
            .fontWeight(this.activeTab === 'daily' ? FontWeight.Bold : FontWeight.Normal)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .padding({ top: 12, bottom: 12 })
            .backgroundColor(this.activeTab === 'daily' ? '#FFF0E5' : Color.Transparent)
            .onClick(() => {
              this.switchTab('daily');
            })
        }
        .width('100%')
        .margin({ left: 12, right: 12, top: 12 })
        .backgroundColor(Color.White)
        .borderRadius(12)

        // 排行列表
        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            if (this.rankingList.length === 0 && !this.isLoading) {
              ListItem() {
                Text('暂无排行数据')
                  .fontSize(15)
                  .fontColor('#999999')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding(40)
              }
            }
            ForEach(this.rankingList, (item: RankingItem) => {
              ListItem() {
                this.rankRow(item, true)
              }
              .margin({ left: 12, right: 12, top: 6 })
            }, (item: RankingItem) => `${this.activeTab}-${item.rankPosition}`)
          }
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
        }
        .layoutWeight(1)
        .margin({ top: 10 })
        .onRefreshing(() => {
          this.loadRanking();
        })

        // 我的排名固定底部
        if (this.myRank !== null && !this.myRankInList()) {
          Column() {
            this.rankRow(this.myRank, true)
          }
          .margin(12)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
