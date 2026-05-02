#!/bin/bash

# ============================================================
#  服务器运维工具 v1.0
#  功能：状态监控 | 防火墙 | 端口 | 网络加速 | Swap | 中文+时区
# ============================================================

# ================= 颜色定义 =================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ================= 工具函数 =================
pause() {
    echo ""
    echo -e "${CYAN}按回车继续...${NC}"
    read -r
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：请用 root 用户运行此脚本${NC}"
        exit 1
    fi
}

# ================= 功能1：服务器状态监控 =================
server_status() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  服务器状态监控  ${NC}"
    echo -e "${GREEN}=================================================${NC}"

    # 系统信息
    echo -e "${CYAN}【系统信息】${NC}"
    echo -e "  主机名：$(hostname)"
    echo -e "  系统：$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "  内核：$(uname -r)"
    echo -e "  运行时间：$(uptime -p 2>/dev/null || uptime | sed 's/.*up/up/')"

    # CPU 信息
    echo ""
    echo -e "${CYAN}【CPU 信息】${NC}"
    echo -e "  型号：$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo -e "  核心数：$(nproc)"
    echo -e "  使用率：$(top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d. -f1)%"

    # 内存信息
    echo ""
    echo -e "${CYAN}【内存信息】${NC}"
    free -h | awk 'NR==2{printf "  总内存: %s  已用: %s  空闲: %s  使用率: %.1f%%\n", $2, $3, $4, $3/$2*100}'

    # 磁盘信息
    echo ""
    echo -e "${CYAN}【磁盘信息】${NC}"
    df -h / | awk 'NR==2{printf "  总容量: %s  已用: %s  可用: %s  使用率: %s\n", $2, $3, $4, $5}'

    # 负载信息
    echo ""
    echo -e "${CYAN}【系统负载】${NC}"
    echo -e "  1分钟：$(awk '{print $1}' /proc/loadavg)"
    echo -e "  5分钟：$(awk '{print $2}' /proc/loadavg)"
    echo -e "  15分钟：$(awk '{print $3}' /proc/loadavg)"

    # 网络信息
    echo ""
    echo -e "${CYAN}【网络信息】${NC}"
    echo -e "  公网IP：$(curl -s4 ifconfig.me 2>/dev/null || echo '获取失败')"

    echo -e "${GREEN}=================================================${NC}"
    pause
}

# ================= 功能2：防火墙管理 =================
firewall_menu() {
    while true; do
        clear
        echo -e "${GREEN}=================================================${NC}"
        echo -e "${GREEN}  防火墙管理  ${NC}"
        echo -e "${GREEN}=================================================${NC}"

        # 检查防火墙状态
        if command -v ufw &>/dev/null; then
            UFW_STATUS=$(ufw status 2>/dev/null | head -1)
            echo -e "  当前状态：${YELLOW}${UFW_STATUS}${NC}"
        elif command -v firewall-cmd &>/dev/null; then
            FW_STATUS=$(systemctl is-active firewalld 2>/dev/null)
            echo -e "  firewalld 状态：${YELLOW}${FW_STATUS}${NC}"
        else
            echo -e "  防火墙：${YELLOW}未安装${NC}"
        fi

        echo -e "${GREEN}=================================================${NC}"
        echo -e "  1. 安装防火墙 (ufw)"
        echo -e "  2. 启动/停止防火墙"
        echo -e "  3. 放行端口"
        echo -e "  4. 关闭端口"
        echo -e "  5. 查看开放端口"
        echo -e "  6. 重载规则"
        echo -e "  0. 返回主菜单"
        echo -e "${GREEN}=================================================${NC}"
        echo -n "请选择: "
        read -r choice

        case $choice in
            1) install_ufw ;;
            2) toggle_ufw ;;
            3) allow_port ;;
            4) deny_port ;;
            5) list_rules ;;
            6) reload_firewall ;;
            0) break ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
    done
}

