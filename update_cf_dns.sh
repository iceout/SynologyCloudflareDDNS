#!/bin/bash
set -e

# 定义域名配置数组
# 每个元素包含：域名、IPv4记录ID、IPv6记录ID
declare -A domains=(
    ["example.com"]="v4_record_id:v6_record_id"
    ["sub.example.com"]="v4_record_id:v6_record_id"
    # 添加更多域名...
)

ZONEID="your_zone_id"
APITOKEN="your_api_token"

# 获取本机 IP
CURRENT_IPV4=$(curl -4s https://ifconfig.co)
CURRENT_IPV6=$(curl -6s https://ifconfig.co)

# 检查并更新 DNS 记录的函数
update_dns_record() {
    local domain=$1
    local record_id=$2
    local current_ip=$3
    local record_type=$4

    # 获取 Cloudflare 上记录的 IP
    CF_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${APITOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result.content')

    if [ "$current_ip" != "$CF_IP" ]; then
        echo "${record_type} 地址不匹配，正在更新 ${domain} 的 DNS 记录..."

        UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONEID}/dns_records/${record_id}" \
            -H "Authorization: Bearer ${APITOKEN}" \
            -H "Content-Type: application/json" \
            --data "{\"id\":\"${record_id}\",\"type\":\"${record_type}\",\"name\":\"${domain}\",\"content\":\"${current_ip}\"}")

        if echo "$UPDATE_RESULT" | jq -e '.success' > /dev/null; then
            echo "${domain} 的 ${record_type} 记录更新成功。新 IP: ${current_ip}"
        else
            echo "${domain} 的 ${record_type} 记录更新失败。错误信息:"
            echo "$UPDATE_RESULT" | jq '.errors'
        fi
    else
        echo "${domain} 的 ${record_type} 地址匹配。无需更新。"
    fi
}

# 遍历所有域名并更新
for domain in "${!domains[@]}"; do
    # 分割 IPv4 和 IPv6 的记录 ID
    IFS=':' read -r ipv4_record_id ipv6_record_id <<< "${domains[$domain]}"

    echo "处理域名: $domain"

    # 如果有 IPv4 记录 ID，则更新 IPv4
    if [ -n "$ipv4_record_id" ] && [ -n "$CURRENT_IPV4" ]; then
        update_dns_record "$domain" "$ipv4_record_id" "$CURRENT_IPV4" "A"
    fi

    # 如果有 IPv6 记录 ID，则更新 IPv6
    if [ -n "$ipv6_record_id" ] && [ -n "$CURRENT_IPV6" ]; then
        update_dns_record "$domain" "$ipv6_record_id" "$CURRENT_IPV6" "AAAA"
    fi

    echo "----------------------------------------"
done
