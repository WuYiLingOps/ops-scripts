#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2023-12-23
#FileName:         centos_install_docker_yum.bash
#URL:              https://script.huangjingblog.cn
#Description:      CentOS/Rocky环境下使用YUM包管理器在线安装Docker
#Copyright (C):    2024 All rights reserved
#********************************************************************
#

#卸载旧版Docker
remove_old_version(){
sudo yum remove docker \
docker-client \
docker-client-latest \
docker-common \
docker-latest \
docker-latest-logrotate \
docker-logrotate \
docker-engine
}

#阿里的镜像仓库
use_aliyun_images(){
yum install -y yum-utils
yum-config-manager \
    --add-repo \
    http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
}

#依赖安装,docker安装
yum_update_install(){
yum install docker-ce docker-ce-cli containerd.io -y
}

#配置镜像加速
aliyun_speed_up(){
mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerproxy.com",
    "https://mirror.iscas.ac.cn",
    "https://huecker.io",
    "https://dockerhub.timeweb.cloud",
    "https://docker.imgdb.de",
    "https://docker-0.unsee.tech",
    "https://docker.hlmirror.com",
    "https://docker.1ms.run",
    "https://lispy.org"
  ]
}
EOF
#启动服务
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
docker info | grep aliyuncs.com >/dev/null
if [ $? -eq 0 ];then
  echo -e "\033[32m>>docker配置完成 \033[0m"
fi
}

main(){
remove_old_version
use_aliyun_images
yum_update_install
aliyun_speed_up
}

#调用
main
