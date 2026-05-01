#!/bin/bash

show_info_tt5srv() {
    VPS_IP=$(curl -s4 ifconfig.me || echo "47.83.121.204")
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}  TeamTalk 登录信息  ${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo -e "  服务器：${YELLOW}$VPS_IP${NC}"
    echo -e "  端口：${YELLOW}10333${NC}"
    echo -e "${GREEN}=================================================${NC}"

    echo -e "${CYAN}已配置的用户：${NC}"
    docker exec tt5srv test -f /srv/tt5srv.xml 2>/dev/null &&     docker exec tt5srv cat /srv/tt5srv.xml 2>/dev/null | python3 -c "
import sys, re
xml = sys.stdin.read()
users = re.findall(r'<user>(.*?)</user>', xml, re.DOTALL)
if users:
    for i, u in enumerate(users, 1):
        uname = re.search(r'<username>([^<]+)</username>', u)
        pwd   = re.search(r'<password>([^<]*)</password>', u)
        utype = re.search(r'<user-type>([^<]*)</user-type>', u)
        name = uname.group(1) if uname else '?'
        pval = pwd.group(1) if pwd and pwd.group(1) else '(空)'
        tval = utype.group(1) if utype else '?'
        print(f'  用户{i}: {name}  |  密码: {pval}  |  类型: {tval}')
else:
    print('  (未找到用户配置)')
" || echo -e "${YELLOW}未找到配置文件，TT5SRV 可能未运行${NC}"
    echo -e "${GREEN}=================================================${NC}"
    pause
}


#!/bin/bash

# ================= 颜色定义 =================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'
SBOX_CMD="sbox"
# SCRIPT_PATH no longer used for symlink - always install to /root/install_tools.sh

# ================= 快捷命令安装函数 =================
install_sbox_shortcut() {
    if [ -L "/usr/local/bin/$SBOX_CMD" ] || [ -f "/usr/local/bin/$SBOX_CMD" ]; then
        return
    fi
    echo -e "${YELLOW}首次运行，正在创建快捷命令 [$SBOX_CMD]...${NC}"
    if ln -sf "$SCRIPT_PATH" /usr/local/bin/$SBOX_CMD 2>/dev/null; then
        echo -e "${GREEN}✅ 快捷命令创建成功！以后输入 '$SBOX_CMD' 即可打开本工具箱${NC}"
    else
        echo -e "${RED}⚠️ 创建快捷命令失败，可能需要 sudo 权限，请尝试：${NC}"
        echo -e "   sudo ln -sf $SCRIPT_PATH /usr/local/bin/$SBOX_CMD"
    fi
    pause
}

pause() {
    echo -e "\n${YELLOW}按任意键返回...${NC}"
    read -n 1 -s -r
}

check_container() {
    if command -v docker &> /dev/null; then
        if docker ps -a --format '{{.Names}}' | grep -Eq "^$1$"; then
            return 0
        fi
    fi
    return 1
}

check_hermes_running() {
    if docker ps --format '{{.Names}}' | grep -qi "hermes"; then
        return 0
    fi
    return 1
}

manage_docker_container() {
    local action=$1
    local name=$2
    if ! check_container "$name"; then
        echo -e "${RED}未找到容器 [$name]，请先安装！${NC}"
    else
        docker $action $name
        echo -e "${GREEN}已成功 $action 容器 [$name]！${NC}"
    fi
    pause
}

install_docker() {
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}Docker 已安装！${NC}"
    else
        echo -e "${YELLOW}正在安装 Docker...${NC}"
        curl -fsSL https://get.docker.com | bash -s docker
        systemctl enable --now docker
        echo -e "${GREEN}Docker 安装完成！${NC}"
    fi
    pause
}

install_xui() {
    if command -v x-ui &> /dev/null; then
        echo -e "${GREEN}X-UI 已安装！${NC}"
    else
        echo -e "${YELLOW}正在安装 X-UI...${NC}"
        wget -O install.sh https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/install.sh
        bash install.sh
    fi
    pause
}

install_lucky() {
    if check_container "lucky"; then
        echo -e "${GREEN}Lucky 已安装！${NC}"
    else
        echo -e "${YELLOW}正在安装 Lucky...${NC}"
        docker run -d --name lucky --restart always --network host -v /etc/lucky:/goodluck gdy666/lucky
        echo -e "${GREEN}Lucky 安装完成！默认管理端口: 16601${NC}"
    fi
    pause
}

