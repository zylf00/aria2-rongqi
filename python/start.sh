#!/bin/bash
ARIA2_RPC_PORT=${SERVER_PORT:-6800}       # Aria2 RPC端口，自动获取玩具端口，不用改 
rpc_secret="P3TERX"                       # Aria2 RPC 密钥

# 哪吒监控变量
export NEZHA_SERVER=${NEZHA_SERVER:-'nz.abc.cn'}       # 哪吒客户端域名或ip,哪吒3个变量不全不运行
export NEZHA_PORT=${NEZHA_PORT:-'5555'}                # 哪吒端口为{443,8443,2053,2083,2087,2096}其中之一时自动开启tls
export NEZHA_KEY=${NEZHA_KEY:-''}                      # 哪吒客户端密钥

# 统一输出格式的函数
log_info() {
    echo -e "\033[1;32m[信息]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[错误]\033[0m $1"
}

# 检测处理器架构
ARCH=$(uname -m)
log_info "检测到处理器架构：$ARCH"


# 检查 aria2c 文件是否存在
if [[ ! -f "./aria2/aria2c" ]]; then
    log_info "未找到 aria2c 文件，正在下载..."
    curl -L -sS -o aria2.tar "https://github.com/zylf00/aria2-rongqi/raw/refs/heads/main/test/aria2.tar"
    tar -xf aria2.tar -C .
    rm aria2.tar
    if [[ ! -f "./aria2/aria2c" ]]; then
        log_error "下载后未能找到 aria2c 文件，退出。"
        exit 1
    fi
fi

# 将 RPC 端口和密钥写入 aria2.conf 配置文件
sed -i "s/^rpc-listen-port=.*/rpc-listen-port=${ARIA2_RPC_PORT}/" "./aria2/aria2.conf"
sed -i "s/^rpc-secret=.*/rpc-secret=${rpc_secret}/" "./aria2/aria2.conf"

# 启动 Aria2
chmod +x "./aria2/aria2c"
log_info "使用配置文件启动 Aria2 服务器，RPC 端口：$ARIA2_RPC_PORT"
"./aria2/aria2c" --conf-path="./aria2/aria2.conf" --log="./aria2/aria2.log" &


sleep 2

# 测试 Aria2 RPC 连接
log_info "正在测试 Aria2 RPC 连接"
response=$(curl -s -X POST http://127.0.0.1:"$ARIA2_RPC_PORT"/jsonrpc \
    -d '{"jsonrpc":"2.0","method":"aria2.getGlobalStat","id":"curltest","params":["token:'"$rpc_secret"'"]}' \
    -H 'Content-Type: application/json')

if echo "$response" | grep -q '"result"'; then
    log_info "Aria2 RPC 连接正常！"
else
    log_error "Aria2 RPC 连接失败！"
fi


# 更新 BT-Tracker
update_bt_tracker() {
    log_info "正在更新 BT-Tracker..."
    bash ./aria2/tracker.sh /home/container/aria2/aria2.conf >> /home/container/aria2/tracker.log
    log_info "BT-Tracker 更新完成！"
}
update_bt_tracker

# 下载并运行哪吒客户端
download_and_run_nezha() {
    ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()

    if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
        FILE_INFO=("https://github.com/zylf00/aria2-rongqi/raw/main/test/arm/swith npm")
    elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
        FILE_INFO=("https://github.com/zylf00/aria2-rongqi/raw/main/test/amd/swith npm")
    else
        log_error "不支持的架构：$ARCH"
        exit 1
    fi

    declare -A FILE_MAP
    generate_random_name() {
        local chars=abcdefghijklmnopqrstuvwxyz1234567890
        local name=""
        for i in {1..6}; do
            name="$name${chars:RANDOM%${#chars}:1}"
        done
        echo "$name"
    }

    download_file() {
        local URL=$1
        local NEW_FILENAME=$2
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        log_info "下载哪吒客户端 $NEW_FILENAME"
    }

    for entry in "${FILE_INFO[@]}"; do
        URL=$(echo "$entry" | cut -d ' ' -f 1)
        RANDOM_NAME=$(generate_random_name)
        NEW_FILENAME="$DOWNLOAD_DIR/$RANDOM_NAME"
        download_file "$URL" "$NEW_FILENAME"
        chmod +x "$NEW_FILENAME"
        FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
    done

    if [ -e "$(basename ${FILE_MAP[npm]})" ]; then
        tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
        if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
            NEZHA_TLS="--tls"
        else
            NEZHA_TLS=""
        fi
        if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
            export TMPDIR=$(pwd)
            nohup ./"$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
            sleep 1
            log_info "$(basename ${FILE_MAP[npm]}) 正在运行"
        else
            log_error "哪吒变量为空，跳过运行"
        fi
    fi

    # 删除下载的哪吒客户端文件
    sleep 3
    rm -f "$(basename ${FILE_MAP[npm]})" fake_useragent_0.2.0.json
}

download_and_run_nezha

install_rclone() {
    log_info "正在下载 rclone..."

    # 判断系统架构，选择对应的下载链接
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
        RCLONE_URL="https://github.com/zylf00/aria2-rongqi/releases/download/rclone/rclone-amd64"
    elif [[ "$ARCH" == "arm" || "$ARCH" == "armv7l" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        RCLONE_URL="https://github.com/zylf00/aria2-rongqi/releases/download/rclone/rclone-arm64"
    else
        log_error "不支持的架构：$ARCH"
        exit 1
    fi

    # 创建所需文件夹
    for dir in "$HOME/rclone" "$HOME/.config/rclone"; do
        [[ ! -d "$dir" ]] && mkdir -p "$dir"
    done

    # 检查并下载 rclone
    if [[ ! -f "$HOME/rclone/rclone" ]]; then
        curl -L -sS -o "$HOME/rclone/rclone" "$RCLONE_URL"
        chmod +x "$HOME/rclone/rclone"
        log_info "rclone 下载并安装完成！"
    else
        log_info "rclone 已存在，跳过下载。"
    fi

    # 确保 rclone 路径写入 .bashrc
    [[ ! -f "$HOME/.bashrc" ]] && touch "$HOME/.bashrc"
    grep -qxF 'export PATH="$HOME/rclone:$PATH"' "$HOME/.bashrc" || echo 'export PATH="$HOME/rclone:$PATH"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
}

# 执行 rclone 安装
install_rclone

install_jq() {
    # 判断系统架构，选择对应的下载链接
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "amd64" ]]; then
        JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64"
    elif [[ "$ARCH" == "arm" || "$ARCH" == "armv7l" || "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        JQ_URL="https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux-arm"
    else
        log_error "不支持的架构：$ARCH"
        exit 1
    fi

    # 创建文件夹并下载 jq
    [[ ! -d "$HOME/bin" ]] && mkdir -p "$HOME/bin"
    
    if [[ ! -f "$HOME/bin/jq" ]]; then
        curl -L --fail -o "$HOME/bin/jq" "$JQ_URL" 2>curl_error.log
        if [[ $? -ne 0 ]]; then
            log_error "jq 下载失败！"
            return 1
        fi
        chmod +x "$HOME/bin/jq"
    fi

    # 确保 jq 路径写入 .bashrc
    [[ ! -f "$HOME/.bashrc" ]] && touch "$HOME/.bashrc"
    grep -qxF 'export PATH="$HOME/bin:$PATH"' "$HOME/.bashrc" || echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
    source "$HOME/.bashrc"
}

# 执行 jq 安装
install_jq
