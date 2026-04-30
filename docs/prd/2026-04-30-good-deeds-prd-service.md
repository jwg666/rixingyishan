# PRD（后端）｜日行一善（Good Deeds）`rixingyishan-service`（MVP）

> 本文为后端 PRD，面向服务子工程：`rixingyishan-service/`。  
> 前端 PRD：`docs/prd/2026-04-30-good-deeds-prd-ui.md`。  
> PRD 总览索引：`docs/prd/2026-04-30-good-deeds-prd.md`。

## 0. 技术选型（已确定）
- **技术栈**：Spring Boot（建议 Java 17）
- **数据库**：MySQL 8.x
- **对象存储**：阿里云 OSS（图片/视频）
- **鉴权**：Bearer Token（MVP 推荐 JWT）

## 1. 目标与范围（后端）
- 手机号验证码登录：发码/校验/发放 token
- 记录元数据：创建、查询（按天分页/详情）、删除（软删优先）
- OSS 上传签名：直传 policy（MVP），可扩展 STS 或预签名 URL
- 日历打点：当月有记录 dayKey 列表
- 安全合规：频控、鉴权、HTTPS、审计日志、可选审核字段预留

### 1.1 MVP 不做
- 社区/公开访问/分享链路
- 复杂搜索（全文检索、多维筛选）
- 多媒体编辑、服务端转码/压缩
- 完整内容审核闭环（仅字段预留）

### 1.2 一致性与幂等目标
- **最终一致**：客户端 local-first；服务端提供可靠同步接口
- **幂等创建**：客户端重试不会产生重复记录
- **软删一致**：删除在多端一致可见

## 2. API 总览

### 2.1 通用约定
- Base URL：`/api/v1`
- 鉴权：`Authorization: Bearer <accessToken>`
- 时间：ISO8601（UTC 推荐）
- dayKey：`YYYY-MM-DD`
- 分页：`page` 从 1 开始，`pageSize` 默认 20，最大 50
- 错误响应：统一 JSON（见第 10 章）

### 2.2 接口清单（MVP）
- `POST /auth/sms/send`
- `POST /auth/sms/verify`
- `POST /upload/policy`
- `POST /records`
- `GET /records?dayKey=YYYY-MM-DD&page=1&pageSize=20`
- `GET /records/{id}`
- `DELETE /records/{id}`
- `GET /records/days?month=YYYY-MM`

## 3. 认证与安全

### 3.1 手机号验证码
#### 3.1.1 发送验证码 `POST /auth/sms/send`
**入参**
- `phone`：字符串
- `scene`：`login`
- `deviceId?`：客户端生成的设备标识（用于风控/频控）

**规则**
- 同手机号 60 秒内最多 1 次（服务端强制）
- 同 IP/同 deviceId 每日总量上限（可配置）
- 验证码有效期 10 分钟（可配置）

**出参**
- `cooldownSeconds`：剩余冷却时间

#### 3.1.2 校验并登录 `POST /auth/sms/verify`
**入参**
- `phone`
- `code`
- `deviceId?`

**出参**
- `accessToken`
- `expiresInSeconds`
- `user`: `{ id, phone }`

### 3.2 Token 方案（MVP）
- **JWT**：有效期 7 天（可配置）
- claim 建议：
  - `sub`：userId
  - `iat/exp`
  - `jti`（可选：如后续做强制失效黑名单）
- **登出**：MVP 可不做服务端强制失效，仅客户端清 token

### 3.3 基础安全要求
- 全站 HTTPS
- 限流：短信、登录、上传签名、records 写入（按 IP/手机号/deviceId）
- 输入校验：长度、字符集、tags 数量、content 最大长度
- 审计日志：登录成功/失败、签名签发、records 写入/删除（不落敏感内容/验证码）

## 4. OSS 上传（阿里云）

