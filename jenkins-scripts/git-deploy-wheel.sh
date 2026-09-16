#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-21
#FileName:         git-deploy-wheel.sh
#URL:              https://script.huangjingblog.cn
#Description:      基于 Git 拉取的 wheel 应用自动化部署和回滚脚本
#Copyright (C):    2026 All rights reserved
#********************************************************************

# Git 仓库地址
GIT_REPO="git@gitlab.huang.org:devops/wheel_of_fortune.git"
# 本地 Git 项目根目录
LOCAL_CODE_DIR="/data/git"
# 目标服务器列表
HOST_LIST="
10.0.0.112
10.0.0.113
10.0.0.114
"
# 应用名称
APP=wheel
# 应用部署目标路径（软链接）
APP_PATH=/usr/share/nginx/html
# 版本包存储根目录
DATA_PATH=/opt
# 时间戳（版本目录命名）
DATE=$(date +%F_%H-%M-%S)

# 部署函数
deploy() {
    BRANCH=$1
    # 校验分支参数
    if [[ -z "${BRANCH}" ]]; then
        echo "错误：请指定要部署的分支名"
        echo "用法：$0 deploy <分支名>"
        exit 1
    fi

    echo "开始部署分支：${BRANCH}"

    # 1. 清空本地项目目录并重新克隆
    LOCAL_PROJECT_DIR="${LOCAL_CODE_DIR}/${APP}"
    echo "[1/4] 清空本地目录 ${LOCAL_PROJECT_DIR} ..."
    rm -rf ${LOCAL_PROJECT_DIR}
    mkdir -p ${LOCAL_PROJECT_DIR}

    echo "[2/4] 克隆仓库 ${GIT_REPO} 分支 ${BRANCH} ..."
    if ! git clone -b ${BRANCH} --single-branch ${GIT_REPO} ${LOCAL_PROJECT_DIR}; then
        echo "错误：Git 克隆失败，请检查仓库地址和分支名"
        exit 1
    fi
    echo "Git 克隆完成"

    # 2. 推送到目标服务器
    HOST_COUNT=$(echo ${HOST_LIST} | wc -w)
    INDEX=0
    for HOST in ${HOST_LIST}; do
        INDEX=$((INDEX + 1))
        echo "[3/4][${INDEX}/${HOST_COUNT}] 部署到服务器 ${HOST} ..."

        # 删除旧软链接，创建新版本目录
        ssh root@${HOST} "rm -rf ${APP_PATH} && mkdir -p ${DATA_PATH}/${APP}-${DATE}"
        # 推送代码
        scp -r ${LOCAL_PROJECT_DIR}/* root@${HOST}:${DATA_PATH}/${APP}-${DATE}/
        # 建立新软链接
        ssh root@${HOST} "ln -sv ${DATA_PATH}/${APP}-${DATE} ${APP_PATH}"

        echo "服务器 ${HOST} 部署完成"
    done

    echo "[4/4] 全部部署完成！"
    echo "版本：${APP}-${DATE}"
    echo "分支：${BRANCH}"
}

# 回滚函数
rollback() {
    echo "开始回滚"

    HOST_COUNT=$(echo ${HOST_LIST} | wc -w)
    INDEX=0
    for HOST in ${HOST_LIST}; do
        INDEX=$((INDEX + 1))
        echo "[${INDEX}/${HOST_COUNT}] 回滚服务器 ${HOST} ..."

        # 获取当前版本
        CURRENT_VERSION=$(ssh root@${HOST} "readlink ${APP_PATH}" 2>/dev/null)
        CURRENT_VERSION=$(basename ${CURRENT_VERSION})
        echo "当前版本：${CURRENT_VERSION}"

        # 获取上一个版本
        PRE_VERSION=$(ssh root@${HOST} "ls -1 ${DATA_PATH} | grep -B1 ${CURRENT_VERSION} | head -n1")
        if [[ -z "${PRE_VERSION}" ]]; then
            echo "错误：服务器 ${HOST} 没有可回滚的更早版本"
            continue
        fi
        echo "回滚目标：${PRE_VERSION}"

        # 切换软链接
        ssh root@${HOST} "rm -f ${APP_PATH} && ln -sv ${DATA_PATH}/${PRE_VERSION} ${APP_PATH}"

        echo "服务器 ${HOST} 回滚完成"
    done

    echo "回滚操作完成"
}

# 入口
case $1 in
deploy)
    deploy $2
    ;;
rollback)
    if [[ -n "$2" ]]; then
        echo "提示：回滚操作不需要分支参数，忽略 \"$2\""
    fi
    rollback
    ;;
*)
    echo "用法："
    echo "  $0 deploy <分支名>    部署指定分支"
    echo "  $0 rollback           回滚到上一个版本"
    echo ""
    echo "示例："
    echo "  $0 deploy master"
    echo "  $0 deploy dev"
    exit 1
    ;;
esac
