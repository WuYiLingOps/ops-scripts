#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-08-06 14:00:00
#FileName:         blog-deploy.sh
#URL:              https://script.huangjingblog.cn
#Description:      gin-vue3-blog Jenkins 自由风格项目构建脚本
#Copyright (C):    2026 All rights reserved
#********************************************************************
set -eo pipefail

APP=gin-vue3-blog
PROJECT_PATH="${WORKSPACE:-$(pwd)}"
BACKEND_PATH="${PROJECT_PATH}/blog-backend"
FRONTEND_PATH="${PROJECT_PATH}/blog-frontend"
NGINX_CONFIG_PATH="${PROJECT_PATH}/nginx-config"
APP_PATH="/web"
DATA_PATH="/web/${APP}-data"
DATE=$(date +%F_%H-%M-%S)
SSH_USER="root"
NGINX_CONF_DIR="/etc/nginx/conf.d"
HOST_LIST="${HOST_LIST:-
10.0.0.112
10.0.0.113
}"

# 数据库配置默认值
DB_HOST="${DB_HOST:-pg.huang.org}"
DB_PASSWORD="${DB_PASSWORD:-123456ok!}"
REDIS_HOST="${REDIS_HOST:-redis.huang.org}"
REDIS_PASSWORD="${REDIS_PASSWORD:-123456}"

# 邮件配置默认值
EMAIL_HOST="${EMAIL_HOST:-smtp.qq.com}"
EMAIL_PORT="${EMAIL_PORT:-587}"
EMAIL_USERNAME="${EMAIL_USERNAME:-huangjing2001.guet@foxmail.com}"
EMAIL_PASSWORD="${EMAIL_PASSWORD:-}"

# Gitee 日历 API
GITEE_CALENDAR_API_URL="${GITEE_CALENDAR_API_URL:-https://huangjingblog.cn/gitee-calendar-api}"

# 腾讯云 COS 配置
COS_BUCKET_URL="${COS_BUCKET_URL:-}"
COS_SECRET_ID="${COS_SECRET_ID:-}"
COS_SECRET_KEY="${COS_SECRET_KEY:-}"

# Jenkins 构建环境中可覆盖以下变量
GO_BIN="/root/.g/go/bin/go"
PNPM_BIN="/root/.nvm/versions/node/v22.23.2/bin/pnpm"
GOPROXY="${GOPROXY:-http://nexus.huang.org/repository/go-group/,direct}"
GONOPROXY="${GONOPROXY:-golang.org/toolchain}"  # toolchain 不走代理
GOSUMDB="${GOSUMDB:-sum.golang.org}"  # 保持默认校验，仅 toolchain 需要
VITE_API_BASE_URL="${VITE_API_BASE_URL:-}"
VITE_WS_BASE_URL="${VITE_WS_BASE_URL:-}"
BACKEND_ENV_FILE="${PROJECT_PATH}/.env.config.prod"
FRONTEND_ENV_FILE="${FRONTEND_PATH}/.env.production"

