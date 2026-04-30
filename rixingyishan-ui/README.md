# rixingyishan-ui

前端跨端工程（`uni-app` + `Vue3` + `TypeScript`），支持：
- iOS / Android（App-Plus）
- H5
- 微信小程序（优先）

## 开发环境
- Node.js（建议 18+）
- npm
- HBuilderX（用于 App / 小程序真机调试与发行，按团队流程选择）

## 启动

在本目录执行：

```bash
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

## 目录结构（核心）
- `src/pages/`：页面（首页/新建/详情/设置）
- `src/services/`：业务服务（本地仓储、上传队列、媒体采集/校验）
- `src/platform-adapter/`：多端能力适配层（相机/相册/录像）
- `src/types/`：领域类型（记录、媒体、上传任务）

## 文档
产品与架构文档在仓库根目录 `docs/`：
- PRD：`docs/prd/`
- 架构：`docs/architecture/`