install_warp() {
    echo -e "${YELLOW}正在启动 WARP 安装脚本...${NC}"
    wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh
    pause
}

install_frps() {
    if check_container "frps"; then
        echo -e "${GREEN}FRP 服务端已安装！${NC}"
    else
        echo -e "${YELLOW}正在安装 FRP 服务端...${NC}"
        docker run --restart=always -d --network host --name frps snowdreamtech/frps
        echo -e "${GREEN}FRP 安装完成！默认通信端口: 7000${NC}"
    fi
    pause
}

install_teamtalk() {
    if check_container "tt5srv"; then
        echo -e "${GREEN}TeamTalk 服务端已安装！${NC}"
    else
        echo -e "${YELLOW}正在安装 TeamTalk (数据保存在当前目录: $PWD)...${NC}"
        docker run --network host -v $PWD:/srv -d --name tt5srv deepcomp/tt5srv:latest
        echo -e "${GREEN}TeamTalk 安装完成！${NC}"
    fi
    pause
}

config_teamtalk() {
    echo -e "${YELLOW}启动 TeamTalk 配置向导...${NC}"
    docker run -v $PWD/srv:/srv --rm -it --entrypoint tt5srv deepcomp/tt5srv:latest -wizard -wd /srv
    
    # 向导运行完毕后，自动检查并复制配置文件到正确位置
    echo -e "${CYAN}正在检查并复制配置文件...${NC}"
    if [ -f "$PWD/srv/srv/tt5srv.xml" ] && [ -s "$PWD/srv/srv/tt5srv.xml" ]; then
        # 检查当前位置的配置文件是否是空的或很小，如果是才复制
        CURRENT_SIZE=$(stat -c%s "$PWD/srv/tt5srv.xml" 2>/dev/null || echo 0)
        WIZARD_SIZE=$(stat -c%s "$PWD/srv/srv/tt5srv.xml" 2>/dev/null || echo 0)

        if [ "$CURRENT_SIZE" -lt 100 ] && [ "$WIZARD_SIZE" -gt 100 ]; then
            cp "$PWD/srv/srv/tt5srv.xml" "$PWD/srv/tt5srv.xml"
            echo -e "${GREEN}✅ 配置文件已复制到正确位置${NC}"
        else
            echo -e "${YELLOW}⚠️ 配置文件未修改或已存在，无需复制${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ 未找到向导生成的新配置文件${NC}"
    fi
    
    echo -e "${GREEN}配置完毕！${NC}"
    pause
}

# ================= Hermes 爱马仕 安装函数 =================
install_hermes() {
    if check_hermes_running; then
        echo -e "${GREEN}Hermes (爱马仕) 已在运行中！${NC}"
        pause
        return
    fi

    echo -e "${YELLOW}正在安装 Hermes (爱马仕)...${NC}"
    echo -e "${CYAN}-> 正在拉取 HermesDeckX Docker Compose 配置...${NC}"
    curl -fsSL https://raw.githubusercontent.com/HermesDeckX/HermesDeckX/main/docker-compose.yml -o docker-compose.yml
    echo -e "${CYAN}-> 正在启动容器...${NC}"
    docker compose up -d
    echo -e "${CYAN}-> 正在进行健康检查 (请稍候 10 秒)...${NC}"
    sleep 10
    
    if check_hermes_running; then
        VPS_IP=$(curl -s4 ifconfig.me || echo "47.83.121.204")
        echo -e "${GREEN}=================================================${NC}"
        echo -e "${GREEN}✅ 恭喜！Hermes (爱马仕) 安装成功！${NC}"
        echo -e "${CYAN}正在提取初始账号信息...${NC}"
        echo -e "${GREEN}=================================================${NC}"
        LOG=$(docker logs hermesdeckx 2>\&1 | grep -A5 "First-time setup" | head -10)
        if [ -n "$LOG" ]; then
            echo -e "${YELLOW}$LOG${NC}"
        else
            echo -e "${YELLOW}⚠️ 未找到初始账号，请运行：docker logs hermesdeckx${NC}"
        fi
        echo -e "${GREEN}=================================================${NC}"
        echo -e "  登录地址：http://$VPS_IP:19700"
        echo -e "${GREEN}=================================================${NC}"
        echo -e "⚠️ 请去阿里云安全组放行 19700 端口！"
        echo -e "${GREEN}=================================================${NC}"
    else
        echo -e "${RED}=================================================${NC}"
        echo -e "${RED}❌ 安装失败，请检查 Docker 和网络是否正常！${NC}"
        echo -e "${RED}=================================================${NC}"
    fi
    pause
}

