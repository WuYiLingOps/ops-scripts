#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-11-01
#FileName:         install-zabbix-agent2.bash
#URL:              https://script.huangjingblog.cn
#Description:      Zabbix Agent2一键安装与卸载工具（仅适配Ubuntu/CentOS/Rocky）
#                   - 版本: Zabbix 7.0 / 7.2 / 7.4（配置区切换）
#                   - 通过官方zabbix-release包配置官方源
#                   - 可选安装mongodb/mssql/postgresql监控插件（默认关闭）
#                   - 自动修改Server/ServerActive指向服务端
#Copyright (C):    2026 All rights reserved
#********************************************************************

# ==================== 默认配置 ====================
# zabbix版本选项（各版本release包与agent2/插件包已于2026/11/01在repo.zabbix.com逐一验证存在）
# 支持矩阵（不在矩阵内的系统/版本组合脚本会提示并退出）:
#   7.0: CentOS/Rocky 7/8/9 + Ubuntu 20.04/22.04/24.04/26.04
#   7.2: CentOS/Rocky 7/8/9 + Ubuntu 20.04/22.04/24.04（官网无26.04的release包）
#   7.4: CentOS/Rocky 7/8/9/10 + Ubuntu 20.04/22.04/24.04/26.04
ZABBIX_VERSION="7.0"  #可用 2026/11/01
#ZABBIX_VERSION="7.2"  #可用 2026/11/01
#ZABBIX_VERSION="7.4"  #可用 2026/11/01

# 是否安装agent2数据库插件（mongodb/mssql/postgresql）
# 仅当需要通过该agent监控对应数据库时才开启，普通Linux主机监控无需安装
INSTALL_PLUGINS=false

# Zabbix Server默认地址（安装时直接回车使用此默认值，也可键盘输入其他地址覆盖）
ZABBIX_SERVER_IP="10.0.0.116"

# agent2配置文件路径（apt与yum安装路径一致）
ZABBIX_AGENT2_CONF="/etc/zabbix/zabbix_agent2.conf"
AGENT2_PORT="10050"

# 颜色定义
GREEN="echo -e \E[32;1m"
RED="echo -e \E[31;1m"
YELLOW="echo -e \E[33;1m"
CYAN="echo -e \E[36;1m"
END="\E[0m"

# 日志函数
color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
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

# 检查命令执行结果
check_result() {
    if [ $? -eq 0 ]; then
        color "$1" 0
    else
        color "$1" 1
        exit 1
    fi
}

# 检查root权限
check_root() {
    if [ $EUID -ne 0 ]; then
        color "请使用root用户执行该脚本 (sudo ./install-zabbix-agent2.bash)" 1
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    color "检测系统信息" 0

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_NAME="${PRETTY_NAME}"
    else
        color "无法检测系统类型" 1
        exit 1
    fi

    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    else
        color "未检测到支持的包管理器（apt/dnf/yum）" 1
        exit 1
    fi

    echo -e "  系统: ${OS_NAME}"
    echo -e "  包管理器: ${PKG_MANAGER}"
}

# 校验系统/版本组合是否在已验证的支持矩阵内
check_version_support() {
    case "${OS_ID}" in
        ubuntu)
            case "${OS_VERSION}" in
                20.04|22.04|24.04)
                    ;;
                26.04)
                    # 官网7.2无ubuntu26.04的release包
                    if [ "${ZABBIX_VERSION}" == "7.2" ]; then
                        color "Zabbix 7.2 官网无Ubuntu 26.04的release包，请选择7.0/7.4" 1
                        exit 1
                    fi
                    ;;
                *)
                    color "暂不支持 Ubuntu ${OS_VERSION}（已验证: 20.04/22.04/24.04/26.04）" 1
                    exit 1
                    ;;
            esac
            ;;
        centos|rocky)
            RHEL_MV="${OS_VERSION%%.*}"
            case "${RHEL_MV}" in
                7|8|9)
                    ;;
                10)
                    # 官网仅7.4提供el10的包
                    if [ "${ZABBIX_VERSION}" != "7.4" ]; then
                        color "Zabbix ${ZABBIX_VERSION} 官网无el10的包，仅7.4支持，请选择7.4" 1
                        exit 1
                    fi
                    ;;
                *)
                    color "暂不支持 EL${RHEL_MV}（已验证: 7/8/9/10）" 1
                    exit 1
                    ;;
            esac
            ;;
        *)
            color "当前脚本仅适配Ubuntu/CentOS/Rocky，不支持系统: ${OS_ID}" 1
            exit 1
            ;;
    esac
}

