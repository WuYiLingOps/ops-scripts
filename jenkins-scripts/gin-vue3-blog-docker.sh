#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-08-21 00:00:00
#FileName:         gin-vue3-blog-docker.sh
#URL:              https://script.huangjingblog.cn
#Description:      gin-vue3-blog Jenkins docker 发布脚本
#Copyright (C):    2026 All rights reserved
#********************************************************************
set -eo pipefail

APP=gin-vue3-blog
PROJECT_PATH="${WORKSPACE:-$(pwd)}"
BACKEND_PATH="${PROJECT_PATH}/blog-backend"
FRONTEND_PATH="${PROJECT_PATH}/blog-frontend"
DEPLOY_PATH="${PROJECT_PATH}/deploy"
APP_PATH="/web"
DATA_PATH="/web/${APP}-data"
DATE=$(date +%F_%H-%M-%S)
SSH_USER="${SSH_USER:-root}"
HOST_LIST="${HOST_LIST:-
10.0.0.112
10.0.0.113
}"

HARBOR="${HARBOR:-harbor.huang.org}"
REPO="${REPO:-example}"
HARBOR_USER="${HARBOR_USER:-admin}"
PASSWD="${PASSWD:-123456}"
TAG="${TAG:-${BUILD_NUMBER:-${DATE}}}"
PORT="${PORT:-8080}"
CONTAINER_PORT="80"
IMAGE="${HARBOR}/${REPO}/${APP}:${TAG}"
CONTAINER_NAME="${CONTAINER_NAME:-${APP}}"

DB_HOST="${DB_HOST:-10.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_PASSWORD="${DB_PASSWORD:-123456ok!}"
DB_NAME="${DB_NAME:-blogdb}"
REDIS_HOST="${REDIS_HOST:-10.0.0.1}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-123456}"
JWT_SECRET="${JWT_SECRET:-}"
JWT_EXPIRE_HOURS="${JWT_EXPIRE_HOURS:-72}"
BLOG_URL="${BLOG_URL:-https://huangjingblog.cn}"
GITEE_CALENDAR_API_URL="${GITEE_CALENDAR_API_URL:-https://huangjingblog.cn/gitee-calendar-api}"
EMAIL_HOST="${EMAIL_HOST:-smtp.qq.com}"
EMAIL_PORT="${EMAIL_PORT:-587}"
EMAIL_USERNAME="${EMAIL_USERNAME:-huangjing2001.guet@foxmail.com}"
EMAIL_PASSWORD="${EMAIL_PASSWORD:-}"
OSS_ENDPOINT="${OSS_ENDPOINT:-}"
OSS_ACCESS_KEY_ID="${OSS_ACCESS_KEY_ID:-}"
OSS_ACCESS_KEY_SECRET="${OSS_ACCESS_KEY_SECRET:-}"
OSS_BUCKET_NAME="${OSS_BUCKET_NAME:-}"
OSS_DOMAIN="${OSS_DOMAIN:-}"
COS_BUCKET_URL="${COS_BUCKET_URL:-}"
COS_SECRET_ID="${COS_SECRET_ID:-}"
COS_SECRET_KEY="${COS_SECRET_KEY:-}"
COS_DOMAIN="${COS_DOMAIN:-}"
VITE_API_BASE_URL="${VITE_API_BASE_URL:-}"
VITE_WS_BASE_URL="${VITE_WS_BASE_URL:-}"
TZ="${TZ:-Asia/Shanghai}"

BACKEND_ENV_FILE="${PROJECT_PATH}/.env.config.prod"
FRONTEND_ENV_FILE="${FRONTEND_PATH}/.env.production"
REMOTE_RELEASE="${APP_PATH}/${APP}-${DATE}"
REMOTE_CONFIG_DIR="${REMOTE_RELEASE}/config"
REMOTE_ENV_FILE="${REMOTE_RELEASE}/.env.config.prod"
REMOTE_UPLOADS_DIR="${DATA_PATH}/uploads"
REMOTE_LOG_DIR="/var/log/${APP}"