# ================= Hermes 爱马仕 安装函数 =================

# ================= 专属子菜单构建器 =================
menu_docker_app() {
    local app_name=$1
    local install_func=$2
    local extra_text=$3
    local extra_func=$4

    while true; do
        clear
        echo -e "${CYAN}========== 管理[$app_name] ==========${NC}"
        echo "  1. 安装 $app_name"
        echo "  2. 启动/重启 $app_name"
        echo "  3. 停止 $app_name"
        if [ -n "$extra_text" ]; then
            echo "  4. $extra_text"
        fi
        echo "  0. 返回主菜单"
        echo -e "${CYAN}======================================${NC}"
        read -p "请选择: " sub_ch

        case "$sub_ch" in
            1) if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker！${NC}"; pause; else $install_func; fi ;;
            2) manage_docker_container "restart" "$app_name" ;;
            3) manage_docker_container "stop" "$app_name" ;;
            4) if [ -n "$extra_func" ]; then $extra_func; fi ;;
            0) break ;;
            *) echo -e "${RED}输入错误！${NC}"; sleep 1 ;;
        esac
    done
}

menu_xui() {
    while true; do
        clear
        echo -e "${CYAN}========== 管理 [X-UI] ==========${NC}"
        echo "  1. 安装/更新 X-UI"
        echo "  2. 启动/重启 X-UI"
        echo "  3. 停止 X-UI"
        echo "  4. 唤出 X-UI 原生控制面板"
        echo "  0. 返回主菜单"
        echo -e "${CYAN}=================================${NC}"
        read -p "请选择: " sub_ch
        case "$sub_ch" in
            1) install_xui ;;
            2) systemctl restart x-ui; echo -e "${GREEN}已重启 X-UI${NC}"; pause ;;
            3) systemctl stop x-ui; echo -e "${GREEN}已停止 X-UI${NC}"; pause ;;
            4) if command -v x-ui &> /dev/null; then x-ui; else echo "未安装"; pause; fi ;;
            0) break ;;
        esac
    done
}

menu_hermes() {
    while true; do
        clear
        echo -e "${CYAN}========== 管理 [Hermes 爱马仕] ==========${NC}"
        echo "  1. 一键部署 Hermes"
        echo "  2. 启动/重启 Hermes"
        echo "  3. 停止 Hermes"
        echo "  4. 查看登录信息"
        echo "  0. 返回主菜单"
        echo -e "${CYAN}==========================================${NC}"
        read -p "请选择: " sub_ch
        case "$sub_ch" in
            1) if ! command -v docker &> /dev/null; then echo -e "${RED}请先安装 Docker！${NC}"; pause; else install_hermes; fi ;;
            2) docker compose -f docker-compose.yml restart 2>/dev/null || docker restart $(docker ps --filter "name=hermes" --format "{{.Names}}") 2>/dev/null; echo -e "${GREEN}已发送重启指令！${NC}"; pause ;;
            3) docker compose -f docker-compose.yml stop 2>/dev/null || docker stop $(docker ps --filter "name=hermes" --format "{{.Names}}") 2>/dev/null; echo -e "${GREEN}已停止！${NC}"; pause ;;
            4) # --- Hermes Info (inline) ---
            VPS_IP=$(curl -s4 ifconfig.me || echo "47.83.121.204")
            echo -e "${GREEN}=================================================${NC}"
            echo -e "${GREEN}  Hermes 登录信息  ${NC}"
            echo -e "${GREEN}=================================================${NC}"
            echo -e "  登录地址：${YELLOW}http://$VPS_IP:19700${NC}"
            echo -e "${GREEN}=================================================${NC}"
            docker exec hermesdeckx test -f /data/hermesdeckx/HermesDeckX.db 2>/dev/null &&             docker cp hermesdeckx:/data/hermesdeckx/HermesDeckX.db /tmp/h.db 2>/dev/null &&             python3 -c "import sqlite3; c=sqlite3.connect('/tmp/h.db').cursor(); print('已注册:', [u[0] for u in c.execute('SELECT username FROM users')] or ['(无)'])" 2>/dev/null || echo "Hermes未运行或无数据"
            echo -e "${YELLOW}初始密码：$(docker logs hermesdeckx 2>&1 | grep 'Password:' | sed 's/.*Password:[[:space:]]*//' | tr -d ' |' | head -1 2>/dev/null || echo '请查看日志')${NC}"
            echo -e "${GREEN}=================================================${NC}"
            echo -n "按任意键继续..." && read -n 1 -s
            ;;
            0) break ;;
            *) echo -e "${RED}输入错误！${NC}"; sleep 1 ;;
        esac
    done
}