install_ufw() {
    if command -v ufw &>/dev/null; then
        echo -e "${YELLOW}ufw 已安装，跳过${NC}"
        pause
        return
    fi
    echo -e "${CYAN}正在安装 ufw...${NC}"
    apt-get update -qq && apt-get install -y ufw
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ufw 安装成功${NC}"
    else
        echo -e "${RED}❌ ufw 安装失败${NC}"
    fi
    pause
}

toggle_ufw() {
    if ! command -v ufw &>/dev/null; then
        echo -e "${RED}ufw 未安装，请先安装${NC}"
        pause
        return
    fi
    STATUS=$(ufw status | head -1)
    if echo "$STATUS" | grep -q "inactive"; then
        echo -e "${CYAN}正在启动 ufw...${NC}"
        ufw --force enable
        echo -e "${GREEN}✅ ufw 已启动${NC}"
    else
        echo -e "${CYAN}正在停止 ufw...${NC}"
        ufw disable
        echo -e "${GREEN}✅ ufw 已停止${NC}"
    fi
    pause
}

allow_port() {
    echo -n "请输入要放行的端口（如 80 或 80,443）: "
    read -r port
    echo -n "协议 (tcp/udp/both，默认tcp): "
    read -r proto
    proto=${proto:-tcp}
    if [ "$proto" = "both" ]; then
        ufw allow "$port"
    else
        ufw allow "$port/$proto"
    fi
    echo -e "${GREEN}✅ 已放行端口 $port${NC}"
    pause
}

deny_port() {
    echo -n "请输入要关闭的端口: "
    read -r port
    ufw deny "$port"
    echo -e "${GREEN}✅ 已关闭端口 $port${NC}"
    pause
}

list_rules() {
    echo -e "${CYAN}当前防火墙规则：${NC}"
    ufw status numbered
    pause
}

reload_firewall() {
    ufw reload
    echo -e "${GREEN}✅ 规则已重载${NC}"
    pause
}

# ================= 功能3：端口管理 =================
port_management() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  端口管理  ${NC}"
    echo -e "${GREEN}=================================================${NC}"

    echo -e "${CYAN}【所有监听端口】${NC}"
    ss -tlnp 2>/dev/null | awk 'NR>1{
        split($4, a, ":");
        port = a[length(a)];
        split($6, b, "\"");
        prog = b[2];
        if (prog == "") prog = "-";
        printf "  端口 %-8s  进程 %s\n", port, prog
    }' | sort -t' ' -k2 -n | uniq

    echo ""
    echo -e "${CYAN}【常用端口检查】${NC}"
    for p in 22 80 443 3306 6379 8080 10333 19700; do
        if ss -tln | grep -q ":$p "; then
            echo -e "  端口 ${YELLOW}$p${NC}：${GREEN}开放${NC}"
        else
            echo -e "  端口 ${YELLOW}$p${NC}：未开放"
        fi
    done

    echo -e "${GREEN}=================================================${NC}"
    pause
}

# ================= 功能4：网络加速 =================
network_accel() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  网络加速  ${NC}"
    echo -e "${GREEN}=================================================${NC}"

    # BBR 状态
    BBR_STATUS=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
    echo -e "${CYAN}【BBR 加速状态】${NC}"
    if [ "$BBR_STATUS" = "bbr" ]; then
        echo -e "  BBR：${GREEN}已启用${NC}"
    else
        echo -e "  BBR：${YELLOW}未启用${NC}"
        echo -e "  当前拥塞控制：${BBR_STATUS}"
    fi

    # TCP Fast Open
    TFO=$(cat /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null)
    echo -e "  TCP Fast Open：${YELLOW}${TFO:-未知}${NC}"

    # TCP 拥塞窗口
    CWND=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)
    echo -e "  拥塞控制算法：${YELLOW}${CWND:-未知}${NC}"

    echo -e "${GREEN}=================================================${NC}"
    echo -e "  1. 启用 BBR 加速"
    echo -e "  2. 优化网络内核参数"
    echo -e "  3. 安装 BBR Plus（内核不支持时）"
    echo -e "  0. 返回主菜单"
    echo -e "${GREEN}=================================================${NC}"
    echo -n "请选择: "
    read -r choice

    case $choice in
        1) enable_bbr ;;
        2) optimize_network ;;
        3) install_bbr_plus ;;
        0) return ;;
    esac
}