create_env () {
    echo "[1/4] 生成 ${APP} 环境文件"
    umask 077
    cat > "${BACKEND_ENV_FILE}" <<EOF
BLOG_URL=${BLOG_URL}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRE_HOURS=${JWT_EXPIRE_HOURS}
GITEE_CALENDAR_API_URL=${GITEE_CALENDAR_API_URL}
EMAIL_HOST=${EMAIL_HOST}
EMAIL_PORT=${EMAIL_PORT}
EMAIL_USERNAME=${EMAIL_USERNAME}
EMAIL_PASSWORD=${EMAIL_PASSWORD}
OSS_ENDPOINT=${OSS_ENDPOINT}
OSS_ACCESS_KEY_ID=${OSS_ACCESS_KEY_ID}
OSS_ACCESS_KEY_SECRET=${OSS_ACCESS_KEY_SECRET}
OSS_BUCKET_NAME=${OSS_BUCKET_NAME}
OSS_DOMAIN=${OSS_DOMAIN}
COS_BUCKET_URL=${COS_BUCKET_URL}
COS_SECRET_ID=${COS_SECRET_ID}
COS_SECRET_KEY=${COS_SECRET_KEY}
COS_DOMAIN=${COS_DOMAIN}
EOF

    cat > "${FRONTEND_ENV_FILE}" <<EOF
VITE_API_BASE_URL=${VITE_API_BASE_URL}
VITE_WS_BASE_URL=${VITE_WS_BASE_URL}
EOF

    test -f "${BACKEND_ENV_FILE}"
    test -f "${FRONTEND_ENV_FILE}"
}

build_image () {
    echo "[2/4] 开始构建 ${APP} Docker 镜像"
    cd "${PROJECT_PATH}"
    test -d "${BACKEND_PATH}"
    test -d "${FRONTEND_PATH}"
    test -f "${DEPLOY_PATH}/Dockerfile"

    docker build -f "${DEPLOY_PATH}/Dockerfile" -t "${IMAGE}" .
    docker image inspect "${IMAGE}" >/dev/null
}

push_image () {
    echo "[3/4] 登录 Harbor 并推送镜像"
    docker login "${HARBOR}" -u "${HARBOR_USER}" -p "${PASSWD}"
    docker push "${IMAGE}"
}

deploy () {
    local host_count index=0
    host_count=$(wc -w <<< "${HOST_LIST}")

    for host in ${HOST_LIST}; do
        index=$((index + 1))
        echo "[4/4] [${index}/${host_count}] 发布到远程服务器 ${host}"

        ssh "${SSH_USER}@${host}" \
            "mkdir -p '${REMOTE_CONFIG_DIR}' '${REMOTE_UPLOADS_DIR}' '${REMOTE_LOG_DIR}'"

        scp -r "${BACKEND_PATH}/config/." \
            "${SSH_USER}@${host}:${REMOTE_CONFIG_DIR}/"
        scp "${BACKEND_ENV_FILE}" \
            "${SSH_USER}@${host}:${REMOTE_ENV_FILE}"

        ssh "${SSH_USER}@${host}" "set -e
            sed -i 's/^env:.*/env: prod/' '${REMOTE_CONFIG_DIR}/config.yml'
            docker rm -f '${CONTAINER_NAME}' >/dev/null 2>&1 || true
            docker run -d \
                --restart unless-stopped \
                --name '${CONTAINER_NAME}' \
                -e TZ='${TZ}' \
                -p ${PORT}:${CONTAINER_PORT} \
                -v '${REMOTE_CONFIG_DIR}:/app/config' \
                -v '${REMOTE_ENV_FILE}:/app/.env.config.prod:ro' \
                -v '${REMOTE_UPLOADS_DIR}:/app/uploads' \
                -v '${REMOTE_LOG_DIR}:/var/log/gin-vue3-blog' \
                '${IMAGE}'"
        echo "服务器 ${host} 发布完成"
    done
}

trap 'rm -f "${BACKEND_ENV_FILE}" "${FRONTEND_ENV_FILE}"' EXIT
create_env
build_image
push_image
deploy