# 检查Agent2是否已安装
check_agent2_installed() {
    if [ -x "$(command -v zabbix_agent2 2>/dev/null)" ] || [ -x /usr/sbin/zabbix_agent2 ]; then
        return 0
    fi
    case "${PKG_MANAGER}" in
        apt) dpkg -l zabbix-agent2 2>/dev/null | grep -q "^ii" ;;
        *)   rpm -q zabbix-agent2 &>/dev/null ;;
    esac
}

# 生成本次安装使用的release包地址（7.0与7.2+官网仓库目录结构不同）
get_release_url() {
    if [ "${PKG_MANAGER}" == "apt" ]; then
        # 7.0: /zabbix/7.0/ubuntu/pool/...  7.2/7.4: /zabbix/${V}/release/ubuntu/pool/...
        if [ "${ZABBIX_VERSION}" == "7.0" ]; then
            RELEASE_URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu${OS_VERSION}_all.deb"
        else
            RELEASE_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu${OS_VERSION}_all.deb"
        fi
    else
        # 7.0: /zabbix/7.0/rhel/${MV}/x86_64/（release包为noarch，归档在x86_64目录）
        # 7.2/7.4: /zabbix/${V}/release/rhel/${MV}/noarch/
        if [ "${ZABBIX_VERSION}" == "7.0" ]; then
            RELEASE_URL="https://repo.zabbix.com/zabbix/7.0/rhel/${RHEL_MV}/x86_64/zabbix-release-latest-7.0.el${RHEL_MV}.noarch.rpm"
        else
            RELEASE_URL="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/${RHEL_MV}/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el${RHEL_MV}.noarch.rpm"
        fi
    fi
}

# 交互获取服务端地址（回车使用默认值）
get_agent2_params() {
    echo ""
    echo -e "  说明: Zabbix Server地址为服务端(或Zabbix Proxy)的IP地址或域名，"
    echo -e "        agent通过该地址的10051端口向服务端主动上报数据，"
    echo -e "        同时服务端需能访问本机的10050端口"
    echo ""
    read -rp "请输入Zabbix Server地址 (回车默认使用 ${ZABBIX_SERVER_IP}): " input_server
    ZABBIX_SERVER_IP="${input_server:-${ZABBIX_SERVER_IP}}"

    echo ""
    echo -e "  Zabbix Server: ${ZABBIX_SERVER_IP}"
    echo -e "  Agent主机名:   $(hostname)（由HostnameItem自动上报）"
}

# 配置Zabbix官方源
setup_agent2_repo() {
    color "1. 配置Zabbix官方源" 0
    get_release_url
    echo -e "  release包: ${RELEASE_URL}"

    if [ "${PKG_MANAGER}" == "apt" ]; then
        # ---------- Ubuntu: 下载并安装zabbix-release deb包 ----------
        wget -q "${RELEASE_URL}" -O /tmp/zabbix-release.deb
        check_result "下载zabbix-release deb包"

        dpkg -i /tmp/zabbix-release.deb
        check_result "安装zabbix-release deb包"
        rm -f /tmp/zabbix-release.deb

        color "更新APT包列表" 0
        apt update -qq 2>&1 | tail -3

        # 验证源中存在agent2候选包
        if ! apt-cache policy zabbix-agent2 2>/dev/null | grep -qE "Candidate: [0-9]"; then
            color "Zabbix源配置失败: 未找到zabbix-agent2候选包" 1
            exit 1
        fi
        color "Zabbix官方源配置验证通过" 0
    else
        # ---------- CentOS/Rocky: 通过yum/dnf安装release rpm包 ----------
        ${PKG_MANAGER} install -y "${RELEASE_URL}"
        check_result "安装zabbix-release rpm包"

        # 验证源中存在agent2可用包
        if ! ${PKG_MANAGER} list available zabbix-agent2 &>/dev/null; then
            color "Zabbix源配置失败: 未找到zabbix-agent2可用包" 1
            exit 1
        fi
        color "Zabbix官方源配置验证通过" 0
    fi
}

