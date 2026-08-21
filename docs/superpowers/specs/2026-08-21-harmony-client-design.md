# 鸿蒙客户端（rixingyishan-hm）设计规格

**日期**：2026-08-21  
**状态**：待实现  
**对照基线**：`rixingyishan-ui`（H5 / uni-app）  
**后端 API**：`https://rxys.qdyhjz.cn/rxys/api`

---

## 1. 目标与约束

### 1.1 目标

在空模板工程 `rixingyishan-hm` 上，按 H5 功能做 **全量行为对齐** 的原生鸿蒙客户端（ArkTS / Stage 模型），覆盖：

- 登录 / 鉴权
- 首页日历 + 列表 + 功德卡
- 新建 / 详情
- 媒体采集 + 上传队列 + 云同步
- 功德排行榜
- 设置 + 用户协议 / 隐私政策

### 1.2 已确认决策

| 项 | 决策 |
|----|------|
| 实现路径 | **镜像移植**：按 H5 分层在 ArkTS 中重建（不做 WebView 壳、本期不做跨端共享内核） |
| UI 风格 | **对齐 H5 暖色**：`#FFF8F0` / `#E8733A` |
| API Base | `https://rxys.qdyhjz.cn/rxys/api` |
| 包名 | `cn.qdyhjz.rxys` |
| 首页数据（相对 H5 增强） | 登录后 **拉远端并与本地合并**；本地领先则 **自动回推远端** |
| 冲突策略 | **LWW**（`serverUpdatedAt` / `syncVersion` / `updatedAt` 较新胜出） |
| 仅本地记录 | **自动入队上传**（不弹窗确认） |
| 未登录 | 允许本地记账；不拉远端、不推送 |

### 1.3 非目标（本期 Out）

- 社区 / 分享 / 点赞
- 记录编辑
- 完整内容审核闭环
- 强后台上传承诺
- 与 H5 共享同一份运行时逻辑

---

## 2. 架构

### 2.1 目录结构（`entry/src/main/ets/`）

```
ets/
  common/          # 常量、主题色、API Base URL
  model/           # GoodDeedRecord / MediaItem / UploadTask / Merit*
  services/        # HttpClient, Auth, RecordRepo, UploadQueue, Merit, Media*
  pages/           # Index, Login, CreateRecord, RecordDetail, Ranking, Settings, Agreement
  components/      # 日历格、记录卡片、功德标签胶囊等
  entryability/    # 启动 / 回前台时 recover 上传队列
```

### 2.2 关键约定

- **Local-first 底座**：记录持久化使用 preferences（对齐 H5 的 `uni.setStorageSync` keys）
- **HTTP**：`@kit.NetworkKit` 封装；`Authorization: Bearer <accessToken>`；401 → refresh → 重试
- **导航**：`router` 多页面；底部 Tab = 首页 + 设置
- **权限**：相机 / 麦克风 / 相册 / 网络在 `module.json5` 声明

### 2.3 Preferences Keys（与 H5 对齐）

| Key | 用途 |
|-----|------|
| `good_deeds_records` | 本地记录 |
| `good_deeds_upload_tasks` | 上传队列 |
| `good_deeds_temp_media` | 临时媒体 |
| `accessToken` / `refreshToken` / `userPhone` / `userId` | 会话 |
| `settings_wifi_only` | 仅 Wi-Fi 上传 |
| `settings_video_duration` | 视频时长上限（默认 30s） |

---

## 3. 页面与功能映射

| 鸿蒙页面 | 对齐 H5 | 职责 |
|---------|---------|------|
| `pages/Index` | `pages/index` | 功德卡片、月历打点、当日列表、进新建/详情/排行/登录 |
| `pages/Login` | `pages/login` | 手机号+验证码、协议勾选 |
| `pages/CreateRecord` | `pages/create-record` | 内容、功德标签/智能匹配、拍照/相册、本地保存+入队 |
| `pages/RecordDetail` | `pages/record-detail` | 详情、媒体预览、失败重试、删除 |
| `pages/Ranking` | `pages/ranking` | 总榜/日榜、我的名次（需登录） |
| `pages/Settings` | `pages/settings` | 昵称、仅 Wi-Fi、排行可见、退出、清缓存、清数据、导出、协议入口 |
| `pages/Agreement` | `pages/agreement` | 用户协议 / 隐私政策 |

**导航**

- Tab：`Index` ↔ `Settings`
- 二级：`Login` / `CreateRecord` / `RecordDetail` / `Ranking` / `Agreement`
- 启动不强制登录

**服务层对齐**

| 鸿蒙 | H5 |
|------|-----|
| `HttpClient` | `request.ts` |
| `AuthService` | `AuthService.ts` |
| `RecordRepository` | `RecordRepository.ts` |
| `UploadQueueService` | `UploadQueueService.ts` |
| `MeritService` | `MeritService.ts` |
| `MediaCapture` + `MediaValidation` | 对应 Media* 服务 |

---

## 4. 数据流与同步

### 4.1 记录生命周期

