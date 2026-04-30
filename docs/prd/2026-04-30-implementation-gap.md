# 实现差距与技术债清单（按前后端拆分）

## 说明
- **对齐 PRD**：
  - 前端：`docs/prd/2026-04-30-good-deeds-prd-ui.md`
  - 后端：`docs/prd/2026-04-30-good-deeds-prd-service.md`
- **优先级**：
  - **P0**：阻塞 MVP 交付或会造成严重数据问题
  - **P1**：影响体验/稳定性，但可在小范围降级后上线
  - **P2**：优化项/技术债

---

## 前端（rixingyishan-ui）

### P0（必须修复）

#### UI-P0-01 云同步链路未落地（上传 URL 占位，且未回写 remoteUrl）
- **现状**：`rixingyishan-ui/src/services/UploadQueueService.ts` 使用 `https://example.com/upload`；任务 success 后不回写 `record.media[mediaIndex].remoteUrl`，也未触发记录元数据同步。
- **影响**：不满足 PRD 的“真实上传 + 云同步”；详情页长期显示“未上传”。
- **建议**：接入后端 `POST /upload/policy` 与真实上传地址；解析响应回写 `remoteUrl/objectKey`；所有媒体成功+元数据同步成功后置 `synced`。
- **关联文件**：`rixingyishan-ui/src/services/UploadQueueService.ts`、`rixingyishan-ui/src/services/RecordRepository.ts`、`rixingyishan-ui/src/pages/record-detail/record-detail.vue`

#### UI-P0-02 清理缓存文案与行为不一致（存在误删数据风险）
- **现状**：`rixingyishan-ui/src/pages/settings/settings.vue` 使用 `uni.clearStorageSync()` 清空全部存储，弹窗却写“不会删除记录”。
- **影响**：用户可能丢失全部本地记录。
- **建议**：拆分为“清理上传任务/临时媒体缓存”（默认）与“删除所有本地记录”（独立入口+强二次确认）。
- **关联文件**：`rixingyishan-ui/src/pages/settings/settings.vue`、`rixingyishan-ui/src/services/RecordRepository.ts`

#### UI-P0-03 账号与登录页未实现（手机号验证码）
- **现状**：目前无登录页、无 token 管理、无请求封装。
- **影响**：无法触发云端同步与跨端一致性。
- **建议**：新增登录页与 AuthService；封装 request 层附带 token；启动时做登录门。
- **关联文件**：`rixingyishan-ui/src/pages.json`（新增页面）、`rixingyishan-ui/src/App.vue`、新增 `rixingyishan-ui/src/services/AuthService.ts`

#### UI-P0-04 `retryTask` 实现错误（单任务重试不可用）
- **现状**：`UploadQueueService.retryTask()` 通过 `getUploadTaskByRecord(\"\")` 查任务，无法匹配 `taskId`。
- **影响**：单任务重试失效。
- **建议**：仓储新增 `getUploadTaskById(taskId)` 或全量查询。
- **关联文件**：`rixingyishan-ui/src/services/UploadQueueService.ts`、`rixingyishan-ui/src/services/RecordRepository.ts`

#### UI-P0-05 混合媒体 record.type 判定不符合 PRD
- **现状**：`create-record.vue` 当前按“第一条媒体”判断类型；若后续添加视频会错标为 photo。
- **影响**：与 PRD 规则“任一视频则 video”冲突。
- **建议**：保存时扫描全部 `media[].mimeType`。
- **关联文件**：`rixingyishan-ui/src/pages/create-record/create-record.vue`

### P1（建议 MVP 期内完成）

#### UI-P1-01 首页返回不一定刷新列表/打点
- **现状**：首页主要在 `onMounted` 拉数。
- **建议**：在 `onShow` 刷新选中日列表；必要时刷新打点缓存。
- **关联文件**：`rixingyishan-ui/src/pages/index/index.vue`

#### UI-P1-02 仅 Wi-Fi 上传未接入队列执行
- **现状**：设置保存了 `settings_wifi_only`，队列未读取网络类型。
- **建议**：`processQueue` 前 `uni.getNetworkType`；非 Wi-Fi 且开关开启则不执行并保留 queued。
- **关联文件**：`rixingyishan-ui/src/pages/settings/settings.vue`、`rixingyishan-ui/src/services/UploadQueueService.ts`

