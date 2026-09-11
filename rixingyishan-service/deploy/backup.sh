#!/usr/bin/env bash
# SQLite 定时备份：sqlite3 .backup 优先（在线安全快照），无 sqlite3 时退回文件拷贝
# crontab 示例（每天 03:10）：10 3 * * * /opt/rixingyishan-service/deploy/backup.sh >> /var/log/rixingyishan-backup.log 2>&1
set -euo pipefail

APP_DIR="/opt/rixingyishan-service"
BACKUP_DIR="$APP_DIR/backups"
KEEP_DAYS=14

mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d_%H%M%S)
DEST="$BACKUP_DIR/rixingyishan_$STAMP.db"

if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$APP_DIR/data/rixingyishan.db" ".backup '$DEST'"
else
    cp "$APP_DIR/data/rixingyishan.db" "$DEST"
fi

find "$BACKUP_DIR" -name 'rixingyishan_*.db' -mtime +"$KEEP_DAYS" -delete
echo "backup ok: $DEST"