### 4.1 OSS 目录与 key 规则（建议）
- bucket：`good-deeds-<env>`（dev/staging/prod 分桶或分前缀）
- key：
  - `users/{userId}/records/{yyyy}/{mm}/{dd}/{clientRecordId}/{assetId}.{ext}`

### 4.2 签名方式选择
MVP 采用 **policy 表单直传**：
- 优点：客户端直传 OSS，带宽成本低
- 风险：需要控制 key 前缀与大小上限；服务端对回写 objectKey 做校验

### 4.3 获取上传 policy `POST /upload/policy`
**入参**
- `clientRecordId`
- `mimeType`
- `sizeBytes`
- `ext`（如 jpg/png/mp4）

**出参（示例字段）**
- `host`：`https://<bucket>.<endpoint>`
- `accessKeyId`
- `policy`：base64
- `signature`
- `expireAt`（epoch 秒）
- `key`（服务端生成，带前缀约束）
- `callback?`（可选，MVP 可不启用）

**服务端约束**
- policy 过期：120 秒（可配置）
- content-length-range：
  - 图片 ≤ 10MB
  - 视频 ≤ 50MB
- key 必须落在 `users/{userId}/` 前缀

### 4.4 回写策略
- 客户端上传成功后，在 `POST /records` 中携带：
  - `media[].objectKey`（必填，推荐）
  - `media[].remoteUrl`（可选，若有 CDN 可由服务端拼装返回）
- 服务端校验：
  - objectKey 前缀必须匹配当前 userId
  - mime/size/duration 合理范围

## 5. Records API（MVP 详细）

### 5.1 创建记录 `POST /records`
**幂等**
- Header：`Idempotency-Key`（推荐）或 body `clientRecordId`（必填）
- 规则：同 `userId + clientRecordId` 重复提交返回同一条记录（upsert 或返回已有）

**入参（建议）**
- `clientRecordId`（必填）
- `type`：`text|photo|video`
- `title?`（≤50）
- `content`（必填，≤1000）
- `tags?`（数组，数量 ≤ 10，单个长度 ≤ 20）
- `dayKey`（必填）
- `createdAt`、`updatedAt`（客户端时间）
- `media[]`（可选）
  - `objectKey`（必填）
  - `mimeType`（必填）
  - `width/height?`
  - `durationMs?`
  - `sizeBytes?`

**出参**
- `serverRecordId`
- `serverUpdatedAt`（或 `syncVersion`）
- `record`（回传完整字段，含 media remoteUrl/objKey）

### 5.2 查询当天列表 `GET /records`
- 入参：`dayKey,page,pageSize`
- 返回：`items[]` + `page` + `pageSize` + `hasMore`
- 排序：`createdAtClient desc, id desc`

### 5.3 查询详情 `GET /records/{id}`
- 权限：必须属于当前 userId

### 5.4 删除记录 `DELETE /records/{id}`
- 语义：软删（写 `deletedAt`）
- 返回：`deletedAt`

### 5.5 日历打点 `GET /records/days?month=YYYY-MM`
- 返回：`dayKeys: string[]`
- 约束：仅返回未删除记录的 dayKey

## 6. 数据模型（MySQL 8.x 建议）

> 下面是“可直接建表”的字段级建议（具体 DDL 由实现团队决定）。

### 6.1 `users`
- `id` BIGINT PK
- `phone` VARCHAR(20) UNIQUE
- `created_at` DATETIME(3)
- `updated_at` DATETIME(3)

### 6.2 `auth_sms_code`（可选）
- `id` BIGINT PK
- `phone` VARCHAR(20)
- `code_hash` VARCHAR(128)
- `sent_at` DATETIME(3)
- `expires_at` DATETIME(3)
- `used_at` DATETIME(3) NULL
- `ip` VARCHAR(64) NULL
- `device_id` VARCHAR(128) NULL
- index：`idx_phone_sent_at(phone, sent_at)`

