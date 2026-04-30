# 日行一善（Good Deeds）

跨端记录 App（文字 / 图片 / 视频），支持 **App(iOS/Android) + H5 + 微信小程序**。

## 仓库结构
- `rixingyishan-ui/`：前端（uni-app + Vue3 + TypeScript）
- `rixingyishan-service/`：后端服务（MVP：登录/记录/上传凭证/日历打点）
- `docs/`：产品、架构与 PRD 文档（不随工程拆分移动）

## 快速开始（前端）

```bash
cd rixingyishan-ui
npm install
```

### H5
```bash
npm run dev:h5
```

### 微信小程序
```bash
npm run dev:mp-weixin
```

## 后端说明
后端子工程目前为占位与职责说明，见 `rixingyishan-service/README.md`。

## 文档入口
- 文档索引：`docs/README.md`
- PRD 总览索引：`docs/prd/2026-04-30-good-deeds-prd.md`
- PRD（前端）：`docs/prd/2026-04-30-good-deeds-prd-ui.md`
- PRD（后端）：`docs/prd/2026-04-30-good-deeds-prd-service.md`
- Gap（前后端拆分）：`docs/prd/2026-04-30-implementation-gap.md`