enable_bbr() {
    echo -e "${CYAN}正在启用 BBR...${NC}"
    # 检查内核版本
    KVER=$(uname -r | cut -d. -f1)
    if [ "$KVER" -ge 4 ]; then
        # 检查模块
        modprobe tcp_bbr 2>/dev/null
        echo "tcp_bbr" >> /etc/modules-load.d/bbr.conf 2>/dev/null
        sysctl -w net.ipv4.tcp_congestion_control=bbr
        sysctl -w net.core.default_qdisc=fq
        # 写入配置
        cat > /etc/sysctl.d/99-bbr.conf << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
        sysctl -p /etc/sysctl.d/99-bbr.conf > /dev/null 2>&1
        echo -e "${GREEN}✅ BBR 加速已启用${NC}"
    else
        echo -e "${RED}内核版本 $(uname -r) 过低，需要 4.9+${NC}"
        echo -e "${YELLOW}请先升级内核或使用 BBR Plus${NC}"
    fi
    pause
}

optimize_network() {
    echo -e "${CYAN}正在优化网络内核参数...${NC}"
    cat > /etc/sysctl.d/99-network-optimize.conf << EOF
# 网络优化参数
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_max_syn_backlog = 32768
net.ipv4.tcp_syncookies = 1
EOF
    sysctl -p /etc/sysctl.d/99-network-optimize.conf > /dev/null 2>&1
    echo -e "${GREEN}✅ 网络参数优化完成${NC}"
    pause
}

install_bbr_plus() {
    echo -e "${CYAN}正在安装 BBR Plus...${NC}"
    echo -e "${YELLOW}BBR Plus 需要手动升级内核，流程较长${NC}"
    echo -e "是否继续？(y/n): "
    read -r confirm
    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}已取消${NC}"
        pause
        return
    fi
    # 安装依赖
    apt-get update -qq
    apt-get install -y wget curl libssl-dev
    # 下载内核
    echo -e "${CYAN}下载 kernel-5.10.102...${NC}"
    wget -q "https://github.com/xanllu/bbrplus/releases/download/v5.10.102/linux-5.10.102-bbrplus.tar.gz" -O /tmp/bbrplus.tar.gz
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 下载成功，解压中...${NC}"
        cd /tmp && tar -xzf bbrplus.tar.gz
        echo -e "${YELLOW}⚠ 请手动安装内核：cd /tmp/linux-5.10.102-bbrplus && make && make modules_install && make install${NC}"
    else
        echo -e "${RED}❌ 下载失败，请手动下载${NC}"
    fi
    pause
}

# ================= 功能5：Swap 虚拟内存 =================
manage_swap() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  虚拟内存 (Swap) 管理  ${NC}"
    echo -e "${GREEN}=================================================${NC}"

    # 当前 Swap 状态
    SWAP_TOTAL=$(free -m | awk '/Swap/{print $2}')
    SWAP_USED=$(free -m | awk '/Swap/{print $3}')
    echo -e "${CYAN}【当前 Swap 状态】${NC}"
    if [ "$SWAP_TOTAL" -gt 0 ]; then
        echo -e "  总大小：${YELLOW}${SWAP_TOTAL}MB${NC}"
        echo -e "  已使用：${YELLOW}${SWAP_USED}MB${NC}"
    else
        echo -e "  ${YELLOW}未设置 Swap${NC}"
    fi

    # Swap 文件位置
    if [ -f /swapfile ]; then
        SWAP_SIZE=$(du -m /swapfile | awk '{print $1}')
        echo -e "  Swap 文件：${YELLOW}/swapfile (${SWAP_SIZE}MB)${NC}"
    fi

    echo -e "${GREEN}=================================================${NC}"
    echo -e "  1. 创建/调整 Swap（推荐 2G）"
    echo -e "  2. 删除 Swap"
    echo -e "  3. 查看 Swap 详细信息"
    echo -e "  0. 返回主菜单"
    echo -e "${GREEN}=================================================${NC}"
    echo -n "请选择: "
    read -r choice

    case $choice in
        1) create_swap ;;
        2) remove_swap ;;
        3) show_swap_detail ;;
        0) return ;;
    esac
}

