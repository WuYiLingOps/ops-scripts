#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-01-23
#FileName:         install_gitlab.sh
#URL:              https://script.huangjingblog.cn
#Description:      自动化安装GitLab（适配CentOS/Rocky/Ubuntu）
#Copyright (C):    2026 All rights reserved
#********************************************************************

# 说明:安装GitLab 服务器内存建议至少4G,root密码至少8位
# 根据系统类型自动选择对应的GitLab安装包URL

# GitLab CE版本选择（根据系统类型取消注释）：
GITLAB_VERSION="17.3.1"   # ubuntu22.04/ubuntu24.04/centos9/rocky9 2026.7.20测试通过

# 已验证的URL示例：
# GITLAB_URL="https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/ubuntu/jammy/pool/main/g/gitlab-ce/gitlab-ce_17.3.1-ce.0_amd64.deb"
# GITLAB_URL="https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el9/Packages/g/gitlab-ce-17.3.1-ce.0.el9.x86_64.rpm"
#
# 注意事项：
# 1. el8目录已从清华源移除，请使用el9或el10
# 2. Ubuntu 22.04 codename为jammy，24.04为noble
# 3. 旧版本GitLab可能已从镜像源删除

# 清华源GitLab镜像URL（按系统类型分类）
# Ubuntu/Debian系列：
#   - jammy: Ubuntu 22.04 LTS
#   - noble: Ubuntu 24.04 LTS
# CentOS/RHEL系列：
#   - el7: CentOS/RHEL 7.x（直接在el7目录下）
#   - el9: CentOS/RHEL 9.x / Rocky 9.x（在Packages/g/子目录下）
#   - el10: CentOS/RHEL 10.x / Rocky 10.x（在Packages/g/子目录下）
#   - 注意：el8已从清华源移除，请使用el9或el10

# 根据系统类型自动设置GITLAB_URL
. /etc/os-release
case $ID in
    ubuntu|debian)
        # Ubuntu/Debian系统使用deb包
        # NOTE: 如果需要其他Ubuntu版本，请修改下方CODENAME变量
        CODENAME="${VERSION_CODENAME:-jammy}"
        GITLAB_URL="https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/ubuntu/${CODENAME}/pool/main/g/gitlab-ce/gitlab-ce_${GITLAB_VERSION}-ce.0_amd64.deb"
        ;;
    centos|rhel|rocky|almalinux)
        # CentOS/RHEL/Rocky系统使用rpm包
        # NOTE: 根据系统主版本号自动选择el7/el9/el10（el8已从清华源移除）
        MAJOR_VERSION=$(rpm -E %{rhel} 2>/dev/null || echo "9")

        # 不同el版本的URL路径格式不同
        if [ "$MAJOR_VERSION" -eq 7 ]; then
            # el7: rpm文件直接在el7目录下
            GITLAB_URL="https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/gitlab-ce-${GITLAB_VERSION}-ce.0.el7.x86_64.rpm"
        elif [ "$MAJOR_VERSION" -ge 9 ]; then
            # el9/el10: rpm文件在Packages/g/子目录下
            GITLAB_URL="https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el${MAJOR_VERSION}/Packages/g/gitlab-ce-${GITLAB_VERSION}-ce.0.el${MAJOR_VERSION}.x86_64.rpm"
        else
            echo "不支持的系统版本: el${MAJOR_VERSION}"
            echo "当前仅支持: el7, el9, el10"
            exit 1
        fi
        ;;
    *)
        echo "不支持的系统类型: $ID"
        echo "当前脚本仅支持: ubuntu, debian, centos, rhel, rocky, almalinux"
        exit 1
        ;;
esac

# 显示系统检测结果
echo "-------------------------------------------------------------------"
echo "系统检测: $ID $VERSION ($VERSION_CODENAME)"
echo "安装版本: GitLab CE $GITLAB_VERSION"
echo "安装包URL: $GITLAB_URL"
echo "-------------------------------------------------------------------"

# 验证URL是否可用
echo "验证安装包URL是否可用..."
if curl -sI "$GITLAB_URL" | grep -q "HTTP/2 200"; then
    echo "URL验证成功，安装包存在"
else
    echo "警告: 指定版本 $GITLAB_VERSION 在当前系统可能不可用"
    echo "请检查清华源是否提供此版本：https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/"
    echo "如需安装其他版本，请修改 GITLAB_VERSION 变量"
    echo "-------------------------------------------------------------------"
    exit 1
fi
echo "-------------------------------------------------------------------"

# 配置信息
GITLAB_ROOT_PASSWORD="huang@123456"  # 新版密码必须符合复杂性要求且至少8位
SMTP_PASSWORD="xxxxxxxxxxxxxx"
SMTP_USER="2794998160@qq.com"  # SMTP邮箱账号
SMTP_DOMAIN="qq.com"  # SMTP域名
GITLAB_EMAIL="2794998160@qq.com"  # GitLab发件邮箱
HOST="gitlab.huang.org"
# HOST=`hostname -I|awk '{print $1}'`

# 定义颜色输出变量
GREEN="echo -e \E[32;1m"
END="\E[0m"

# 定义自定义安装路径和相关配置
DOWNLOAD_DIR="/usr/local/src"
GITLAB_PACKAGE=$(basename $GITLAB_URL)
PACKAGE_PATH="$DOWNLOAD_DIR/$GITLAB_PACKAGE"

# 定义颜色输出函数（用于操作结果提示）
color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \033[1;32m"
    SETCOLOR_FAILURE="echo -en \033[1;31m"
    SETCOLOR_WARNING="echo -en \033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $" OK "    
    elif [ $2 = "failure" -o $2 = "1" ] ;then
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo
}

