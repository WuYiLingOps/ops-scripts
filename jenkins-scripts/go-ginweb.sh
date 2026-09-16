#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-05 18:53:37
#FileName:         go-ginweb.sh
#URL:              https://script.huangjingblog.cn
#Description:      ginweb 项目示例
#Copyright (C):    2026 All rights reserved
#********************************************************************
set -eo pipefail
APP=ginweb
APP_PATH=/opt
DATE=`date +%F_%H-%M-%S`
# 定义go二进制绝对路径，后续修改只改这一处
GO_BIN=/root/.g/go/bin/go
HOST_LIST="
10.0.0.112
10.0.0.113
"

build () {
    #go env 可以查看到下面变量信息，如下环境变量不支持相对路径，只支持绝对路径
    #go env -w GOPROXY=https://goproxy.cn,direct
    #export GOPROXY="https://goproxy.cn,direct"
    export GOPROXY="http://nexus.huang.org/repository/go-group/,direct"
    CGO_ENABLED=0 ${GO_BIN} build -o ${APP}
}

deloy () {
    for host in $HOST_LIST;do
        ssh root@$host "mkdir -p $APP_PATH/${APP}-${DATE}"
        scp -r * root@$host:$APP_PATH/${APP}-${DATE}/
        #必须进入项目目录使用相对路径才能运行
        ssh root@$host "killall -0 ${APP} &> /dev/null && killall -9 ${APP}; rm -f ${APP_PATH}/${APP} && \
ln -s ${APP_PATH}/${APP}-${DATE} ${APP_PATH}/${APP}; \
cd ${APP_PATH}/${APP}/ && nohup ./${APP}&>/dev/null" &
    done
}

build
deloy