### 6.3 `records`
- `id` BIGINT PK（serverRecordId）
- `user_id` BIGINT NOT NULL
- `client_record_id` VARCHAR(64) NOT NULL
- `type` ENUM('text','photo','video') NOT NULL
- `title` VARCHAR(50) NULL
- `content` VARCHAR(1000) NOT NULL
- `day_key` CHAR(10) NOT NULL
- `tags_json` JSON NULL
- `created_at_client` DATETIME(3) NOT NULL
- `updated_at_client` DATETIME(3) NOT NULL
- `server_updated_at` DATETIME(3) NOT NULL
- `deleted_at` DATETIME(3) NULL
- `audit_status` ENUM('pending','pass','reject') NULL
- unique：`uk_user_client_record(user_id, client_record_id)`
- index：`idx_user_day(user_id, day_key, server_updated_at)`

### 6.4 `record_assets`
- `id` BIGINT PK（serverAssetId）
- `record_id` BIGINT NOT NULL
- `user_id` BIGINT NOT NULL
- `object_key` VARCHAR(512) NOT NULL
- `remote_url` VARCHAR(1024) NULL
- `mime_type` VARCHAR(100) NOT NULL
- `width` INT NULL
- `height` INT NULL
- `duration_ms` INT NULL
- `size_bytes` BIGINT NULL
- `created_at` DATETIME(3) NOT NULL
- index：`idx_record_id(record_id)`

## 7. Spring Boot 工程形态（建议）
- 分层：
  - `controller`：REST
  - `service`：业务
  - `repository`：MyBatis(-Plus) 或 JPA（二选一）
  - `domain/dto`：实体与 DTO
  - `config`：Security、CORS、OSS、RateLimit
- 推荐组件：
  - Spring Web、Validation
  - Spring Security + JWT
  - MyBatis-Plus（或 JPA）
  - Flyway/Liquibase（迁移）
  - Aliyun OSS SDK
  - Redis（可选，推荐用于频控/验证码）

## 8. 配置项（建议）
- MySQL：
  - `SPRING_DATASOURCE_URL`
  - `SPRING_DATASOURCE_USERNAME`
  - `SPRING_DATASOURCE_PASSWORD`
- OSS：
  - `OSS_ENDPOINT`
  - `OSS_BUCKET`
  - `OSS_ACCESS_KEY_ID`
  - `OSS_ACCESS_KEY_SECRET`
  - `OSS_CDN_DOMAIN`（可选）
- JWT：
  - `JWT_SECRET`（或 RSA key）
  - `JWT_EXPIRES_DAYS`
- 业务：
  - `UPLOAD_POLICY_EXPIRE_SECONDS`（默认 120）
  - `MAX_IMAGE_BYTES`、`MAX_VIDEO_BYTES`

## 9. 可观测性与审计（MVP）
- 结构化日志：traceId、userId、path、statusCode、latency
- 指标：\n  - 短信发送量/失败率/频控命中\n  - policy 签发量/失败率\n  - records 写入/删除量\n  - 错误码分布\n

## 10. 错误码（建议）
- `AUTH_SMS_RATE_LIMITED`
- `AUTH_SMS_INVALID_CODE`
- `AUTH_SMS_EXPIRED`
- `AUTH_UNAUTHORIZED`
- `OSS_POLICY_DENIED`
- `RECORD_NOT_FOUND`
- `RECORD_FORBIDDEN`
- `VALIDATION_ERROR`

错误响应建议格式：
```json
{
  "code": "VALIDATION_ERROR",
  "message": "content is required",
  "requestId": "..."
}
```

## 11. 验收要点（后端）
- 登录：验证码频控有效；错误码可区分（错误/过期/超限）
- policy：只能写入允许的 key 前缀；过期后不可用；大小限制生效
- records：按天分页正确；软删后多端一致；days 接口支撑日历打点
- 安全：HTTPS、鉴权校验、最小日志泄露

