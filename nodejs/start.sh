#!/bin/bash

# Aria2 路径和配置
aria2c_path="/home/container/aria2/aria2c"
config_path="/home/container/aria2/aria2.conf"
log_path="/home/container/aria2/aria2.log"
ARIA2_RPC_PORT=${SERVER_PORT:-6800}        # Aria2 RPC端口，自动获取玩具端口，不用改  
rpc_secret="P3TERX"                        # Aria2 RPC 密钥

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

# 检查 aria2c 文件是否存在
if [[ ! -f "$aria2c_path" ]]; then
    log_info "未找到 aria2c 文件，正在下载..."
    curl -L -o aria2.tar "https://raw.githubusercontent.com/zylf00/aria2-rongqi/main/aria2.tar"
    tar -xf aria2.tar -C .
    rm aria2.tar
    if [[ ! -f "$aria2c_path" ]]; then
        log_error "下载后未能找到 aria2c 文件，退出。"
        exit 1
    fi
fi

# 检查配置文件是否存在
if [[ ! -f "$config_path" ]]; then
    log_error "未找到 aria2.conf 配置文件，请检查下载的文件。"
    exit 1
fi

chmod +x "$aria2c_path"

log_info "使用配置文件启动 Aria2 服务器，RPC 端口：$ARIA2_RPC_PORT"
"$aria2c_path" --conf-path="$config_path" --log="$log_path" --log-level=warn \
    --rpc-listen-port="$ARIA2_RPC_PORT" --rpc-secret="$rpc_secret" &

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

# 下载并运行哪吒客户端
download_and_run_nezha() {
    ARCH=$(uname -m) && DOWNLOAD_DIR="." && mkdir -p "$DOWNLOAD_DIR" && FILE_INFO=()

    if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/arm64/swith npm")
    elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
        FILE_INFO=("https://github.com/eooce/test/releases/download/amd64/swith npm")
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
    rm -f "$(basename ${FILE_MAP[npm]})"
}

download_and_run_nezha

# 更新 BT-Tracker
update_bt_tracker() {
    log_info "正在更新 BT-Tracker..."
    bash <(curl -fsSL https://raw.githubusercontent.com/P3TERX/aria2.conf/master/tracker.sh) /home/container/aria2/aria2.conf >> /home/container/aria2/tracker.log
    log_info "BT-Tracker 更新完成！"
}

# 执行更新 BT-Tracker
update_bt_tracker