create_swap() {
    echo -n "请输入 Swap 大小（MB，默认 2048）: "
    read -r size
    size=${size:-2048}

    # 检查物理内存
    MEM_TOTAL=$(free -m | awk '/Mem/{print $2}')
    if [ "$size" -gt "$((MEM_TOTAL * 2))" ]; then
        echo -e "${RED}⚠ Swap 大小建议不超过物理内存的 2 倍${NC}"
        echo -n "确认创建？(y/n): "
        read -r confirm
        if [ "$confirm" != "y" ]; then
            echo -e "${YELLOW}已取消${NC}"
            pause
            return
        fi
    fi

    # 关闭现有 swap
    swapoff /swapfile 2>/dev/null

    # 创建 swap 文件
    echo -e "${CYAN}正在创建 ${size}MB Swap...${NC}"
    dd if=/dev/zero of=/swapfile bs=1M count="$size" status=progress 2>&1
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # 添加到 fstab（防止重启丢失）
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi

    # 设置默认 swappiness
    sysctl vm.swappiness=10 > /dev/null 2>&1
    echo "vm.swappiness=10" > /etc/sysctl.d/99-swap.conf

    echo -e "${GREEN}✅ Swap ${size}MB 创建成功${NC}"
    echo -e "  当前 Swap：$(free -h | awk '/Swap/{print $2}')"
    pause
}

remove_swap() {
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}没有 Swap 文件，无需删除${NC}"
        pause
        return
    fi
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
    echo -e "${GREEN}✅ Swap 已删除${NC}"
    pause
}

show_swap_detail() {
    echo -e "${CYAN}【Swap 详细信息】${NC}"
    swapon --show 2>/dev/null
    echo ""
    free -h | grep -E "Mem|Swap"
    echo ""
    echo -e "  swappiness：$(sysctl vm.swappiness 2>/dev/null | awk '{print $3}')"
    pause
}

