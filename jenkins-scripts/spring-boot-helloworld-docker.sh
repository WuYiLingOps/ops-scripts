#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-08-18 21:29:15
#FileName:         spring-boot-helloworld-docker.sh
#URL:              https://script.huangjingblog.cn
#Description:      jenkins docker 脚本 
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP=spring-boot-helloworld
REPO=example
HARBOR=harbor.huang.org
USER=admin
PASSWD=123456
HOST_LIST="
10.0.0.112
10.0.0.113
"
PORT=80

mvn clean package -Dmaven.test.skip=true
docker build -t $HARBOR/$REPO/$APP:$BUILD_NUMBER .
docker login -u $USER -p $PASSWD $HARBOR
docker push $HARBOR/$REPO/$APP:$BUILD_NUMBER

for host in $HOST_LIST; do
    #ssh root@$host "docker rm -f $APP && docker run -d $APP --restart always --name -p $PORT:80 $HARBOR/$REPO/$APP:$BUILD_NUMBER"
    #docker -H $host rm -f $APP && docker -H $host run -d name $APP --restart always -- -p $PORT:80 $HARBOR/$REPO/$APP:$BUILD_NUMBER
    docker -H ssh://root@$host rm -f $APP && docker -H ssh://root@$host run -d \
        --restart always \
        --name $APP \
        -p $PORT:80 \
        $HARBOR/$REPO/$APP:$BUILD_NUMBER
done
