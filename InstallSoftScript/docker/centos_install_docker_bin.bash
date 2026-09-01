#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2023-12-23
#FileName:         centos_install_docker_bin.bash
#URL:              https://script.huangjingblog.cn
#Description:      CentOS环境下二进制方式安装Docker，支持自定义数据存储目录
#Copyright (C):    2024 All rights reserved
#********************************************************************
#

# 生产环境采用二进制部署
# docker 数据存储至额外盘,不存放在系统盘

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

#依赖安装,docker安装
tar_update_install(){
if [ -f "./docker-20.10.18.tgz" ];then
  tar -xf docker-20.10.18.tgz
  cp docker/* /usr/bin
else
  yum install git -y >/dev/null
  git clone https://gitee.com/master_hj/docker-binary-deployment.git
  tar -xf ./docker-binary-deployment/docker-20.10.18.tgz
  cp docker/* /usr/bin
fi
if [ $? -eq 0 ];then
  rm -rf ./docker
fi
}

docker_system(){
#添加新硬盘,脚本自动格式化硬盘作为docker的数据存储目录
read -p "是否配置docker数据存储目录(需要手动添加新硬盘)(y/n)" yn
if [[ $yn == "n" ]];then
cat >/etc/systemd/system/docker.service<<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
elif [[ $yn == "y" ]];then
  read -p "请输入存放路径:" dirhome
  mkdir -p $dirhome
  #动态热插拔
  echo "- - -" > /sys/class/scsi_host/host0/scan
  echo "- - -" > /sys/class/scsi_host/host1/scan
  echo "- - -" > /sys/class/scsi_host/host2/scan
  if [ -b "/dev/sdb" ];then
    echo -e "\033[32m>>请输入\"y\"确定磁盘格式化: \033[0m"
    mkfs.ext4 /dev/sdb
    mount /dev/sdb $dirhome
    #开机自动挂载
    cat >>/root/.bashrc<<EOF
df -h | grep sdb >/dev/null
if [ $? -ne 0 ];then
  mount /dev/sdb $dirhome
fi
EOF
else
  echo -e "\033[32m>>未添加新硬盘,请检查配置!!\033[0m"
  fi
  if [ $? -eq 0 ];then
cat >/etc/systemd/system/docker.service<<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --graph=$dirhome
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF
  fi
fi
#关闭警告
#WARNING: bridge-nf-call-iptables is disabled
#WARNING: bridge-nf-call-ip6tables is disabled
cat >>/etc/sysctl.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl -p
echo "net.ipv4.ip_forward=1" >>/usr/lib/sysctl.d/00-system.conf
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
systemctl daemon-reload
systemctl restart docker
systemctl enable docker
systemctl restart network
docker info | grep aliyuncs.com >/dev/null
if [ $? -eq 0 ];then
  echo -e "\033[32m>>docker配置完成 \033[0m"
fi
}

main(){
remove_old_version
tar_update_install
docker_system
aliyun_speed_up
}

#调用
main
