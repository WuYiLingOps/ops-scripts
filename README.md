# 运维脚本集合

> 个人运维脚本库，包含系统初始化、软件安装、服务管理、大数据环境配置等各类脚本

## 📁 目录结构

### 根目录脚本分类

- [系统初始化脚本 (system_init/)](system_init/)
  - AnolisOS/CentOS/Ubuntu 系统初始化
  - YUM源配置
  - 主机名和IP地址配置
  - 网络配置脚本

- [Docker工具脚本 (docker_tools/)](docker_tools/)
  - Docker镜像清理
  - 镜像推送工具
  - 自动补全配置

- [系统管理脚本 (system_manage/)](system_manage/)
  - 用户管理
  - SSH密钥分发
  - SSH批量执行
  - SSH版本升级

- [服务管理脚本 (service_manage/)](service_manage/)
  - FTP服务
  - Logstash服务
  - MySQL备份
  - Nginx SSL证书

- [开发工具脚本 (dev_tools/)](dev_tools/)
  - 代理切换工具
  - SSH密钥生成与分发

- [软件安装脚本 (InstallSoftScript/)](InstallSoftScript/)
  - [MySQL安装脚本](#mysql安装脚本)
  - [Docker安装脚本](#docker安装脚本)
  - [Kubernetes安装脚本](#kubernetes安装脚本)
  - [Redis安装脚本](#redis安装脚本)
  - [大数据组件安装脚本](#大数据组件安装脚本)
  - [Web服务安装脚本](#web服务安装脚本)
  - [开发工具安装脚本](#开发工具安装脚本)
  - [其他服务安装脚本](#其他服务安装脚本)

- [大数据脚本 (BigDataScript/)](BigDataScript/)
  - Hadoop/Hive/Kafka/Zookeeper 集群管理
  - 容器创建和管理

- [大数据Docker配置 (BigdDataDockerConf/)](BigdDataDockerConf/)
  - Dockerfile集合
  - Hadoop/Hive配置文件

- [Dockerfile仓库 (DockerfileRepo/)](DockerfileRepo/)
  - 各类Docker镜像构建文件

---

## 📋 详细说明

### 系统初始化脚本

**目录：** [`system_init/`](system_init/)

包含系统初始化和网络配置相关脚本。

| 脚本文件 | 说明 |
|---------|------|
| `anolisOS_initialization.bash` | AnolisOS虚拟机初始化脚本 |
| `centos_initialization.bash` | CentOS虚拟机初始化脚本 |
| `centos_yum.bash` | CentOS环境YUM源配置 |
| `anolisOS_change-hostname-ip.bash` | AnolisOS模板机快速修改主机名和IP |
| `centos_change-hostname-ip.bash` | CentOS模板机快速修改主机名和IP |
| `ubuntu_change-hostname-ip.bash` | Ubuntu模板机快速修改主机名和IP |

### Docker工具脚本

**目录：** [`docker_tools/`](docker_tools/)

| 脚本文件 | 说明 |
|---------|------|
| `docker_clean_tool.bash` | Docker镜像清理工具 |
| `docker-push-aliyun.bash` | 将本地Docker镜像上传至阿里云镜像仓库 |
| `docker-自动补全.bash` | 配置Docker自动补全 |

### 系统管理脚本

**目录：** [`system_manage/`](system_manage/)

| 脚本文件 | 说明 |
|---------|------|
| `del_user.bash` | 删除指定用户，可选择是否清除用户数据 |
| `fenfa.bash` | 一键自动化创建和分发SSH公钥 |
| `ssh_check.bash` | 通过SSH批量在多台服务器上执行命令 |
| `ssh7.4_update_ssh8.9.bash` | CentOS下更新SSH 7.4到SSH 8.9 |

### 服务管理脚本

**目录：** [`service_manage/`](service_manage/)

| 脚本文件 | 说明 |
|---------|------|
| `ftp_intall_new.bash` | 一键安装FTP并修改用户上传文件目录 |
| `logstash-system.bash` | Logstash启动脚本 |
| `mysql_mysqldump_Databak.bash` | MySQL数据备份脚本 |
| `nginx_create_local_SSL.bash` | Nginx自签证书生成（仅限于测试环境） |

### 开发工具脚本

**目录：** [`dev_tools/`](dev_tools/)

| 脚本文件 | 说明 |
|---------|------|
| `clash.sh` | 代理切换脚本，支持start|stop|status，适用于WSL场景 |
| `ssh-keygen-automated.sh` | 免交互SSH密钥生成与分发脚本（生产环境慎用） |

### 软件安装脚本

**目录：** [`InstallSoftScript/`](InstallSoftScript/)

#### MySQL安装脚本

**目录：** [`InstallSoftScript/mysql/`](InstallSoftScript/mysql/)

| 脚本文件 | 说明 |
|---------|------|
| `install_mysql5_7.bash` | CentOS下安装MySQL5.7，可选择安装方式 |
| `install_mysql5_7_bin.bash` | CentOS下二进制安装MySQL5.7 |
| `install_mysql5_7_Multi-instance.bash` | CentOS下二进制安装MySQL5.7并实现多实例 |
| `install_mysql8_0_bin.bash` | CentOS下二进制安装MySQL8.0 |
| `install_mysql8_0_Multi-instance.bash` | CentOS下源码编译安装MySQL8.0并实现多实例 |
| `install_compile_make_mysql5_7.bash` | 源码编译安装MySQL5.7（编译时间过长，谨慎选择） |
| `install_compile_make_mysql8_0.bash` | 源码编译安装MySQL8.0（编译时间过久，谨慎选择） |
| `install_MGR.bash` | CentOS下安装MGR单组集群 |
| `update_gcc_cmake_install_MYSQL8.bash` | CentOS下更新GCC并源码编译安装MySQL8.0 |

#### Docker安装脚本

**目录：** [`InstallSoftScript/docker/`](InstallSoftScript/docker/)

| 脚本文件 | 说明 |
|---------|------|
| `install_docker.bash` | 自动识别系统类型(CentOS/Ubuntu)并使用对应包管理器(YUM/APT)在线安装Docker，支持版本选择、镜像加速配置 |
| `centos_install_docker_yum.bash` | CentOS/Rocky环境下使用YUM包管理器在线安装Docker |
| `centos_install_docker_bin.bash` | CentOS环境下二进制方式安装Docker，支持自定义数据存储目录 |
| `ubuntu_install_docker_apt.bash` | Ubuntu环境下使用APT包管理器在线安装Docker，支持删除旧版本、配置阿里云镜像源加速 |
| `ubuntu_install_docker_bin.bash` | Ubuntu环境下简易二进制安装Docker |
| `install_harbor.bash` | Ubuntu / CentOS 下安装harbor |

#### Kubernetes安装脚本

**目录：** [`InstallSoftScript/kubernetes/`](InstallSoftScript/kubernetes/)

| 脚本文件 | 说明 |
|---------|------|
| `install_kubernetes_docker.sh` | 基于kubeadm + docker方式实现Kubernetes的初始准备到安装的全过程 |
| `install_kubernetes_containerd.sh` | 基于kubeadm + Containerd方式实现Kubernetes的初始准备到安装的全过程 |

#### Redis安装脚本

**目录：** [`InstallSoftScript/redis/`](InstallSoftScript/redis/)

| 脚本文件 | 说明 |
|---------|------|
| `install_redis.bash` | CentOS下编译安装Redis并完成基础配置 |
| `install_redis_cluster.bash` | CentOS环境下安装Redis集群 |

#### 大数据组件安装脚本

**目录：** [`InstallSoftScript/bigdata/`](InstallSoftScript/bigdata/)

| 脚本文件 | 说明 |
|---------|------|
| `install_and_run_spark.bash` | 自动化安装和配置Spark，支持添加环境变量、配置YARN提交任务等 |
| `install_kafka_zookeeper_bin.bash` | CentOS下部署Zookeeper和Kafka集群 |
| `install_clickhouse.bash` | 安装ClickHouse |

#### Web服务安装脚本

**目录：** [`InstallSoftScript/web/`](InstallSoftScript/web/)

| 脚本文件 | 说明 |
|---------|------|
| `install_nginx_universal.bash` | 通用Nginx编译安装脚本，自动识别CentOS/Ubuntu系统 |
| `install_php_yum.bash` | CentOS下使用YUM安装PHP 8.2版本 |
| `install_php83.bash` | 安装PHP 8.3版本 |

#### 开发工具安装脚本

**目录：** [`InstallSoftScript/devtools/`](InstallSoftScript/devtools/)

| 脚本文件 | 说明 |
|---------|------|
| `install_jdk_bin.bash` | CentOS下安装JDK脚本 |
| `install_nvm.bash` | 安装NVM（Node Version Manager），源码来自GitHub NVM官网 |
| `install_nvm_node.bash` | 检查本地是否存在NVM，并使用NVM安装Node18，并配置淘宝源 |
| `install_python3.bash` | CentOS下使用YUM简易安装Python3 |
| `install_golang.sh` | 自动化安装Go语言环境，支持下载、解压、配置环境变量并验证安装 |

#### 其他服务安装脚本

**目录：** [`InstallSoftScript/others/`](InstallSoftScript/others/)

| 脚本文件 | 说明 |
|---------|------|
| `install_gitlab.sh` | 自动化安装GitLab（适配CentOS/Rocky/Ubuntu） |
| `install_jenkins.sh` | 自动化安装Jenkins（适配CentOS/Rocky/Ubuntu） |
| `install_mongodb.bash` | CentOS下安装MongoDB |
| `install_nexus.sh` | 自动化安装Nexus（适配CentOS/Rocky/Ubuntu） |
| `install-zabbix-agent2.bash` | CentOS环境下安装Zabbix Agent2客户端 |

### 大数据脚本

**目录：** [`BigDataScript/`](BigDataScript/)

| 脚本文件 | 说明 |
|---------|------|
| `create_bigdatamaster_and_bigdataSlave.bash` | 根据创建的基础镜像创建容器 |
| `hiveservices.bash` | HiveServer2和HiveMetastore服务管理脚本 |
| `jpsall` | 查看集群所有节点的Java进程信息 |
| `kafka.bash` | Kafka集群管理脚本，支持启动、停止操作 |
| `ssh-key_scp.bash` | 在所有节点运行此脚本，实现免密登录 |
| `start_flume_conf.bash` | 传参以配置文件启动Flume |
| `zk.bash` | Zookeeper集群管理脚本，支持启动、停止、查看状态 |

### 大数据Docker配置

**目录：** [`BigdDataDockerConf/`](BigdDataDockerConf/)

包含大数据环境的Docker配置文件和Dockerfile：
- `Dockerfile/` - Docker镜像构建文件
- `hadoop_conf/` - Hadoop配置文件
- `hive_conf/` - Hive配置文件
- `hive_lib/` - Hive依赖库
- `start_docker_hadoop.bash` - 启动Docker Hadoop环境脚本

### Dockerfile仓库

**目录：** [`DockerfileRepo/`](DockerfileRepo/)

包含各类Docker镜像的Dockerfile：
- `Dockerfile_hadoop` - Hadoop环境镜像
- `Dockerfile_hive` - Hive环境镜像
- `Dockerfile_sshjdk` - SSH和JDK基础环境镜像
- `Dockerfile_bigdata_ubuntu_master` - 大数据Master节点镜像
- `Dockerfile_bigdata_ubuntu_slave` - 大数据Slave节点镜像

---

## 🚀 使用说明

### 脚本执行前准备

1. **检查脚本格式**
   ```bash
   # 安装dos2unix工具
   yum install dos2unix -y
   
   # 转换脚本格式（Windows环境下）
   dos2unix script_name.bash
   ```

2. **添加执行权限**
   ```bash
   chmod +x script_name.bash
   ```

3. **查看脚本使用说明**
   ```bash
   # 查看脚本头部注释
   head -20 script_name.bash
   ```

### 脚本执行示例

```bash
# 系统初始化
bash system_init/centos_initialization.bash

# 安装MySQL
bash InstallSoftScript/mysql/install_mysql8_0_bin.bash

# 管理Hive服务
bash BigDataScript/hiveservices.bash start
```

---

## ⚙️ Git配置

### 1. Git全局配置

```sh
$ git config --global user.name 'huangjing'

$ git config --global user.email '2794998160@qq.com'

$ git config --global color.ui true

$ git config --global --list
user.name=17758619389
user.email=2794998160@qq.com
color.ui=true
```

### 2. 添加仓库

```sh
#gitee
$ git remote add gitee https://gitee.com/master_hj/openstack_-study_-notes.git

#github
git remote add github git@github.com:wuyiling55kai/openstack_-study_-notes.git

#查看仓库情况
$ git remote -v
gitee   https://gitee.com/master_hj/openstack_-study_-notes.git (fetch)
gitee   https://gitee.com/master_hj/openstack_-study_-notes.git (push)
github  git@github.com:wuyiling55kai/openstack_-study_-notes.git (fetch)
github  git@github.com:wuyiling55kai/openstack_-study_-notes.git (push)
```

### 3. 生成公钥私钥

```sh
$ ssh-keygen.exe
Generating public/private rsa key pair.
Enter file in which to save the key (/c/Users/hj/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /c/Users/hj/.ssh/id_rsa
Your public key has been saved in /c/Users/hj/.ssh/id_rsa.pub
The key fingerprint is:
SHA256:e1leq19dfTn+CkbSJ0JHcc5P41SahOQGLReXQruMtFk hj@DESKTOP-TP96LAR
```

### 4. 查看是否创建成功

```sh
$ ls ~/.ssh/
id_rsa  id_rsa.pub  known_hosts  known_hosts.old
```

### 5. 查看公钥

```sh
$ cat ~/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDxr8bAvg3vz6CCOfZmbKxwqieAr5LLVgv2RTXw3PNuEotOE0IGcWsJafLA6IFoJzT1KqhpMJbxu6WK4BPX6YSEwvi6NfCi0aEJkinK1igcetlNG9peCTNCNXO2bAGRL2dB/Duu7uXUgHakmmCT4HrbJpUxA84GHKS0eQ66ORQgK+Wokek5A+iGrZ40GidxyKy/+OOXYZ6
```

### 6. Shell格式转换

```sh
yum install dos2unix -y
dos2unix install_MYSQL.sh
```

---

## 📝 注意事项

1. **脚本执行权限**：执行前请确保脚本有执行权限
2. **环境检查**：部分脚本需要特定环境，请先查看脚本注释说明
3. **备份数据**：涉及数据操作的脚本，建议先备份重要数据
4. **测试环境**：建议先在测试环境验证脚本功能
5. **脚本格式**：Windows环境下编辑的脚本可能需要使用 `dos2unix` 转换格式

---

## 📧 联系方式

- **作者：** YiLing Wu (hj)
- **邮箱：** huangjing510@126.com
- **URL：** https://script.huangjingblog.cn/

---

## 📄 版权信息

Copyright (C) 2026 All rights reserved