create_env () {
    umask 077
    cat > "${BACKEND_ENV_FILE}" <<EOF
BLOG_URL=${BLOG_URL:-https://huangjingblog.cn}
DB_HOST=pg.huang.org
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=123456ok!
DB_NAME=blogdb
REDIS_HOST=redis.huang.org
REDIS_PORT=6379
REDIS_PASSWORD=123456
GITEE_CALENDAR_API_URL=https://huangjingblog.cn/gitee-calendar-api
EMAIL_HOST=smtp.qq.com
EMAIL_PORT=587
EMAIL_USERNAME=huangjing2001.guet@foxmail.com
EMAIL_PASSWORD=${EMAIL_PASSWORD:-}
COS_BUCKET_URL=${COS_BUCKET_URL:-}
COS_SECRET_ID=${COS_SECRET_ID:-}
COS_SECRET_KEY=${COS_SECRET_KEY:-}
EOF

    cat > "${FRONTEND_ENV_FILE}" <<EOF
VITE_API_BASE_URL=${VITE_API_BASE_URL}
VITE_WS_BASE_URL=${VITE_WS_BASE_URL}
EOF
}

build () {
    echo "[1/3] 开始构建 ${APP} 后端"
    cd "${BACKEND_PATH}"
    echo "Go 代理: ${GOPROXY}"
    echo "Go 校验: ${GOSUMDB}"
    echo "Go 不走代理: ${GONOPROXY}"
    export GOPROXY GOSUMDB GONOPROXY
    CGO_ENABLED=0 "${GO_BIN}" mod download
    CGO_ENABLED=0 "${GO_BIN}" build -o blog-backend ./cmd/server

    echo "[2/3] 开始构建 ${APP} 前端"
    cd "${FRONTEND_PATH}"
    echo "Pnpm: ${PNPM_BIN}"
    # 将 Node.js bin 目录添加到 PATH，确保 pnpm 能找到 node
    export PATH="/root/.nvm/versions/node/v22.23.2/bin:${PATH}"
    export VITE_API_BASE_URL VITE_WS_BASE_URL
    "${PNPM_BIN}" install
    NODE_OPTIONS="--max-old-space-size=1024" "${PNPM_BIN}" build

    echo "[3/3] 检查构建产物"
    test -x "${BACKEND_PATH}/blog-backend"
    test -f "${FRONTEND_PATH}/dist/index.html"
    echo "${APP} 构建完成"
}

deloy () {
    local host_count index=0 remote_release
    host_count=$(wc -w <<< "${HOST_LIST}")
    remote_release="${APP_PATH}/${APP}-${DATE}"

    for host in ${HOST_LIST}; do
        index=$((index + 1))
        echo "[${index}/${host_count}] 发布到远程服务器 ${host}"

        ssh "${SSH_USER}@${host}" \
            "mkdir -p '${remote_release}/blog-backend' \
            '${remote_release}/blog-frontend' '${DATA_PATH}/uploads' \
            '/var/log/${APP}'"

        scp "${BACKEND_PATH}/blog-backend" \
            "${SSH_USER}@${host}:${remote_release}/blog-backend/"
        scp -r "${BACKEND_PATH}/config" \
            "${SSH_USER}@${host}:${remote_release}/blog-backend/"
        scp "${BACKEND_ENV_FILE}" \
            "${SSH_USER}@${host}:${remote_release}/blog-backend/.env.config.prod"
        scp -r "${FRONTEND_PATH}/dist" \
            "${SSH_USER}@${host}:${remote_release}/blog-frontend/"

        # 部署 Nginx 配置
        if [ -f "${NGINX_CONFIG_PATH}/go-blog-dev.conf" ]; then
            echo "部署 Nginx 配置到 ${host}"
            scp "${NGINX_CONFIG_PATH}/go-blog-dev.conf" \
                "${SSH_USER}@${host}:${NGINX_CONF_DIR}/${APP}.conf"
            # 修改 Nginx 配置中的 server_name 为当前服务器 IP
            ssh "${SSH_USER}@${host}" \
                "sed -i 's/server_name .*/server_name ${host};/' '${NGINX_CONF_DIR}/${APP}.conf'"
        fi

        ssh "${SSH_USER}@${host}" "set -e
            sed -i 's/^env:.*/env: prod/' '${remote_release}/blog-backend/config/config.yml'
            ln -sfn '${DATA_PATH}/uploads' '${remote_release}/blog-backend/uploads'
            pkill -x blog-backend >/dev/null 2>&1 || true
            ln -sfn '${remote_release}' '${APP_PATH}/${APP}'
            # 设置前端静态文件权限
            chmod -R 644 '${APP_PATH}/${APP}/blog-frontend/dist'
            find '${APP_PATH}/${APP}/blog-frontend/dist' -type d -exec chmod 755 {} \;
            if [ -f '${NGINX_CONF_DIR}/${APP}.conf' ]; then
                nginx -t && nginx -s reload
            fi
            cd '${APP_PATH}/${APP}/blog-backend'
            nohup ./blog-backend </dev/null >'/var/log/${APP}/stdout.log' 2>&1 &"

        echo "服务器 ${host} 发布完成"
    done
}

create_env
trap 'rm -f "${BACKEND_ENV_FILE}" "${FRONTEND_ENV_FILE}"' EXIT
build
deloy
