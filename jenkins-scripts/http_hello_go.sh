#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-05 18:57:48
#FileName:         http_hello_go.sh
#URL:              https://script.huangjingblog.cn
#Description:      http_demo项目示例
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP=http_server_demo
APP_PATH=/data
DATE=$(date +%F_%H-%M-%S)
HOST_LIST="
10.0.0.112
10.0.0.113
"

build () {
    #go env 可以查看到下面变量信息
    export GOCACHE="/root/.cache/go-build"
    export GOPATH="/root/go"
    export GOPROXY="https://goproxy.cn,direct"
    CGO_ENABLED=0 go build -o "${APP}"
}

deploy () {
    for host in $HOST_LIST; do
        ssh "${host}" "mkdir -p ${APP_PATH}/${APP}-${DATE}"
        scp hello.html "${APP}" "${host}:${APP_PATH}/${APP}-${DATE}/"
        ssh "${host}" "killall -0 ${APP} &>/dev/null && killall -9 ${APP}; rm -f ${APP_PATH}/${APP} && \
ln -s ${APP_PATH}/${APP}-${DATE} ${APP_PATH}/${APP}; \
cd ${APP_PATH}/${APP}/ && nohup ./${APP} &>/dev/null &" &
    done
}

build
deploy
