import { router, promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { RecordRepository } from '../services/RecordRepository';
import { AuthService } from '../services/AuthService';
import { MeritService } from '../services/MeritService';
import { KvStore } from '../services/KvStore';
import { Constants } from '../common/Constants';
import { UserProfile } from '../model/Types';
import { Theme } from '../common/Theme';
import { getAvatarColor, getNicknameInitial, maskPhone, RouteParams } from '../common/Utils';

/**
 * 设置页 — 资料 / 仅 Wi-Fi / 排行可见 / 退出 / 清缓存 / 清数据 / 导出 / 协议入口
 */
@Entry
@Component
struct Settings {
  @State isLoggedIn: boolean = false;
  @State wifiOnly: boolean = false;
  @State videoDurationLimit: number = Constants.DEFAULT_VIDEO_DURATION;
  @State showInRanking: boolean = true;
  @State userProfile: UserProfile | null = null;
  @State showNicknameModal: boolean = false;
  @State newNickname: string = '';

  aboutToAppear(): void {
    this.wifiOnly = KvStore.getString(Constants.KEY_WIFI_ONLY) === 'true';
    const savedDuration = KvStore.getString(Constants.KEY_VIDEO_DURATION);
    if (savedDuration) {
      const parsed = parseInt(savedDuration);
      if (parsed > 0 && parsed <= 300) {
        this.videoDurationLimit = parsed;
      }
    }
    this.refreshAuthState();
  }

  onPageShow(): void {
    this.refreshAuthState();
  }

  private async refreshAuthState(): Promise<void> {
    this.isLoggedIn = AuthService.isLoggedIn();
    if (this.isLoggedIn) {
      const profile = await MeritService.getProfile();
      if (profile !== null) {
        this.userProfile = profile;
        this.showInRanking = profile.showInRanking;
      }
    }
  }

  private onWifiOnlyChange(checked: boolean): void {
    this.wifiOnly = checked;
    KvStore.setString(Constants.KEY_WIFI_ONLY, checked ? 'true' : 'false');
  }

  private async onShowInRankingChange(checked: boolean): Promise<void> {
    const previous = this.showInRanking;
    this.showInRanking = checked;
    try {
      await MeritService.updateShowInRanking(checked);
    } catch (e) {
      promptAction.showToast({ message: '设置失败', duration: 2000 });
      this.showInRanking = previous;
    }
  }

  private openNicknameModal(): void {
    this.newNickname = this.userProfile !== null && this.userProfile.nickname ? this.userProfile.nickname : '';
    this.showNicknameModal = true;
  }

  private async saveNickname(): Promise<void> {
    const nickname = this.newNickname.trim();
    if (!nickname) {
      promptAction.showToast({ message: '昵称不能为空', duration: 2000 });
      return;
    }
    try {
      await MeritService.updateNickname(nickname);
      if (this.userProfile !== null) {
        const updated: UserProfile = {
          id: this.userProfile.id,
          phone: this.userProfile.phone,
          nickname: nickname,
          avatarSeed: this.userProfile.avatarSeed,
          totalMerit: this.userProfile.totalMerit,
          showInRanking: this.userProfile.showInRanking
        };
        this.userProfile = updated;
      }
      promptAction.showToast({ message: '昵称已更新', duration: 2000 });
      this.showNicknameModal = false;
    } catch (e) {
      promptAction.showToast({ message: '更新失败', duration: 2000 });
    }
  }

  private confirmLogout(): void {
    AlertDialog.show({
      title: '确认退出',
      message: '退出后需要重新登录才能同步数据，确定退出吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '退出',
        action: () => {
          this.doLogout();
        }
      }
    });
  }

  private async doLogout(): Promise<void> {
    await AuthService.logout();
    this.userProfile = null;
    this.refreshAuthState();
    promptAction.showToast({ message: '已退出登录', duration: 2000 });
  }

  private confirmClearCache(): void {
    AlertDialog.show({
      title: '清理缓存',
      message: '将清理上传任务队列和临时媒体缓存，不会删除您的记录。确定继续吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清理',
        action: () => {
          RecordRepository.clearUploadTasks();
          RecordRepository.clearTempMedia();
          RecordRepository.clearCompletedUploadTasks();
          promptAction.showToast({ message: '缓存已清理', duration: 2000 });
        }
      }
    });
  }

  private confirmDeleteAllRecords(): void {
    AlertDialog.show({
      title: '⚠️ 危险操作',
      message: '这将永久删除所有本地记录和上传任务，此操作不可恢复！确定要继续吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '继续',
        fontColor: '#FF4D4F',
        action: () => {
          this.confirmDeleteAllRecordsAgain();
        }
      }
    });
  }

  private confirmDeleteAllRecordsAgain(): void {
    AlertDialog.show({
      title: '再次确认',
      message: '真的要删除所有记录吗？此操作无法撤销！',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '全部删除',
        fontColor: '#FF4D4F',
        action: () => {
          RecordRepository.clearAllRecords();
          promptAction.showToast({ message: '所有记录已删除', duration: 2000 });
        }
      }
    });
  }

  private openAgreement(type: string): void {
    const p = new RouteParams();
    p.type = type;
    router.pushUrl({ url: 'pages/Agreement', params: p });
  }

  private async exportData(): Promise<void> {
    try {
      const json = JSON.stringify(RecordRepository.getAll());
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, json);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '已复制到剪贴板', duration: 2000 });
    } catch (e) {
      promptAction.showToast({ message: '导出失败', duration: 2000 });
    }
  }

  @Builder
  settingItem(label: string, action: string, danger: boolean, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(danger ? '#FF4D4F' : '#333333')
      Blank()
      Text(action)
        .fontSize(13)
        .fontColor(danger ? '#FF4D4F' : '#999999')
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .onClick(() => {
      onTap();
    })
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column() {
            // ---------- 用户资料区 ----------
            if (this.isLoggedIn) {
              Row({ space: 12 }) {
                Text(getNicknameInitial(this.userProfile !== null ? this.userProfile.nickname : null))
                  .fontSize(18)
                  .fontColor('#5A3A22')
                  .width(52)
                  .height(52)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(getAvatarColor(this.userProfile !== null ? this.userProfile.avatarSeed : ''))
                  .borderRadius(26)
                  .onClick(() => {
                    this.openNicknameModal();
                  })
                Column({ space: 4 }) {
                  Text(this.userProfile !== null && this.userProfile.nickname ? this.userProfile.nickname : '点击设置昵称')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')
                    .onClick(() => {
                      this.openNicknameModal();
                    })
                  Text(maskPhone(AuthService.getPhone()))
                    .fontSize(13)
                    .fontColor('#999999')
                  Text(`功德 ${this.userProfile !== null ? this.userProfile.totalMerit : 0} ✨`)
                    .fontSize(13)
                    .fontColor('#D4A017')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
            } else {
              Column() {
                this.settingItem('登录', '点击登录', false, () => {
                  router.pushUrl({ url: 'pages/Login' });
                })
              }
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // ---------- 偏好 ----------
            Column() {
              Row() {
                Text('仅 Wi-Fi 上传').fontSize(15).fontColor('#333333')
                Blank()
                Toggle({ type: ToggleType.Switch, isOn: this.wifiOnly })
                  .selectedColor(Theme.accent)
                  .onChange((checked: boolean) => {
                    this.onWifiOnlyChange(checked);
                  })
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 4 })
              Text('开启后仅在连接 Wi-Fi 时自动上传媒体')
                .fontSize(11)
                .fontColor('#BBBBBB')
                .width('100%')
                .padding({ left: 14, right: 14, bottom: 10 })

              Divider().color(Theme.divider).strokeWidth(0.5)

              Row() {
                Text('视频默认时长限制').fontSize(15).fontColor('#333333')
                Blank()
                Text(`${this.videoDurationLimit}秒`)
                  .fontSize(13)
                  .fontColor('#999999')
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })

              if (this.isLoggedIn) {
                Divider().color(Theme.divider).strokeWidth(0.5)
                Row() {
                  Text('排行榜可见').fontSize(15).fontColor('#333333')
                  Blank()
                  Toggle({ type: ToggleType.Switch, isOn: this.showInRanking })
                    .selectedColor(Theme.accent)
                    .onChange((checked: boolean) => {
                      this.onShowInRankingChange(checked);
                    })
                }
                .width('100%')
                .padding({ left: 14, right: 14, top: 4, bottom: 12 })
              }
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 12 })

            // ---------- 已登录操作 ----------
            if (this.isLoggedIn) {
              Column() {
                this.settingItem('修改昵称', '→', false, () => {
                  this.openNicknameModal();
                })
                Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 14, right: 14 })
                this.settingItem('退出登录', '清除登录状态', true, () => {
                  this.confirmLogout();
                })
              }
              .width('100%')
              .backgroundColor(Color.White)
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // ---------- 缓存 / 数据 ----------
            Column() {
              this.settingItem('清理缓存', '清理上传队列和临时缓存', false, () => {
                this.confirmClearCache();
              })
              Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.settingItem('删除所有本地记录', '不可恢复，请谨慎操作', true, () => {
                this.confirmDeleteAllRecords();
              })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 12 })

            Column() {
              this.settingItem('导出数据', '导出所有记录为 JSON', false, () => {
                this.exportData();
              })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 12 })

            // ---------- 协议 ----------
            Column() {
              this.settingItem('用户协议', '→', false, () => {
                this.openAgreement('agreement');
              })
              Divider().color(Theme.divider).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.settingItem('隐私政策', '→', false, () => {
                this.openAgreement('privacy');
              })
            }
            .width('100%')
            .backgroundColor(Color.White)
            .borderRadius(12)
            .margin({ bottom: 12 })

            // ---------- 关于 ----------
            Column({ space: 4 }) {
              Text('关于')
                .fontSize(13)
                .fontColor('#8B7E74')
              Text('版本：v0.2.0')
                .fontSize(12)
                .fontColor('#999999')
              Text('日行一善 - 记录每天的美好瞬间')
                .fontSize(11)
                .fontColor('#BBBBBB')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .padding({ top: 10, bottom: 16 })
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
              .fontColor('#999999')
          }
          .layoutWeight(1)
          .onClick(() => {
            try {
              router.back({ url: 'pages/Index' });
            } catch (e) {
              router.back();
            }
          })
          Column({ space: 2 }) {
            Text('⚙️').fontSize(20)
            Text('设置')
              .fontSize(11)
              .fontColor(Theme.accent)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .height(56)
        .backgroundColor(Color.White)
        .border({ width: { top: 0.5 }, color: Theme.divider })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      // ---------- 修改昵称弹窗 ----------
      if (this.showNicknameModal) {
        Column() {
          Column({ space: 14 }) {
            Text('修改昵称')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
            TextInput({ text: this.newNickname, placeholder: '输入新昵称' })
              .fontSize(15)
              .maxLength(20)
              .placeholderColor('#C7B29C')
              .height(44)
              .width('100%')
              .backgroundColor('#FFF8F0')
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((v: string) => {
                this.newNickname = v;
              })
            Row({ space: 12 }) {
              Button('取消')
                .layoutWeight(1)
                .height(40)
                .fontSize(15)
                .fontColor('#666666')
                .backgroundColor('#F0F0F0')
                .borderRadius(10)
                .onClick(() => {
                  this.showNicknameModal = false;
                })
              Button('保存')
                .layoutWeight(1)
                .height(40)
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(Theme.accent)
                .borderRadius(10)
                .onClick(() => {
                  this.saveNickname();
                })
            }
            .width('100%')
          }
          .padding(20)
          .backgroundColor(Color.White)
          .borderRadius(16)
          .width('82%')
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.45)')
        .onClick(() => {
          this.showNicknameModal = false;
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
