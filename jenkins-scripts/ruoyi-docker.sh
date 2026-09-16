#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-08-18 21:33:32
#FileName:         ruoyi-docker.sh
#URL:              https://script.huangjingblog.cn
#Description:      jenkins ruoyi docker 
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP=ruoyi
HARBOR=harbor.huang.org
REPO=example
PORT=80
USER=admin
PASSWD=123456
HOST_LIST="
10.0.0.112
10.0.0.113
"

mvn clean package -Dmaven.test.skip=true
docker build -t $HARBOR/$REPO/$APP:$TAG .
docker login $HARBOR -u $USER -p $PASSWD
docker push $HARBOR/$REPO/$APP:$TAG

for host in $HOST_LIST; do
    #方法1：
    #ssh root@$host "docker rm -f $APP && docker run -d $APP --restart always --name -p $PORT:80 $HARBOR/$REPO/$APP:$TAG"
    #方法2:事先配置jenkins到后端服务器ssh key验证，安全性高
    docker -H ssh://root@$host rm -f $APP
    docker -H ssh://root@$host run -d \
        --restart always --name $APP \
        -p $PORT:80 \
        $HARBOR/$REPO/$APP:$TAG
    #方法3：事先配置docker后端服务器的端口打开2375/tcp,但是无需验证就可以访问，安全性差
    #docker -H $host rm -f $APP
    #docker -H $host run -d \
    #    --restart always \
    #    --name $APP \
    #    -p $PORT:80 \
    #    $HARBOR/$REPO/$APP:$TAG
done
