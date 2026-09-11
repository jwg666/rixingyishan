# rixingyishan-service 部署指引

目标形态：Linux 服务器 + systemd 常驻 + nginx 反代（HTTPS、子路径 `/rxys`）+ SQLite 定时备份。

## 1. 构建

依赖已全部纯 Go 化（sqlite 驱动为 glebarez/sqlite），无需 CGO/gcc，可交叉编译：

```bash
cd rixingyishan-service
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rixingyishan-service .
```

产物为单文件二进制，连同 `deploy/` 一起上传。

## 2. 服务器目录

约定部署到 `/opt/rixingyishan-service`：

```bash
sudo mkdir -p /opt/rixingyishan-service
scp rixingyishan-service deploy/* user@server:/opt/rixingyishan-service/
```

## 3. 配置 .env

```bash
cd /opt/rixingyishan-service
cp .env.example .env
openssl rand -hex 32   # 生成 JWT_SECRET 填入 .env
```

必填项：
- `JWT_SECRET`：不配置则每次重启随机生成，所有登录会话失效
- `RXYS_BASE_URL`：公网地址（如 `https://your.domain/rxys`），决定 remoteUrl 拼接
- `SMS_PROVIDER`：`aliyun` 为真实短信（需填 `ALIYUN_*` 四项）；开发环境留 mock，验证码固定 `123456`

## 4. systemd 常驻

```bash
sudo cp deploy/rixingyishan.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now rixingyishan
curl http://127.0.0.1:8866/api/health   # {"code":0,...} 即正常
```

## 5. nginx 反代 + HTTPS

参考 `deploy/nginx.conf.example`。要点：
- `location /rxys/ { proxy_pass http://127.0.0.1:8866/; }`（末尾斜杠剥前缀）
- `client_max_body_size 60m`（视频上限 50MB）
- 证书用 certbot 签发：`sudo certbot --nginx -d your.domain`

## 6. 定时备份

```bash
chmod +x /opt/rixingyishan-service/deploy/backup.sh
crontab -e
# 10 3 * * * /opt/rixingyishan-service/deploy/backup.sh >> /var/log/rxys-backup.log 2>&1
```

备份保留 14 天。注意 `uploads/` 目录存放媒体文件，如需容灾可另行 rsync 到异地。

## 7. 升级流程

```bash
# 本机构建 → scp 覆盖二进制 → 服务器：
sudo systemctl restart rixingyishan
```

数据库 schema 变更由启动时 AutoMigrate 自动处理；升级前建议手动跑一次 `deploy/backup.sh`。