# 安装agent2及数据库插件
install_agent2_packages() {
    color "2. 安装Zabbix Agent2" 0

    if [ "${INSTALL_PLUGINS}" == "true" ]; then
        if ! ${PKG_MANAGER} install -y zabbix-agent2 \
                zabbix-agent2-plugin-mongodb \
                zabbix-agent2-plugin-mssql \
                zabbix-agent2-plugin-postgresql; then
            color "插件安装失败，回退为仅安装zabbix-agent2" 2
            ${PKG_MANAGER} install -y zabbix-agent2
            check_result "安装Zabbix Agent2（不含插件）"
        else
            check_result "安装Zabbix Agent2及插件"
        fi
    else
        ${PKG_MANAGER} install -y zabbix-agent2
        check_result "安装Zabbix Agent2"
    fi
}

# 设置agent2配置项（优先替换已生效行，其次取消注释默认行，都没有则追加）
set_agent2_conf() {
    local key="$1" value="$2"
    if grep -qE "^[[:space:]]*${key}=" "${ZABBIX_AGENT2_CONF}"; then
        sed -i -E "s|^[[:space:]]*${key}=.*|${key}=${value}|" "${ZABBIX_AGENT2_CONF}"
    elif grep -qE "^[[:space:]]*#[[:space:]]*${key}=" "${ZABBIX_AGENT2_CONF}"; then
        sed -i -E "s|^[[:space:]]*#[[:space:]]*${key}=.*|${key}=${value}|" "${ZABBIX_AGENT2_CONF}"
    else
        echo "${key}=${value}" >> "${ZABBIX_AGENT2_CONF}"
    fi
}

# 配置Agent2指向Server
configure_agent2() {
    color "3. 配置Agent2" 0

    if [ ! -f "${ZABBIX_AGENT2_CONF}" ]; then
        color "未找到配置文件: ${ZABBIX_AGENT2_CONF}" 1
        exit 1
    fi

    # 首次修改前备份原配置
    if [ ! -f "${ZABBIX_AGENT2_CONF}.bak" ]; then
        cp -p "${ZABBIX_AGENT2_CONF}" "${ZABBIX_AGENT2_CONF}.bak"
        color "已备份原配置: ${ZABBIX_AGENT2_CONF}.bak" 0
    fi

    set_agent2_conf "Server" "${ZABBIX_SERVER_IP}"
    set_agent2_conf "ServerActive" "${ZABBIX_SERVER_IP}"

    color "验证配置结果" 0
    grep -E "^(Server|ServerActive|HostnameItem)=" "${ZABBIX_AGENT2_CONF}"
}

# 启动并设置开机自启
start_agent2() {
    color "4. 启动Zabbix Agent2服务" 0

    systemctl restart zabbix-agent2
    check_result "启动Zabbix Agent2服务"

    systemctl enable zabbix-agent2 >/dev/null 2>&1
    check_result "配置开机自启"
}