# ================= 主菜单逻辑 =================
install_sbox_shortcut

while true; do
    clear
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${GREEN}       服务器全能工具箱 v2.2        ${NC}"
    echo -e "${GREEN}=================================================${NC}"
    echo -e "${YELLOW} [基础环境 & 双栈网络] ${NC}"
    echo "   1. Docker    (基础容器引擎)"
    echo "   2. WARP      (添加虚拟 IPv6)"
    echo -e "${YELLOW} [代理与内网穿透] ${NC}"
    echo "   3. X-UI      (多协议代理面板)"
    echo "   4. Lucky     (端口转发/反代)"
    echo "   5. FRP       (高速专属内网穿透)"
    echo -e "${YELLOW}[AI 智能与协同工具] ${NC}"
    echo "   6. TeamTalk  (企业级语音服务)"
    echo "   7. Hermes    (爱马仕-中文智能体控制台)"
    echo -e "${GREEN}=================================================${NC}"
    echo "   8. 创建/更新快捷命令 ($SBOX_CMD)"
    echo "   0. 退出工具箱"
    echo ""
    read -p "请输入要管理的工具序号 [0-8]: " main_choice

    case "$main_choice" in
        1) 
            while true; do
                clear; echo -e "${CYAN}========== 管理[Docker] ==========${NC}"
                echo "  1. 安装 Docker"; echo "  2. 重启 Docker 服务"; echo "  0. 返回主菜单"
                read -p "请选择: " d_ch
                case "$d_ch" in 1) install_docker ;; 2) systemctl restart docker; echo "已重启"; pause ;; 0) break ;; esac
            done ;;
        2) 
            while true; do
                clear; echo -e "${CYAN}========== 管理 [WARP] ==========${NC}"
                echo "  1. 安装/唤出 WARP 脚本"; echo "  0. 返回主菜单"
                read -p "请选择: " w_ch
                case "$w_ch" in 1) install_warp ;; 0) break ;; esac
            done ;;
        3) menu_xui ;;
        4) menu_docker_app "lucky" "install_lucky" "" "" ;;
        5) menu_docker_app "frps" "install_frps" "" "" ;;
        6) 
            while true; do
                clear; echo -e "${CYAN}========== 管理 [TeamTalk] ==========${NC}"
                echo "  1. 安装 TeamTalk"
                echo "  2. 启动/重启 TeamTalk"
                echo "  3. 停止 TeamTalk"
                echo "  4. 运行配置向导"
                echo "  5. 查看登录信息"
                echo "  0. 返回主菜单"
                echo -e "${CYAN}=================================${NC}"
                read -p "请选择: " tt_ch
                case "$tt_ch" in
                    1) install_teamtalk ;;
                    2) manage_docker_container "restart" "tt5srv" ;;
                    3) manage_docker_container "stop" "tt5srv" ;;
                    4) config_teamtalk ;;
                    5) show_info_tt5srv ;;
                    0) break ;;
                    *) echo -e "${RED}输入错误！${NC}"; sleep 1 ;;
                esac
            done ;;
        7) menu_hermes ;;
        8) install_sbox_shortcut ;;
        0) echo -e "${GREEN}感谢使用，再见！${NC}"; exit 0 ;;
        *) echo -e "${RED}输入错误，请输入有效数字！${NC}"; sleep 1 ;;
    esac
done