# 检查并创建下载目录
prepare_directory() {
    if [ ! -d "$DOWNLOAD_DIR" ]; then
        mkdir -p "$DOWNLOAD_DIR"
        if [ $? -eq 0 ]; then
            color "创建下载目录成功!" 0
        else
            color "创建下载目录失败!" 1
            exit
        fi
    else
        color "下载目录已存在，跳过创建!" 0
    fi
}

# 下载GitLab安装包
download_gitlab() {
    # 检查安装包是否已存在
    if [ -f "$PACKAGE_PATH" ]; then
        color "安装包 $GITLAB_PACKAGE 已存在，跳过下载!" 0
    else
        color "开始下载GitLab安装包..." 0
        wget -P "$DOWNLOAD_DIR" "$GITLAB_URL" || { color "下载失败!" 1 ;exit ; }
        if [ $? -eq 0 ]; then
            color "下载GitLab安装包成功!" 0
        else
            color "下载GitLab安装包失败!" 1
            exit
        fi
    fi
}

# 安装GitLab
install_gitlab() {
    color "开始安装GitLab..." 0
    
    if [ $ID = "centos" -o $ID = "rocky" -o $ID = "rhel" -o $ID = "almalinux" ]; then
        yum -y install "$PACKAGE_PATH"
    else
        dpkg -i "$PACKAGE_PATH"
    fi
    
    if [ $? -eq 0 ]; then
        color "安装GitLab完成!" 0
    else
        color "安装GitLab失败!" 1
        exit
    fi
}

# 配置GitLab
config_gitlab() {
    color "配置GitLab..." 0
    
    # 备份原配置文件
    cp /etc/gitlab/gitlab.rb /etc/gitlab/gitlab.rb.bak
    
    # 修改外部URL
    sed -i "/^external_url.*/c external_url 'http://$HOST'" /etc/gitlab/gitlab.rb
    
    # 添加SMTP和初始密码配置
    cat >> /etc/gitlab/gitlab.rb << EOF
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "smtp.qq.com"
gitlab_rails['smtp_port'] = 465
gitlab_rails['smtp_user_name'] = "$SMTP_USER"
gitlab_rails['smtp_password'] = "$SMTP_PASSWORD"
gitlab_rails['smtp_domain'] = "$SMTP_DOMAIN"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = false
gitlab_rails['smtp_tls'] = true
gitlab_rails['gitlab_email_from'] = "$GITLAB_EMAIL"
gitlab_rails['initial_root_password'] = "$GITLAB_ROOT_PASSWORD"

# 禁用Prometheus相关组件
prometheus['enable'] = false
prometheus['monitor_kubernetes'] = false
alertmanager['enable'] = false
node_exporter['enable'] = false
redis_exporter['enable'] = false
postgres_exporter['enable'] = false
gitlab_exporter['enable'] = false
prometheus_monitoring['enable'] = false
EOF
    
    color "重新配置GitLab..." 0
    gitlab-ctl reconfigure
    
    if [ $? -eq 0 ]; then
        color "GitLab重新配置成功!" 0
    else
        color "GitLab重新配置失败!" 1
        exit
    fi
}

# 验证GitLab状态
verify_gitlab() {
    color "验证GitLab状态..." 0
    
    # 等待服务启动
    MAX_WAIT=180
    WAIT_COUNT=0
    
    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        gitlab-ctl status | grep -q "run"
        if [ $? -eq 0 ]; then
            break
        fi
        sleep 10
        WAIT_COUNT=$((WAIT_COUNT + 10))
        color "等待GitLab服务启动... ($WAIT_COUNT/$MAX_WAIT秒)" 0
    done
    
    # 检查服务状态
    gitlab-ctl status
    if [ $? -eq 0 ]; then
        echo
        color "GitLab安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "访问链接: \c"
        ${GREEN}"http://$HOST/"${END}
        echo "-------------------------------------------------------------------"
        echo -e "默认账号: root"
        echo -e "默认密码: \c"
        ${GREEN}$GITLAB_ROOT_PASSWORD${END}
        echo "-------------------------------------------------------------------"
    else
        color "GitLab启动失败!" 1
        exit
    fi
}

# 清理临时文件
cleanup() {
    color "清理临时文件..." 0
    rm -f "$PACKAGE_PATH"
    if [ $? -eq 0 ]; then
        color "清理临时文件成功!" 0
    else
        color "清理临时文件失败!" 1
    fi
}

# 执行安装流程
prepare_directory
download_gitlab
install_gitlab
config_gitlab
verify_gitlab
#cleanup

echo
echo "-------------------------------------------------------------------"
echo "GitLab安装信息:"
echo "系统类型: $ID ($VERSION)"
echo "安装版本: $GITLAB_VERSION"
echo "安装包URL: $GITLAB_URL"
echo "访问地址: http://$HOST/"
echo "默认账号: root"
echo "默认密码: $GITLAB_ROOT_PASSWORD"
echo "-------------------------------------------------------------------"
echo "注意事项:"
echo "1. GitLab服务启动可能需要几分钟时间，请耐心等待"
echo "2. 首次登录后请立即修改默认密码以确保安全"
echo "3. 如需修改GitLab配置，请编辑 /etc/gitlab/gitlab.rb"
echo "4. 修改配置后需执行: gitlab-ctl reconfigure"
echo "-------------------------------------------------------------------"
color "GitLab自动化安装脚本执行完成!" 0