# 验证安装
verify_agent2() {
    color "5. 验证安装" 0
    sleep 2

    # 服务运行状态
    if systemctl is-active --quiet zabbix-agent2; then
        color "zabbix-agent2 服务运行中" 0
    else
        color "zabbix-agent2 服务未运行，请执行 systemctl status zabbix-agent2 排查" 1
        exit 1
    fi

    # 开机自启状态
    if systemctl is-enabled --quiet zabbix-agent2 2>/dev/null; then
        color "zabbix-agent2 已设置开机自启" 0
    else
        color "zabbix-agent2 未设置开机自启，请执行 systemctl enable zabbix-agent2" 1
        exit 1
    fi

    # 端口监听（优先ss，回退netstat，两者都没有则跳过）
    if command -v ss &> /dev/null || command -v netstat &> /dev/null; then
        if command -v ss &> /dev/null; then
            PORT_OUT=$(ss -tlnp 2>/dev/null)
        else
            PORT_OUT=$(netstat -tlnp 2>/dev/null)
        fi
        if echo "${PORT_OUT}" | grep -qE ":${AGENT2_PORT}[[:space:]]"; then
            color "端口 ${AGENT2_PORT} 监听正常" 0
        else
            color "端口 ${AGENT2_PORT} 未监听，请检查服务状态与日志" 1
            exit 1
        fi
    else
        color "未检测到ss/netstat命令，跳过端口检查" 2
    fi
}

# 安装Zabbix Agent2
do_install() {
    color "开始安装Zabbix Agent2 ${ZABBIX_VERSION}" 0

    # 检查是否已安装
    if check_agent2_installed; then
        read -rp "检测到Zabbix Agent2已安装，是否覆盖安装？(Y/n): " confirm
        if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
            color "取消安装" 0
            return 0
        fi
    fi

    # 交互获取服务端地址
    get_agent2_params

    # 执行安装步骤
    setup_agent2_repo
    install_agent2_packages
    configure_agent2
    start_agent2
    verify_agent2

    echo ""
    $CYAN "================================================================" $END
    color "Zabbix Agent2 ${ZABBIX_VERSION} 安装完成！" 0
    $CYAN "================================================================" $END
    echo ""
    echo -n "  Zabbix Server: " && $GREEN "${ZABBIX_SERVER_IP}" $END
    echo -n "  Agent主机名:   " && $GREEN "$(hostname)（由HostnameItem自动上报）" $END
    echo -n "  配置文件:      " && $GREEN "${ZABBIX_AGENT2_CONF}（原配置已备份为.bak）" $END
    echo -n "  监听端口:      " && $GREEN "${AGENT2_PORT}" $END
    echo ""
    $CYAN "  常用命令:" $END
    $GREEN "    systemctl status zabbix-agent2    # 查看服务状态" $END
    $GREEN "    systemctl restart zabbix-agent2   # 重启服务" $END
    $GREEN "    tail -f /var/log/zabbix/zabbix_agent2.log   # 查看日志" $END
    echo ""
    $YELLOW "  提示: 请在Zabbix Server的Web界面中添加主机，" $END
    $YELLOW "        接口类型选择Agent并填写本机IP，端口10050" $END
    echo ""
}