```
创建(本地) → draft
  ├─ 有媒体 → queued → uploading → (全媒体成功) → POST /records → synced
  └─ 无媒体 + 已登录 → POST /records → synced
失败 → failed → 用户重试 → queued
退出登录 → 未 synced 标记 needsAccountBind
再次登录 → 自动入队推送（无需弹窗）
```

### 4.2 登录后首页双向同步（相对 H5 增强）

1. 已登录进入首页 / `onShow`：拉取远端 **当日列表** + 当月 **`/records/days` 打点**
2. 与本地按 `serverRecordId`（无则本地 `id`）合并
3. 刷新日历打点与列表
4. 本地领先或仅本地有 → **自动入队** 推送远端

**合并规则（LWW）**

| 情况 | 行为 |
|------|------|
| 仅远端有 | 写入本地，`status=synced` |
| 仅本地有 / `needsAccountBind` | 保留本地，**自动入队**上传 |
| 两端都有 | LWW 比较字段优先级：`syncVersion` > `serverUpdatedAt` > `updatedAt`；较新胜出。本地胜出 → 推送；远端胜出 → 覆盖本地 |
| 本地 `draft/queued/uploading/failed` | 不覆盖进行中的本地任务；任务完成后再对齐 |
| 本地已删且有 `serverRecordId` | 调用 `DELETE /records/:id` 后移除本地；远端已删则清本地副本 |

### 4.3 上传流水线

1. `POST /upload/policy` → `uploadUrl` / `objectKey` / `remoteUrl`
2. 原生上传文件 → 回写 `media.remoteUrl`
3. 该记录全部媒体成功 → `POST /records` 元数据
4. 重试：最多 3 次（2s / 5s / 10s）；并发 1
5. `settings_wifi_only` 开启时，蜂窝网络跳过自动上传
6. `EntryAbility` 回前台：`uploading` 降为 `queued` 并 `recoverPendingTasks`

### 4.4 鉴权

- 请求头：`Authorization: Bearer <accessToken>`
- 401 → `POST /auth/refresh`；失败清会话 → Login

### 4.5 功德卡

- 本地汇总；已登录再拉 `GET /merit/my`，展示 `max(本地, 云端)`

### 4.6 主要 API

| Method | Path | Auth |
|--------|------|------|
| POST | `/auth/sms/send` | 否 |
| POST | `/auth/sms/verify` | 否 |
| POST | `/auth/refresh` | 否（body token） |
| POST | `/auth/logout` | 是 |
| POST | `/upload/policy` | 是 |
| POST | `/records` | 是 |
| GET | `/records?dayKey=&page=&pageSize=` | 是 |
| GET | `/records/:id` | 是 |
| DELETE | `/records/:id` | 是 |
| GET | `/records/days?month=` | 是 |
| GET | `/merit/tags` | 否 |
| POST | `/merit/match` | 否 |
| GET | `/merit/my` | 是 |
| GET | `/merit/ranking?type=` | 是 |
| GET/PATCH | `/users/profile` | 是 |

---

## 5. 错误处理

| 场景 | 行为 |
|------|------|
| 网络失败（列表/同步） | Toast「网络不稳定」；保留本地展示；可后台重试 |
| 验证码错误/频控 | 展示后端文案 |
| Token 失效 | refresh；失败清会话 → Login |
| 上传失败 | 任务/记录 → `failed`；详情可重试 |
| 媒体超限/权限拒绝 | 校验拦截 + 明确文案；可继续纯文字 |
| 合并冲突写回失败 | 本地保留领先副本，任务 `failed`，可重试 |
| 清缓存 vs 清数据 | 行为分离；清数据强二次确认 |

---

## 6. 落地顺序与里程碑

1. 工程基线：包名、主题、`HttpClient`、preferences、路由  
2. 模型 + `RecordRepository`  
3. Auth + Login + Agreement  
4. 首页 Index（含双向合并）  
5. CreateRecord + RecordDetail  
6. Media + UploadQueue  
7. Merit + Ranking  
8. Settings  

**里程碑**

- **M1**：能登录 + 本地记账可见  
- **M2**：登录后双向合并正确（含自动回推）  
- **M3**：带媒体上传至 `synced`  
- **M4**：排行 + 设置闭环  

**验收用例（摘要）**

- 未登录创建 → 登录后自动入队并 `synced`
- 两端同记录不同时间戳 → LWW 正确覆盖/回推
- 弱网上传失败 → 重试成功
- 仅 Wi-Fi 在蜂窝下不自动传
- 退出后再登录：本地保留 + 自动合并推送
- 清缓存不误删记录；清数据需二次确认

---

## 7. 风险与备注

- H5 首页目前偏「只读本地」；鸿蒙按本规格实现 **双向同步**，属有意增强，后续 H5 可再对齐。
- 对象存储上传依赖 `upload/policy` 返回的 URL 与 headers；需在真机验证 HTTPS 与证书。
- DevEco / API 26 Stage 模型；媒体能力需按鸿蒙 PhotoAccessHelper / CameraKit 适配，行为对齐 H5，API 不必相同。