#### UI-P1-03 视频时长设置未贯通录像与校验
- **现状**：adapter 固定 `maxDuration: 30`；校验固定 60s；设置页展示但不生效。
- **建议**：统一配置源（storage key）；录像、校验共同取最小值。
- **关联文件**：`rixingyishan-ui/src/platform-adapter/index.ts`、`rixingyishan-ui/src/services/MediaValidationService.ts`、`rixingyishan-ui/src/pages/settings/settings.vue`

#### UI-P1-04 详情页点击视频仍走图片预览逻辑
- **现状**：`previewMedia()` 一律 `uni.previewImage`。
- **建议**：图片预览走 `previewImage`；视频点击不触发或进入全屏播放页。
- **关联文件**：`rixingyishan-ui/src/pages/record-detail/record-detail.vue`

#### UI-P1-05 退出登录（方案 A）与“登录后合并上传”尚未实现
- **现状**：无退出入口、无合并弹窗。
- **建议**：设置页增加退出；退出暂停鉴权上传；登录成功后检测未绑定记录并弹窗确认合并入队。
- **关联文件**：`rixingyishan-ui/src/pages/settings/settings.vue`、`rixingyishan-ui/src/App.vue`、新增 Auth 模块、`rixingyishan-ui/src/services/UploadQueueService.ts`

#### UI-P1-06 协议/隐私入口未实现
- **现状**：设置页无入口、登录流程无勾选。
- **建议**：登录页增加勾选；设置页提供入口（WebView/外链）。

### P2（优化/技术债）
- **UI-P2-01**：日历打点计算重复 parse storage（可做月缓存/索引）  
  - 关联文件：`rixingyishan-ui/src/pages/index/index.vue`、`rixingyishan-ui/src/services/RecordRepository.ts`
- **UI-P2-02**：上传重试递归实现可改为 while 状态机  
  - 关联文件：`rixingyishan-ui/src/services/UploadQueueService.ts`
- **UI-P2-03**：埋点 SDK 未接入（封装 `analytics.track`）  
  - 关联文件：建议新增 `rixingyishan-ui/src/services/AnalyticsService.ts`

---

## 后端（rixingyishan-service）

### P0（必须实现）

#### SVC-P0-01 手机号验证码登录（send/verify/token）
- **需求**：实现 `POST /auth/sms/send`、`POST /auth/sms/verify`，并发放 `accessToken`（可选 refresh）。
- **关键点**：频控、错误码可区分（错误/过期/超限）、HTTPS、审计日志。

#### SVC-P0-02 上传凭证签发（policy/STS/签名 URL）
- **需求**：实现 `POST /upload/policy`，短时效、最小权限、约束 key 前缀。
- **关键点**：服务端校验 mime/size/扩展名；防止伪造回写。

#### SVC-P0-03 记录 CRUD + days 接口
- **需求**：`POST /records`、`GET /records`（按 dayKey 分页）、`GET /records/:id`、`DELETE /records/:id`、`GET /records/days?month=YYYY-MM`。
- **关键点**：稳定排序、软删优先、按用户隔离、时区规则固定。

#### SVC-P0-04 数据模型字段对齐（serverRecordId/syncVersion）
- **需求**：返回并维护 `serverRecordId`、`syncVersion` 或 `serverUpdatedAt`，支持增量与排障。

### P1（建议）
- **SVC-P1-01**：冲突策略落地（LWW + 可观测日志）
- **SVC-P1-02**：对象存储回收策略（删除记录时是否删除对象/延迟清理）
- **SVC-P1-03**：当月 days 接口性能优化（索引/聚合）

### P2（预留）
- **SVC-P2-01**：审核字段与异步审核流程（`auditStatus`）预留
- **SVC-P2-02**：更完整的风控（设备指纹、黑名单、验证码攻击防护）

---

## 建议交付顺序（前后端并行）
1. **SVC-P0-01** 登录 + Token 设计，同时前端补 **UI-P0-03** 登录页/请求封装  
2. **SVC-P0-02** policy + **UI-P0-01** 上传回写 remoteUrl  
3. **SVC-P0-03** records CRUD + days，同时前端补首页云端拉取与打点补全  
4. **UI-P0-02** 清理缓存修正 + **UI-P1-05** 退出/合并上传（方案 A）  

