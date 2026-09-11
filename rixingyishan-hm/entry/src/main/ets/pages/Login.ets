import { router, promptAction } from '@kit.ArkUI';
import { AuthService } from '../services/AuthService';
import { Theme } from '../common/Theme';
import { errorMessage, RouteParams } from '../common/Utils';

/**
 * 登录页 — 手机号 + 短信验证码 + 协议勾选（对齐 H5 pages/login）
 */
@Entry
@Component
struct Login {
  @State phone: string = '';
  @State code: string = '';
  @State countdown: number = 0;
  @State isLogging: boolean = false;
  @State agreed: boolean = false;
  private timerId: number = -1;

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private isPhoneValid(): boolean {
    return /^1[3-9]\d{9}$/.test(this.phone);
  }

  private canLogin(): boolean {
    return this.isPhoneValid() && /^\d{6}$/.test(this.code) && this.agreed && !this.isLogging;
  }

  private async sendCode(): Promise<void> {
    if (!this.isPhoneValid() || this.countdown > 0) {
      return;
    }
    try {
      await AuthService.sendSmsCode(this.phone);
      promptAction.showToast({ message: '验证码已发送', duration: 2000 });
      this.countdown = 60;
      this.timerId = setInterval(() => {
        this.countdown -= 1;
        if (this.countdown <= 0 && this.timerId >= 0) {
          clearInterval(this.timerId);
          this.timerId = -1;
        }
      }, 1000);
    } catch (e) {
      promptAction.showToast({ message: errorMessage(e, '发送验证码失败'), duration: 2000 });
    }
  }

  private async doLogin(): Promise<void> {
    if (!this.agreed) {
      promptAction.showToast({ message: '请先阅读并同意用户协议和隐私政策', duration: 2000 });
      return;
    }
    if (!this.canLogin()) {
      return;
    }
    this.isLogging = true;
    try {
      await AuthService.verifySmsCode(this.phone, this.code);
      promptAction.showToast({ message: '登录成功', duration: 2000 });
      setTimeout(() => {
        router.back();
      }, 600);
    } catch (e) {
      promptAction.showToast({ message: errorMessage(e, '登录失败'), duration: 2000 });
    } finally {
      this.isLogging = false;
    }
  }

  private openAgreement(type: string): void {
    const p = new RouteParams();
    p.type = type;
    router.pushUrl({ url: 'pages/Agreement', params: p });
  }

  build() {
    Column() {
      // ---------- 顶部品牌 ----------
      Column() {
        Text('☀️')
          .fontSize(48)
          .width(96)
          .height(96)
          .textAlign(TextAlign.Center)
          .borderRadius(28)
          .linearGradient({
            angle: 135,
            colors: [['#FFB25C', 0], ['#E8733A', 1]]
          })
          .shadow({ radius: 16, color: 'rgba(232,115,58,0.35)', offsetY: 6 })
        Text('日行一善')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#5A3A22')
          .margin({ top: 18 })
          .letterSpacing(4)
        Text('记录每天的美好瞬间')
          .fontSize(16)
          .fontColor('#A8907A')
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 64, bottom: 40 })

      // ---------- 表单卡片 ----------
      Column() {
        Text('手机号')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5A3A22')
          .width('100%')
          .margin({ bottom: 10 })
        TextInput({ text: this.phone, placeholder: '请输入手机号' })
          .type(InputType.PhoneNumber)
          .maxLength(11)
          .fontSize(17)
          .fontColor(Theme.text)
          .placeholderColor('#C7B29C')
          .height(48)
          .width('100%')
          .backgroundColor('#FFF8F0')
          .borderRadius(12)
          .padding({ left: 14, right: 14 })
          .onChange((v: string) => {
            this.phone = v;
          })
          .margin({ bottom: 20 })

        Text('验证码')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5A3A22')
          .width('100%')
          .margin({ bottom: 10 })
        Row() {
          TextInput({ text: this.code, placeholder: '6位验证码' })
            .type(InputType.Number)
            .maxLength(6)
            .fontSize(17)
            .fontColor(Theme.text)
            .placeholderColor('#C7B29C')
            .height(48)
            .layoutWeight(1)
            .backgroundColor('#FFF8F0')
            .borderRadius(12)
            .padding({ left: 14, right: 14 })
            .onChange((v: string) => {
              this.code = v;
            })
          Button(this.countdown > 0 ? `${this.countdown}s` : '获取验证码')
            .height(48)
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.countdown > 0 || !this.isPhoneValid() ? '#EDE2D6' : Theme.accent)
            .borderRadius(12)
            .margin({ left: 12 })
            .enabled(this.countdown <= 0 && this.isPhoneValid())
            .onClick(() => {
              this.sendCode();
            })
        }
        .width('100%')

        Button(this.isLogging ? '登录中...' : '登录')
          .width('100%')
          .height(52)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(this.canLogin() ? Theme.accent : '#E5D8C8')
          .borderRadius(26)
          .margin({ top: 24 })
          .enabled(this.canLogin())
          .onClick(() => {
            this.doLogin();
          })

        // ---------- 协议勾选 ----------
        Row() {
          Row() {
            if (this.agreed) {
              Text('✓')
                .fontSize(12)
                .fontColor(Color.White)
            }
          }
          .width(18)
          .height(18)
          .borderRadius(9)
          .border({ width: 1, color: this.agreed ? Theme.accent : '#D8C6B2' })
          .backgroundColor(this.agreed ? Theme.accent : Color.White)
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
          .onClick(() => {
            this.agreed = !this.agreed;
          })

          Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
            Text('我已阅读并同意 ')
              .fontSize(13)
              .fontColor('#A8907A')
            Text('《用户协议》')
              .fontSize(13)
              .fontColor(Theme.accent)
              .onClick(() => {
                this.openAgreement('agreement');
              })
            Text(' 和 ')
              .fontSize(13)
              .fontColor('#A8907A')
            Text('《隐私政策》')
              .fontSize(13)
              .fontColor(Theme.accent)
              .onClick(() => {
                this.openAgreement('privacy');
              })
          }
          .layoutWeight(1)
          .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
        .margin({ top: 18 })
      }
      .padding({ left: 22, right: 22, top: 26, bottom: 26 })
      .backgroundColor(Color.White)
      .borderRadius(18)
      .shadow({ radius: 20, color: 'rgba(206,126,58,0.12)', offsetY: 4 })
      .margin({ left: 20, right: 20 })

      Text('未注册手机号将自动创建账号')
        .fontSize(13)
        .fontColor('#BFA98F')
        .margin({ top: 28 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#FFEDD9', 0], ['#FFF8F0', 0.42], ['#FFF8F0', 1]]
    })
  }
}
