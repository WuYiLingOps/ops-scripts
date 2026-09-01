#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2023-12-23
#FileName:         ubuntu_install_docker_apt.bash
#URL:              https://script.huangjingblog.cn
#Description:      Ubuntu环境下使用APT包管理器在线安装Docker，支持删除旧版本、配置阿里云镜像源加速
#Copyright (C):    2024 All rights reserved
#********************************************************************
#

# 删除旧版本 Docker
remove_old_versions() {
  echo "--------------------------------------------"
  echo "1. 删除旧版本 Docker"
  echo "--------------------------------------------"
  sudo apt-get remove docker docker.io containerd runc -y
}

# 安装所需工具
install_dependencies() {
  echo "--------------------------------------------"
  echo "2. 安装所需工具"
  echo "--------------------------------------------"
  sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y
}

# 增加 Docker 官方 GPG 密钥
add_docker_gpg_key() {
  echo "--------------------------------------------"
  echo "3. 增加 Docker 官方 GPG 密钥"
  echo "--------------------------------------------"
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
}

# 配置 Docker 软件源
configure_docker_repository() {
  echo "--------------------------------------------"
  echo "4. 配置 Docker 软件源信息"
  echo "--------------------------------------------"
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
}

# 更新源列表
update_sources() {
  echo "--------------------------------------------"
  echo "5. 更新源列表"
  echo "--------------------------------------------"
  sudo apt-get update
}

# 安装 Docker
install_docker() {
  echo "--------------------------------------------"
  echo "6. 安装 Docker"
  echo "--------------------------------------------"
  sudo apt-get install docker-ce docker-ce-cli containerd.io -y
}

# 配置 Docker 镜像加速
configure_registry_mirrors() {
  echo "--------------------------------------------"
  echo "7. 配置 Docker 镜像加速"
  echo "--------------------------------------------"
  sudo mkdir -p /etc/docker
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
  sudo systemctl restart docker
}

# 验证 Docker 安装
verify_docker_installation() {
  echo "--------------------------------------------"
  echo "8. 验证 Docker 安装"
  echo "--------------------------------------------"
  docker --version
  if [ $? -eq 0 ]; then
    echo "Docker 安装成功！"
  else
    echo "Docker 安装失败，请检查脚本执行过程中的错误信息。"
  fi
}

# 主函数
main() {
  remove_old_versions
  install_dependencies
  add_docker_gpg_key
  configure_docker_repository
  update_sources
  install_docker
  configure_registry_mirrors
  verify_docker_installation
}

# 执行主函数
main
