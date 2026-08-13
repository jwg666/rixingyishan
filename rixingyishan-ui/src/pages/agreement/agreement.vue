<template>
  <view class="container">
    <view v-if="type === 'privacy'" class="doc">
      <text class="doc-title">隐私政策</text>
      <text class="doc-update">更新日期：2026年8月12日　生效日期：2026年8月12日</text>

      <view v-for="(sec, i) in privacySections" :key="i" class="section">
        <text class="section-title">{{ sec.title }}</text>
        <text v-for="(p, j) in sec.paragraphs" :key="j" class="section-p">{{ p }}</text>
      </view>
    </view>

    <view v-else class="doc">
      <text class="doc-title">用户协议</text>
      <text class="doc-update">更新日期：2026年8月12日　生效日期：2026年8月12日</text>

      <view v-for="(sec, i) in agreementSections" :key="i" class="section">
        <text class="section-title">{{ sec.title }}</text>
        <text v-for="(p, j) in sec.paragraphs" :key="j" class="section-p">{{ p }}</text>
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { onLoad } from "@dcloudio/uni-app";

const type = ref<"agreement" | "privacy">("agreement");

onLoad((options) => {
  if (options?.type === "privacy") {
    type.value = "privacy";
    uni.setNavigationBarTitle({ title: "隐私政策" });
  } else {
    uni.setNavigationBarTitle({ title: "用户协议" });
  }
});

interface Section {
  title: string;
  paragraphs: string[];
}

const agreementSections: Section[] = [
  {
    title: "一、服务说明",
    paragraphs: [
      "「日行一善」是一款帮助用户记录每日善行与美好瞬间的应用，提供善行记录、图片与视频上传、功德积分累计、功德排行榜等功能。",
      "您注册并登录本应用即表示您已阅读、理解并同意接受本协议的全部内容。如您不同意本协议，请勿使用本应用。",
    ],
  },
  {
    title: "二、账号注册与管理",
    paragraphs: [
      "本应用通过手机号 + 短信验证码的方式注册登录，未注册的手机号在首次验证后将自动创建账号。",
      "您应妥善保管自己的账号，因您个人原因导致的账号泄露或损失由您自行承担。",
      "您可以随时在设置页退出登录；退出后本地记录仍保留在您的设备上，重新登录后可继续同步。",
    ],
  },
  {
    title: "三、用户行为规范",
    paragraphs: [
      "您承诺上传的善行记录内容真实、合法，不含有违法、虚假、侵犯他人合法权益的信息。",
      "您上传的图片、视频等内容应为您本人拍摄或已获得合法授权。",
      "禁止通过技术手段刷取功德积分、操纵排行榜排名。一经发现，我们有权清零相关积分、限制账号功能。",
    ],
  },
  {
    title: "四、内容与知识产权",
    paragraphs: [
      "您上传的内容（文字、图片、视频）的著作权归您或原权利人所有。您授予本应用为提供服务所必需的非独占许可（如存储、展示于您的个人记录与排行榜统计）。",
      "本应用的界面设计、代码、图标、文案等知识产权归开发者所有，未经许可不得复制、修改或用于商业用途。",
    ],
  },
  {
    title: "五、功德积分与排行榜",
    paragraphs: [
      "功德积分是本应用对您坚持记录善行的正向激励，仅为虚拟积分，不具备任何货币价值，不可兑换、转让或提现。",
      "排行榜数据基于用户提交的记录统计生成，您可在设置中关闭排行榜可见性。",
    ],
  },
  {
    title: "六、免责声明",
    paragraphs: [
      "因不可抗力、网络故障、设备故障等原因导致的数据丢失或同步延迟，我们将尽力协助恢复但不承担赔偿责任，建议您定期使用导出功能备份数据。",
      "本应用提供的功德积分与排行仅供娱乐与自我激励，不构成任何形式的宗教或功德认定。",
    ],
  },
  {
    title: "七、协议的变更与终止",
    paragraphs: [
      "我们可能根据功能更新或法律法规要求修订本协议，修订后的协议将在应用内公布，重大变更将以弹窗或站内通知方式提醒。",
      "如您继续使用本应用，即视为接受修订后的协议；如不同意，请停止使用并删除本地数据。",
    ],
  },
];

const privacySections: Section[] = [
  {
    title: "一、我们收集的信息",
    paragraphs: [
      "1. 手机号：用于注册、登录与账号安全验证，是创建账号所必需的信息。",
      "2. 善行记录内容：包括您填写的文字、拍摄或从相册选择的图片与视频，用于记录展示与云端同步。",
      "3. 设备与网络信息：仅在上传时获取网络类型（用于判断 Wi-Fi 上传开关），不收集设备标识符。",
      "4. 我们不收集您的精确地理位置、通讯录、通话记录等与功能无关的敏感信息。",
    ],
  },
  {
    title: "二、信息的使用方式",
    paragraphs: [
      "手机号仅用于账号登录与验证，不会用于营销推送。",
      "您上传的内容仅用于：在您本人的记录中展示、云端备份同步、功德积分与排行榜的匿名统计。",
      "我们不会将您的个人信息或内容出售、出租给任何第三方。",
    ],
  },
  {
    title: "三、信息的存储与保护",
    paragraphs: [
      "您的记录默认存储在设备本地（浏览器存储），登录后才会同步到我们的服务器。",
      "服务器数据传输采用 HTTPS 加密，访问凭证（Token）设置有效期并支持随时退出失效。",
      "我们仅保留为您提供服务所必需的数据；您删除记录时，服务器端数据将同步删除。",
    ],
  },
  {
    title: "四、您的权利",
    paragraphs: [
      "1. 查询与导出：您可以在设置页将所有本地记录导出为 JSON 数据。",
      "2. 删除：您可以删除单条记录，或在设置页删除所有本地记录；已同步的服务端数据将一并删除。",
      "3. 退出登录：您可以随时退出，退出后我们将停止与您账号相关的云端同步。",
      "4. 注销：如需注销账号并删除全部服务端数据，请联系开发者处理。",
    ],
  },
  {
    title: "五、未成年人保护",
    paragraphs: [
      "本应用适合所有年龄段用户使用。未满 14 周岁的用户请在监护人指导下使用，监护人如发现未成年人未经同意提供了个人信息，可联系我们删除。",
    ],
  },
  {
    title: "六、本政策的更新",
    paragraphs: [
      "如本政策发生变更，我们将在应用内更新并以显著方式提示。您继续使用本应用即表示同意更新后的政策。",
    ],
  },
  {
    title: "七、联系我们",
    paragraphs: [
      "如您对本政策或个人信息处理有任何疑问，可通过应用内反馈渠道联系开发者，我们将在 15 个工作日内答复。",
    ],
  },
];
</script>

<style scoped>
.container {
  min-height: 100vh;
  background-color: #FFF8F0;
  padding: 24rpx;
}

.doc {
  background-color: #ffffff;
  border-radius: 16rpx;
  padding: 32rpx 28rpx;
}

.doc-title {
  font-size: 40rpx;
  font-weight: bold;
  color: #333333;
  display: block;
  text-align: center;
  margin-bottom: 12rpx;
}

.doc-update {
  font-size: 22rpx;
  color: #999999;
  display: block;
  text-align: center;
  margin-bottom: 32rpx;
}

.section {
  margin-bottom: 28rpx;
}

.section-title {
  font-size: 30rpx;
  font-weight: bold;
  color: #E8733A;
  display: block;
  margin-bottom: 12rpx;
}

.section-p {
  font-size: 26rpx;
  color: #555555;
  line-height: 1.8;
  display: block;
  margin-bottom: 8rpx;
}
</style>