# 卸载Zabbix Agent2
do_uninstall() {
    color "开始卸载Zabbix Agent2" 0

    # 检查是否已安装
    if ! check_agent2_installed; then
        color "Zabbix Agent2未安装，无需卸载" 2
        return 0
    fi

    read -rp "确认卸载Zabbix Agent2？(Y/n): " confirm
    if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
        color "取消卸载" 0
        return 0
    fi

    # 停止并禁用服务
    color "停止Zabbix Agent2服务" 0
    systemctl stop zabbix-agent2 2>/dev/null
    systemctl disable zabbix-agent2 2>/dev/null

    # 卸载软件包
    color "卸载Zabbix Agent2软件包" 0
    if [ "${PKG_MANAGER}" == "apt" ]; then
        apt purge -y zabbix-agent2 \
            zabbix-agent2-plugin-mongodb \
            zabbix-agent2-plugin-mssql \
            zabbix-agent2-plugin-postgresql 2>/dev/null
        apt autoremove -y 2>/dev/null
    else
        ${PKG_MANAGER} remove -y zabbix-agent2 \
            zabbix-agent2-plugin-mongodb \
            zabbix-agent2-plugin-mssql \
            zabbix-agent2-plugin-postgresql 2>/dev/null
    fi

    # 删除配置文件
    echo ""
    read -rp "是否删除配置文件目录 /etc/zabbix？(Y/n): " del_conf
    if [[ "${del_conf}" != "n" && "${del_conf}" != "N" ]]; then
        color "删除配置文件目录" 0
        rm -rf /etc/zabbix
    fi

    # 删除日志与运行数据
    color "删除日志与运行数据" 0
    rm -rf /var/log/zabbix /run/zabbix 2>/dev/null

    # 删除官方源
    echo ""
    read -rp "是否删除Zabbix官方源配置？(Y/n): " del_repo
    if [[ "${del_repo}" != "n" && "${del_repo}" != "N" ]]; then
        color "删除Zabbix源配置" 0
        if [ "${PKG_MANAGER}" == "apt" ]; then
            apt purge -y zabbix-release 2>/dev/null
            rm -f /etc/apt/sources.list.d/zabbix.list
            apt update -qq 2>/dev/null
        else
            ${PKG_MANAGER} remove -y zabbix-release 2>/dev/null
            rm -f /etc/yum.repos.d/zabbix.repo
        fi
        color "Zabbix源配置已删除" 0
    fi

    # 验证卸载
    color "验证卸载结果" 0
    if check_agent2_installed; then
        color "Zabbix Agent2卸载失败，请手动检查" 1
        exit 1
    else
        color "Zabbix Agent2卸载成功" 0
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "说明: 不传参数时默认执行install"
    echo ""
    echo "选项:"
    echo "  install    安装Zabbix Agent2"
    echo "  uninstall  卸载Zabbix Agent2"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0          # 默认安装"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
    echo ""
    echo "系统支持（脚本安装时自动校验）:"
    echo "  Ubuntu 20.04/22.04/24.04/26.04（7.2不支持26.04）"
    echo "  CentOS/Rocky 7/8/9/10（仅7.4支持10）"
    echo ""
    echo "参数说明:"
    echo "  安装时需输入Zabbix Server地址: 服务端(或Zabbix Proxy)的IP地址或域名，"
    echo "  直接回车使用脚本配置区的默认地址（当前: ${ZABBIX_SERVER_IP}），"
    echo "  agent通过该地址的10051端口主动上报数据，服务端需能访问本机10050端口"
    echo ""
    echo "组件说明:"
    echo "  zabbix-agent2                   Zabbix Agent2主程序"
    echo "  zabbix-agent2-plugin-mongodb    MongoDB监控插件（可选）"
    echo "  zabbix-agent2-plugin-mssql      MSSQL监控插件（可选）"
    echo "  zabbix-agent2-plugin-postgresql PostgreSQL监控插件（可选）"
    echo "  注: 插件仅监控对应数据库时需要，由配置区INSTALL_PLUGINS开关控制（默认不安装）"
}

# 主函数
main() {
    $CYAN "================================================================" $END
    $GREEN "          Zabbix Agent2 ${ZABBIX_VERSION} 安装与卸载工具" $END
    $CYAN "================================================================" $END
    echo ""

    # 设置默认操作：不传参时默认为install
    ACTION="${1:-install}"

    case "${ACTION}" in
        install)
            check_root
            detect_system
            check_version_support
            do_install
            ;;
        uninstall)
            check_root
            detect_system
            do_uninstall
            ;;
        -h|--help)
            show_help
            ;;
        *)
            color "未知选项: $1" 1
            show_help
            exit 1
            ;;
    esac

    echo ""
    $CYAN "================================================================" $END
    color "脚本执行完成" 0
    $CYAN "================================================================" $END
    echo ""
}

main "$@"
