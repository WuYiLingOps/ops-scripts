#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-10 12:28:22
#FileName:         docker_image_export.sh
#URL:              https://script.huangjingblog.cn
#Description:      Docker镜像导出与远程传输工具
#                   功能说明：
#                   1. 列出所有Docker镜像，按顺序编号显示
#                   2. 支持单个/范围/混合选择镜像编号（如：1 或 1-3 或 1,2-4）
#                   3. 导出选中镜像为tar.gz压缩包，存储到指定目录
#                   4. 支持跳过远程传输，仅导出到本地
#                   5. 通过rsync安全传输镜像到远程服务器
#                   6. 远程服务器自动执行docker load导入镜像
#Copyright (C):    2026 All rights reserved
#********************************************************************

echo_log_info() {
    echo -e "$(date +'%F %T') - [\033[32mInfo\033[0m] $*"
}
echo_log_warn() {
    echo -e "$(date +'%F %T') - [\033[33mWarn\033[0m] $*"
}
echo_log_error() {
    echo -e "$(date +'%F %T') - [\033[31mError\033[0m] $*"
    exit 1
}

# 打印分隔线
print_separator() {
    echo -e "\033[36m================================================================\033[0m"
}

# 打印标题
print_title() {
    echo -e "\033[36m================================================================\033[0m"
    echo -e "\033[36m          Docker 镜像导出与远程传输工具\033[0m"
    echo -e "\033[36m================================================================\033[0m"
}

# 检测系统类型和包管理器
check_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        os_name="${ID}"
        os_version="${VERSION_ID}"
        os_desc="${PRETTY_NAME}"
    else
        echo_log_error "\033[31m无法检测系统类型，缺少 /etc/os-release 文件\033[0m"
    fi

    if command -v apt &> /dev/null; then
        pkg_manager="apt"
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
    else
        pkg_manager="unknown"
    fi

    echo_log_info "当前系统: \033[36m${os_desc}\033[0m"
    echo_log_info "包管理器: \033[36m${pkg_manager}\033[0m"
    echo_log_info "导出目录: \033[36m${docker_dir}\033[0m"
}

docker_dir="$(pwd)/docker_images"

# 自动创建导出目录
mkdir -p "${docker_dir}" || echo_log_error "\033[31m无法创建导出目录 ${docker_dir}，请检查权限\033[0m"

check_packet() {
    if ! command -v sshpass &> /dev/null; then
        echo_log_warn "sshpass 未安装，准备安装 sshpass..."
        case "$pkg_manager" in
            apt) apt-get -y install sshpass >/dev/null 2>&1 ;;
            yum) yum -y install sshpass >/dev/null 2>&1 ;;
            dnf) dnf -y install sshpass >/dev/null 2>&1 ;;
            *) echo_log_error "\033[31m不支持的包管理器，请手动安装 sshpass\033[0m" ;;
        esac
        [ $? -eq 0 ] || echo_log_error "\033[31msshpass 安装失败！\033[0m"
        echo_log_info "sshpass 安装成功"
    fi

    if ! command -v rsync &> /dev/null; then
        echo_log_warn "rsync 未安装，准备安装 rsync..."
        case "$pkg_manager" in
            apt) apt-get -y install rsync >/dev/null 2>&1 ;;
            yum) yum -y install rsync >/dev/null 2>&1 ;;
            dnf) dnf -y install rsync >/dev/null 2>&1 ;;
            *) echo_log_error "\033[31m不支持的包管理器，请手动安装 rsync\033[0m" ;;
        esac
        [ $? -eq 0 ] || echo_log_error "\033[31mrsync 安装失败！\033[0m"
        echo_log_info "rsync 安装成功"
    fi
}

list_images() {
    echo ""
    echo -e "\033[36m可用的 Docker 镜像：\033[0m"
    echo ""
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}" | tail -n +2 | nl
}