# ================= 功能6：中文+时区设置 =================
set_chinese_locale() {
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  中文语言 + 上海时区设置  ${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${CYAN}此操作将分两步执行：${NC}"
    echo -e "  第1步：安装中文语言包"
    echo -e "  第2步：设置时区为 Asia/Shanghai"
    echo -e "${YELLOW}第1步成功后才会执行第2步${NC}"
    echo -e "${GREEN}=================================================${NC}"

    # ---- 第1步：安装中文语言包 ----
    echo ""
    echo -e "${CYAN}【第1步/2】安装中文语言包 (zh_CN.UTF-8)...${NC}"

    # 检测当前语言
    CURRENT_LANG=$(locale 2>/dev/null | grep LANG | head -1 | cut -d= -f2 | tr -d '"')
    echo -e "  当前语言：${YELLOW}${CURRENT_LANG}${NC}"

    if echo "$CURRENT_LANG" | grep -qi "zh_CN.UTF-8"; then
        echo -e "  ${GREEN}✅ 已经是中文语言，跳过${NC}"
        STEP1_OK=true
    else
        # 检测系统包管理器
        if command -v apt-get &>/dev/null; then
            PKG_MGR="apt"
            echo -e "  使用 apt 安装..."
            apt-get update -qq
            apt-get install -y locales
            sed -i 's/# en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen 2>/dev/null
            sed -i 's/# zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen 2>/dev/null
            locale-gen zh_CN.UTF-8 en_US.UTF-8 > /dev/null 2>&1
            update-locale LANG=zh_CN.UTF-8 > /dev/null 2>&1
            STEP1_OK=true
        elif command -v yum &>/dev/null; then
            PKG_MGR="yum"
            echo -e "  使用 yum 安装..."
            yum install -y langpacks-zh_CN glibc-langpack-zh > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                localectl set-locale LANG=zh_CN.UTF-8 > /dev/null 2>&1
                STEP1_OK=true
            else
                STEP1_OK=false
            fi
        elif command -v dnf &>/dev/null; then
            PKG_MGR="dnf"
            echo -e "  使用 dnf 安装..."
            dnf install -y langpacks-zh_CN glibc-langpack-zh > /dev/null 2>&1
            if [ $? -eq 0 ]; then
                localectl set-locale LANG=zh_CN.UTF-8 > /dev/null 2>&1
                STEP1_OK=true
            else
                STEP1_OK=false
            fi
        else
            echo -e "  ${RED}❌ 未识别的包管理器${NC}"
            STEP1_OK=false
        fi

        if [ "$STEP1_OK" = true ]; then
            echo -e "  ${GREEN}✅ 中文语言包安装成功${NC}"
        else
            echo -e "  ${RED}❌ 中文语言包安装失败${NC}"
            echo -e "${RED}=================================================${NC}"
            echo -e "${YELLOW}第1步失败，中止执行第2步${NC}"
            pause
            return
        fi
    fi

    # ---- 第2步：设置时区 ----
    echo ""
    echo -e "${CYAN}【第2步/2】设置时区为 Asia/Shanghai...${NC}"

    CURRENT_TZ=$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}')
    echo -e "  当前时区：${YELLOW}${CURRENT_TZ}${NC}"

    if [ "$CURRENT_TZ" = "Asia/Shanghai" ]; then
        echo -e "  ${GREEN}✅ 已经是上海时区，跳过${NC}"
    else
        # 尝试用 timedatectl
        if command -v timedatectl &>/dev/null; then
            timedatectl set-timezone Asia/Shanghai 2>/dev/null
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}✅ 时区已设置为 Asia/Shanghai${NC}"
            else
                echo -e "  ${RED}❌ timedatectl 设置失败，尝试软链接方式...${NC}"
                # 备用方案：软链接
                rm -f /etc/localtime
                ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
                echo "Asia/Shanghai" > /etc/timezone
                echo -e "  ${GREEN}✅ 时区已设置为 Asia/Shanghai（软链接方式）${NC}"
            fi
        else
            rm -f /etc/localtime
            ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
            echo "Asia/Shanghai" > /etc/timezone
            echo -e "  ${GREEN}✅ 时区已设置为 Asia/Shanghai（软链接方式）${NC}"
        fi
    fi

    # 验证结果
    echo ""
    echo -e "${CYAN}【设置结果】${NC}"
    echo -e "  系统语言：${YELLOW}$(locale 2>/dev/null | grep LANG | head -1 | cut -d= -f2 | tr -d '"')${NC}"
    echo -e "  系统时区：${YELLOW}$(timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}' || cat /etc/timezone 2>/dev/null)${NC}"
    echo -e "  系统时间：${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

    echo -e "${GREEN}=================================================${NC}"
    pause
}

# ================= 主菜单 =================
main_menu() {
    check_root

    while true; do
        clear
        echo -e "${GREEN}=================================================${NC}"
        echo -e "${GREEN}  服务器运维工具 v1.0  ${NC}"
        echo -e "${GREEN}  $(date '+%Y-%m-%d %H:%M:%S %Z')  ${NC}"
        echo -e "${GREEN}=================================================${NC}"
        echo -e "  1. 服务器状态监控"
        echo -e "  2. 防火墙管理"
        echo -e "  3. 端口管理"
        echo -e "  4. 网络加速 (BBR)"
        echo -e "  5. Swap 虚拟内存"
        echo -e "  6. 中文语言 + 上海时区"
        echo -e "  0. 退出"
        echo -e "${GREEN}=================================================${NC}"
        echo -n "请选择: "
        read -r choice

        case $choice in
            1) server_status ;;
            2) firewall_menu ;;
            3) port_management ;;
            4) network_accel ;;
            5) manage_swap ;;
            6) set_chinese_locale ;;
            0)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu
