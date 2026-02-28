#!/usr/bin/env sh
# Alpine Linux 兼容版 Cloudflare DDNS
# 保存到: /usr/local/bin/cf-ddns.sh

set -e

# ============ 配置区域 ============
# Cloudflare API Token (推荐) 或 Global API Key
# 如果使用 API Token，CFTOKEN 填 Token，CFUSER 留空
# 如果使用 Global API Key，CFKEY 填 Key，CFUSER 填邮箱
CFTOKEN=""
CFKEY=""
CFUSER=""

# 域名配置
CFZONE_NAME="example.com"      # 主域名
CFRECORD_NAME="ddns.example.com"  # 要更新的子域名
CFRECORD_TYPE="A"              # A(IPv4) 或 AAAA(IPv6)
CFTTL=120                      # TTL 120-86400

# 获取公网 IP 的站点
WANIPSITE="https://ipv4.icanhazip.com"
# WANIPSITE="https://api.ipify.org"
# WANIPSITE="https://ipv4.ip.sb"

# 强制更新（无视本地缓存）
FORCE=false

# 日志文件
LOGFILE="/var/log/cf-ddns.log"
# ============ 配置结束 ============

# 检查依赖
if ! command -v curl >/dev/null 2>&1; then
    echo "错误: 请先安装 curl: apk add curl"
    exit 1
fi

# IPv6 支持
if [ "$CFRECORD_TYPE" = "AAAA" ]; then
    WANIPSITE="https://ipv6.icanhazip.com"
elif [ "$CFRECORD_TYPE" != "A" ]; then
    echo "错误: CFRECORD_TYPE 只能是 A 或 AAAA"
    exit 2
fi

# 参数解析 (Alpine getopts 略有不同)
while getopts "k:u:t:h:z:f:" opt; do
    case $opt in
        k) CFKEY="$OPTARG" ;;
        u) CFUSER="$OPTARG" ;;
        t) CFTOKEN="$OPTARG" ;;
        h) CFRECORD_NAME="$OPTARG" ;;
        z) CFZONE_NAME="$OPTARG" ;;
        f) FORCE="$OPTARG" ;;
        *) echo "用法: $0 [-k api_key] [-u email] [-t token] [-h hostname] [-z zone] [-f true]"; exit 1 ;;
    esac
done

# 验证配置
if [ -n "$CFTOKEN" ]; then
    AUTH_HEADER="Authorization: Bearer $CFTOKEN"
elif [ -n "$CFKEY" ] && [ -n "$CFUSER" ]; then
    AUTH_HEADER="X-Auth-Key: $CFKEY"
else
    echo "错误: 请配置 CFTOKEN (API Token) 或 CFKEY+CFUSER (Global Key)"
    exit 2
fi

if [ -z "$CFZONE_NAME" ] || [ -z "$CFRECORD_NAME" ]; then
    echo "错误: 请配置 CFZONE_NAME 和 CFRECORD_NAME"
    exit 2
fi

# 确保主机名是完整域名
if [ "$CFRECORD_NAME" != "$CFZONE_NAME" ] && [ "${CFRECORD_NAME##*.$CFZONE_NAME}" = "$CFRECORD_NAME" ]; then
    CFRECORD_NAME="$CFRECORD_NAME.$CFZONE_NAME"
    echo "主机名补全为: $CFRECORD_NAME"
fi

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE" 2>/dev/null || echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 获取当前公网 IP
log "获取当前公网 IP..."
WAN_IP=$(curl -s --max-time 10 "$WANIPSITE" 2>/dev/null | tr -d '[:space:]')

if [ -z "$WAN_IP" ]; then
    log "错误: 无法获取公网 IP"
    exit 1
fi

if ! echo "$WAN_IP" | grep -Eq '^[0-9a-fA-F.:]+$'; then
    log "错误: 获取的 IP 格式无效: $WAN_IP"
    exit 1
fi

log "当前公网 IP: $WAN_IP"

# 检查 IP 是否变化
WAN_IP_FILE="/root/.cf-wan_ip_${CFRECORD_NAME}.txt"
OLD_WAN_IP=""
if [ -f "$WAN_IP_FILE" ]; then
    OLD_WAN_IP=$(cat "$WAN_IP_FILE" 2>/dev/null | tr -d '[:space:]')
fi

if [ "$WAN_IP" = "$OLD_WAN_IP" ] && [ "$FORCE" != "true" ]; then
    log "IP 未变化 ($WAN_IP)，跳过更新"
    exit 0
fi

# 获取 Zone ID 和 Record ID
ID_FILE="/root/.cf-id_${CFRECORD_NAME}.txt"
CFZONE_ID=""
CFRECORD_ID=""

if [ -f "$ID_FILE" ]; then
    # 读取缓存的 ID
    CFZONE_ID=$(sed -n '1p' "$ID_FILE" 2>/dev/null | tr -d '[:space:]')
    CFRECORD_ID=$(sed -n '2p' "$ID_FILE" 2>/dev/null | tr -d '[:space:]')
    CACHED_ZONE=$(sed -n '3p' "$ID_FILE" 2>/dev/null | tr -d '[:space:]')
    CACHED_RECORD=$(sed -n '4p' "$ID_FILE" 2>/dev/null | tr -d '[:space:]')
    
    if [ "$CACHED_ZONE" != "$CFZONE_NAME" ] || [ "$CACHED_RECORD" != "$CFRECORD_NAME" ]; then
        log "域名配置变更，重新获取 ID"
        CFZONE_ID=""
        CFRECORD_ID=""
    fi
fi

# 获取 Zone ID
if [ -z "$CFZONE_ID" ]; then
    log "获取 Zone ID for $CFZONE_NAME..."
    
    if [ -n "$CFTOKEN" ]; then
        ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
            -H "Authorization: Bearer $CFTOKEN" \
            -H "Content-Type: application/json")
    else
        ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CFZONE_NAME" \
            -H "X-Auth-Email: $CFUSER" \
            -H "X-Auth-Key: $CFKEY" \
            -H "Content-Type: application/json")
    fi
    
    # Alpine 兼容的 JSON 解析 (不用 grep -P)
    CFZONE_ID=$(echo "$ZONE_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*"name":"'"$CFZONE_NAME"'".*/\1/p' | head -1)
    
    # 如果上面失败，尝试更宽松的模式
    if [ -z "$CFZONE_ID" ]; then
        CFZONE_ID=$(echo "$ZONE_RESPONSE" | sed -n 's/.*"id":"\([a-f0-9]\{32\}\)".*/\1/p' | head -1)
    fi
    
    if [ -z "$CFZONE_ID" ]; then
        log "错误: 无法获取 Zone ID"
        log "响应: $ZONE_RESPONSE"
        exit 1
    fi
    
    log "Zone ID: $CFZONE_ID"
fi

# 获取 Record ID
if [ -z "$CFRECORD_ID" ]; then
    log "获取 Record ID for $CFRECORD_NAME..."
    
    if [ -n "$CFTOKEN" ]; then
        RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME&type=$CFRECORD_TYPE" \
            -H "Authorization: Bearer $CFTOKEN" \
            -H "Content-Type: application/json")
    else
        RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records?name=$CFRECORD_NAME&type=$CFRECORD_TYPE" \
            -H "X-Auth-Email: $CFUSER" \
            -H "X-Auth-Key: $CFKEY" \
            -H "Content-Type: application/json")
    fi
    
    # Alpine 兼容的解析
    CFRECORD_ID=$(echo "$RECORD_RESPONSE" | sed -n 's/.*"id":"\([^"]*\)".*"name":"'"$CFRECORD_NAME"'".*/\1/p' | head -1)
    
    if [ -z "$CFRECORD_ID" ]; then
        # 尝试提取第一个 id 字段（32位十六进制）
        CFRECORD_ID=$(echo "$RECORD_RESPONSE" | sed -n 's/.*"id":"\([a-f0-9]\{32\}\)".*/\1/p' | head -1)
    fi
    
    if [ -z "$CFRECORD_ID" ]; then
        log "错误: 无法获取 Record ID，记录可能不存在"
        log "响应: $RECORD_RESPONSE"
        exit 1
    fi
    
    log "Record ID: $CFRECORD_ID"
    
    # 保存 ID 缓存
    echo "$CFZONE_ID" > "$ID_FILE"
    echo "$CFRECORD_ID" >> "$ID_FILE"
    echo "$CFZONE_NAME" >> "$ID_FILE"
    echo "$CFRECORD_NAME" >> "$ID_FILE"
fi

# 更新 DNS 记录
log "更新 DNS 记录 $CFRECORD_NAME -> $WAN_IP"

UPDATE_DATA="{\"type\":\"$CFRECORD_TYPE\",\"name\":\"$CFRECORD_NAME\",\"content\":\"$WAN_IP\",\"ttl\":$CFTTL,\"proxied\":false}"

if [ -n "$CFTOKEN" ]; then
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
        -H "Authorization: Bearer $CFTOKEN" \
        -H "Content-Type: application/json" \
        --data "$UPDATE_DATA")
else
    UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CFZONE_ID/dns_records/$CFRECORD_ID" \
        -H "X-Auth-Email: $CFUSER" \
        -H "X-Auth-Key: $CFKEY" \
        -H "Content-Type: application/json" \
        --data "$UPDATE_DATA")
fi

# 检查是否成功 (Alpine 兼容)
if echo "$UPDATE_RESPONSE" | grep -q '"success":true'; then
    log "✓ DNS 更新成功: $CFRECORD_NAME -> $WAN_IP"
    echo "$WAN_IP" > "$WAN_IP_FILE"
    exit 0
else
    log "✗ DNS 更新失败"
    log "响应: $UPDATE_RESPONSE"
    exit 1
fi
