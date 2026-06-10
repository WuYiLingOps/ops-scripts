#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-09
#FileName:         backup_blogdb.sh
#URL:              https://script.huangjingblog.cn
#Description:      postgres数据自动备份脚本
#Copyright (C):    2026 All rights reserved
#********************************************************************
set -e

BACKUP_DIR="/data/backups/blogdb"
DB_NAME="blogdb"
DB_USER="postgres"
CONTAINER_NAME="pg-prod"   # 如无 Docker，请留空或调整

mkdir -p "${BACKUP_DIR}"
DATE_STR="$(date +%Y%m%d)"
BACKUP_FILE="${BACKUP_DIR}/blogdb_${DATE_STR}.dump"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  echo "检测到 Docker 容器 ${CONTAINER_NAME}，使用容器内 pg_dump 备份..."
  docker exec "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" -Fc > "${BACKUP_FILE}"
else
  echo "未检测到容器 ${CONTAINER_NAME}，使用本机 pg_dump 备份..."
  pg_dump -h localhost -U "${DB_USER}" -d "${DB_NAME}" -Fc > "${BACKUP_FILE}"
fi

# 可选：自动清理 30 天前的旧备份
find "${BACKUP_DIR}" -type f -mtime +30 -delete