# 导出镜像
export_image() {
    list_images
    echo ""
    while :; do
        read -rp "请输入要导出的镜像编号(例：1 或 1-3 或 1,2-4): " image_number
        if [ -z $image_number ]; then
            echo_log_warn "镜像编号不能为空,请重新输入！"
            continue
        fi

        local flag=0
        local image_number_array=()
        local image_name_array=()

        IFS=',' read -r -a ranges <<< "$image_number"

        for range in "${ranges[@]}"; do
            if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                start=${BASH_REMATCH[1]}  # 匹配的起始数字
                end=${BASH_REMATCH[2]}    # 匹配的结束数字

                # 将范围内的数字加入数组
                for ((i=start; i<=end; i++)); do
                    image_number_array+=("$i")
                done
            elif [[ "$range" =~ ^[0-9]+$ ]]; then
                image_number_array+=("$range")
            else
                echo_log_warn "镜像编号格式有误,请重新输入！"
                flag=1
                break
            fi
        done

        if [ $flag -eq 0 ]; then
            for num in "${image_number_array[@]}"; do
                image_name=$(docker images --format "{{.Repository}}:{{.Tag}}" | sed -n "${num}p")
                if [ -z $image_name ]; then
                    echo_log_warn "镜像编号不在范围内,请重新输入！"
                    flag=1
                    break
                fi
                image_name_array+=("$image_name")
            done
        fi

        [ $flag -eq 0 ] && break
    done

    [ ! -w "$docker_dir" ] && echo_log_error "\033[31m当前目录不可写，请检查权限或切换目录\033[0m"

    sanitized_image_name_array=()   # 作为全局，为后续使用

    echo ""
    echo_log_info "\033[34m>>> 1. 开始导出镜像...\033[0m"
    for image_name_array in "${image_name_array[@]}"; do
        # 镜像名的/和:替换成下划线
        sanitized_image_name=$(echo "$image_name_array" | tr '/' '_' | tr ':' '_')
        sanitized_image_name_array+=("$sanitized_image_name")
        
        answer=""
        
        echo_log_info "导出镜像 \033[33m$image_name_array\033[0m..."
        if [ -f "${docker_dir}/${sanitized_image_name}.tar.gz" ]; then
            while [[ "$answer" != "y" && "$answer" != "n" ]]; do
                echo -e -n "$(date +'%F %T') - [\033[33mWarn\033[0m] 镜像文件已存在，是否重新导出？(y/n) "
                read -r answer
            done
            [[ $answer == "n" ]] && continue || rm -f ${docker_dir}/${sanitized_image_name}.tar.gz
        fi

        docker save "$image_name_array" | gzip > "${docker_dir}/${sanitized_image_name}.tar.gz"
        [ $? -ne 0 ] && echo_log_error "\033[31m镜像导出失败，请检查异常！\033[0m"
        echo_log_info "导出成功: \033[36m${docker_dir}/${sanitized_image_name}.tar.gz\033[0m"
        
        
    done
}

# 传输镜像文件到远程服务器
copy_image_to_remote() {
    local ipzz="^([0-9]\.|[1-9][0-9]\.|1[0-9][0-9]\.|2[0-4][0-9]\.|25[0-5]\.){3}([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-4])$"

    echo && check_packet

    echo && while :; do
        read -rp "请输入远程服务器的 IP 地址(直接回车跳过): " remote_ip
        if [ -z "$remote_ip" ]; then
            echo_log_info "已跳过远程传输，镜像已保存到本地目录: ${docker_dir}"
            return 1
        elif [[  $remote_ip =~ $ipzz ]]; then
            break
        else
            echo_log_warn "IP 地址格式错误，请重新输入！"
        fi
    done

    remote_user=$(read -rp "请输入远程服务器的用户名: " && echo $REPLY)
    remote_passwd=$(read -rsp "请输入远程服务器的密码: " && echo $REPLY)
    echo   # 这个 echo 用于强制换行

    echo ""
    echo_log_info "\033[34m>>> 2. 开始传输镜像文件...\033[0m"

    for sanitized_image_name_array in "${sanitized_image_name_array[@]}"; do
        echo_log_info "传输镜像文件 \033[33m${sanitized_image_name_array}.tar.gz\033[0m..."

        # 用 rsync 显示进度条
        sshpass -p "${remote_passwd}" rsync -e 'ssh -o StrictHostKeyChecking=no' -avz --progress "${docker_dir}/${sanitized_image_name_array}.tar.gz" "${remote_user}@${remote_ip}:${docker_dir}"
        [ $? -ne 0 ] && echo_log_error "\033[31m镜像文件传输失败，请检查网络或地址信息！\033[0m"
    done
}

# 在远程服务器上加载镜像并修改名称
remote_operations() {
    echo ""
    echo_log_info "\033[34m>>> 3. 开始导入镜像文件...\033[0m"

    for sanitized_image_name_array in "${sanitized_image_name_array[@]}"; do
        echo_log_info "导入镜像文件 \033[33m${sanitized_image_name_array}.tar.gz\033[0m..."
        sshpass -p "${remote_passwd}" ssh -o StrictHostKeyChecking=no "$remote_user@$remote_ip" >/dev/null 2>&1 << EOF
cd "${docker_dir}"
gunzip -c "${sanitized_image_name_array}.tar.gz" | docker load
EOF
    [ $? -ne 0 ] && echo_log_error "\033[31m镜像导入失败，请检查异常！\033[0m"
    done
}

main() {
    print_title
    check_system
    export_image
    copy_image_to_remote
    if [ $? -eq 0 ]; then
        remote_operations
    fi
    echo ""
    print_separator
    echo -e "\033[32m脚本执行完成！\033[0m"
    print_separator
    echo ""
}

main