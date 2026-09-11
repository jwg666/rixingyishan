# 下一步开发计划（2026-09-11）

## 现状小结
- **后端（rixingyishan-service）**：MVP PRD 接口清单全部实现，并超出 PRD 加了功德标签/匹配、排行榜（total/daily）、用户资料三块。技术栈 Go + Gin + GORM + SQLite。
- **鸿蒙端（rixingyishan-hm）**：已提交 8 个 commit——模型/存储、登录/协议、首页日历+列表+onShow 同步、创建/详情、功德、排行页、设置页（资料/缓存/退出/导出）、上传队列（policy 上传/暂停恢复/仅 Wi-Fi/回前台恢复）、LWW 同步核心（含单测）。
- **在途未提交**：Settings 返回路由修正、无用 import 清理、module.json5 权限清理（cameraPicker/PhotoViewPicker 为系统 Picker 无需权限，属正确清理，可直接提交）。
- **rixingyishan-ui（uni-app）**：长期未动，gap 清单中多项 P0 未修，见 P2 决策项。

## 关键结论（决定优先级）
1. **同步闭环差最后一块**：`SyncMergeService.ets:67` 注释"后端暂无更新接口，本地胜出只能跳过"。LWW 合并能拉、能建，不能更新。
2. **上传接口裸奔**：`/api/upload/policy`、`/api/upload/file` 无鉴权、无 mime/大小/扩展名校验，公网部署即可被任意刷盘、传任意文件。
3. **功德可刷**：`POST /records` 的 `meritValue` 由客户端上报直接入库并累加 `total_merit`，伪造请求即可刷榜。
4. **删除口径不一致**：软删记录不扣 `users.total_merit`，总榜只增不减；日榜实时 SUM 是对的，总榜失真。
5. **上线欠账**：JWT secret 硬编码、验证码/频控/token 黑名单全内存、无后端测试、README 仍是占位文案。

---

## P0 — 打通闭环 + 公网可用（本轮必须）

### SVC-1 记录更新接口 `PUT /records/:id`（LWW）
- **改动**：`handler/record.go`、`service/record.go`、`main.go` 路由。
- **做法**：请求携带 `syncVersion` + 全量字段（content/tag/media 等）；服务端比较——incoming > server 则更新并 `syncVersion+1` 返回新记录；否则返回 **409** + 服务端当前记录（客户端据此再合并）。
- **联动**：`SyncMergeService.ets` 本地胜出分支改为调用 update，替换现在的 skip 逻辑；`RecordApiService` 增加 `update()`；更新接口同样走服务端计分（见 SVC-4）。
- **验收**：两份副本分别改同一条记录，后提交者胜出且 `syncVersion` 递增；旧版本提交得到 409；带 media 的更新正确替换关联。

### SVC-2 上传链路鉴权与校验
- **改动**：`handler/upload.go`、`main.go`。
- **做法**：policy 与 file 两个端点挂 `AuthRequired()`；file 校验 mime 白名单（image/jpeg、image/png、image/webp、video/mp4）、大小上限（图片 10MB / 视频 50MB，对齐 `MediaValidationService` 现有值）、扩展名与 mime 一致；`objectKey` 由服务端生成，不信任客户端传入路径。
- **验收**：未登录 401；超限/非法类型 4xx；伪造 objectKey 路径穿越无效。

### SVC-3 删除功德一致性
- **改动**：`service/record.go` `DeleteRecord`。
- **做法**：软删与 `users.total_merit` 扣减放在同一事务；仅对 `merit_value > 0` 的记录扣减。
- **验收**：创建（+15）→ 删除后 `GET /api/merit/my` 的 `totalMerit` 回落到原值；删除不存在的记录不扣分。

### SVC-4 meritValue 服务端权威
- **改动**：`service/record.go` `CreateRecord`（及 SVC-1 的 update）。
- **做法**：服务端按 tag 从 `MeritTag` 配置查 `meritValue` 入库与累加，忽略客户端上报值；tag 不在配置中则落"其他善行"。客户端已有 `POST /merit/match` 预览分值，闭环不破坏。
- **验收**：客户端上报 `meritValue=99999` 无效；`GET /api/merit/my` 与按 tag 配置一致。

### HM-1 客户端接入更新接口（与 SVC-1 同步做）
- **改动**：`SyncMergeService.ets`、`RecordApiService.ets`；409 分支把服务端记录合并回本地。
- **验收**：模拟双端（卸载重装 + 备份导入）编辑同一条记录，最终两端一致且 status=synced。

---

## P1 — 上线准备（本轮内完成）

### SVC-5 配置安全化
- JWTSecret、阿里云 SMS 密钥全部走 `.env`（loadDotEnv 已具备），删除 config.go 中的硬编码 secret；仓库提交 `.env.example`；`RXYS_BASE_URL`、`SMS_PROVIDER` 文档化。
- **验收**：clone 后仅凭 `.env.example` 能起服务；代码中 grep 不到明文 secret。

### SVC-6 后端核心路径单测
- 覆盖：验证码 TTL/尝试次数/频控、token 签发/刷新/黑名单、record create/list/days/delete+扣分、LWW 更新（含 409）、upload 校验拒绝分支。SQLite 内存库即可。
- **验收**：`go test ./...` 全绿，核心 service 覆盖。

### DEP-1 部署上线
- nginx `/rxys` 反代 + HTTPS（后端 README 已提示目标域名）、systemd 常驻、`RXYS_BASE_URL` 指向公网地址、SQLite 文件定时备份（crontab）、`/api/health` 接入监控。
- **验收**：鸿蒙真机连公网域名走通登录→创建→上传→同步全链路。

### HM-2 双端联调清单
- 401 过期自动刷新（HttpClient 已实现，真机验证）；仅 Wi-Fi 上传开关；详情页删除（本地+远端）后打点/榜单回落；退出登录→换账号登录后本地未绑定记录并入新账号（`afterLoginAutoPush`）。

---

## P2 — 下一轮（技术债与增强）
- **SVC-7**：内存态（验证码/频控/token 黑名单）落库或 Redis，加过期清理 goroutine，为多实例做准备。
- **SVC-8**：对象存储迁移到阿里云 OSS（PRD 原方案 policy/STS），本地磁盘保留为开发 fallback。
- **SVC-9**：`auditStatus` 审核字段预留、设备维度风控。
- **SVC-10**：`(user_id, record_date)` 联合索引；榜单 myRank 不在前 50 时兜底实时计算。
- **DOC-1**：重写后端 README（真实功能清单 + 启动方式）；可选输出 OpenAPI。
- **DEC-1（决策项）**：rixingyishan-ui 去留——要么冻结并在其 README 标注"以 hm 为主端"，要么排期补齐 gap 清单中 UI-P0-01/02/03/04/05。默认建议：冻结。
- **HM-3**：日历打点月缓存、上传重试 while 状态机等 P2 优化。

## 建议排期
1. **第 1 步（约 2 天）**：SVC-1 ~ SVC-4 + 单测（SVC-6 先覆盖这批新逻辑），后端一次交付。
2. **第 2 步（约 1 天）**：HM-1 客户端接入 + 真机联调（HM-2 清单）。
3. **第 3 步（约 1 天）**：SVC-5 + DEP-1 部署上线。
4. **之后**：P2 按需排期，DEC-1 先定方向。
