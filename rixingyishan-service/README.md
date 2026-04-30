# rixingyishan-service

后端服务子工程（占位）。

## 职责（MVP）
- 手机号验证码登录（发码/校验/发放 token）
- 记录元数据 CRUD（按天分页、详情、删除）
- 上传凭证签发（对象存储 policy / STS / 签名 URL）
- 当月有记录 dayKey 列表（用于日历打点）
- 安全与合规：频控、鉴权、HTTPS、可选审核字段预留

## PRD 与接口约定
- PRD（总）：`docs/prd/2026-04-30-good-deeds-prd.md`
- PRD（后端）：后续拆分文档会放在 `docs/prd/` 下

## 下一步（建议）
- 明确技术栈（例如 Node.js/NestJS 或 Go/Gin 等）
- 明确对象存储（COS/OSS/S3）与数据库（MySQL/PostgreSQL）
- 输出接口文档（OpenAPI/Swagger）与本地开发启动方式

