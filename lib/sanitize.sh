#!/usr/bin/env bash
# lib/sanitize.sh - 输入净化与安全编码函数
# SEC-2026-0112-0409 H1 修复：命令/表达式注入防护

# 移除控制字符，限制长度（用于展示层）
# 用于在显示前净化用户输入
sanitize_display() {
    local input="$1"
    local max_len="${2:-200}"

    # 移除控制字符（保留换行转为空格）
    local sanitized
    sanitized=$(printf '%s' "$input" | tr '\n\r\t' '   ' | tr -d '\000-\037')

    # 限制长度
    if [[ ${#sanitized} -gt $max_len ]]; then
        sanitized="${sanitized:0:$max_len}..."
    fi

    printf '%s' "$sanitized"
}

# Base64 编码（UTF-8 安全）
# 用于安全传递数据到 PowerShell，避免表达式求值
to_base64() {
    local input="$1"
    printf '%s' "$input" | base64 -w 0
}

# 验证 Base64 格式（仅 A-Za-z0-9+/=）
validate_base64() {
    local input="$1"
    [[ "$input" =~ ^[A-Za-z0-9+/=]*$ ]]
}

# 移除 shell 危险字符（备用方案，不推荐单独使用）
# 推荐使用 Base64 编码方案
sanitize_for_shell() {
    local input="$1"
    # 移除危险字符
    local sanitized="$input"
    sanitized="${sanitized//\`/}"
    sanitized="${sanitized//\$/}"
    sanitized="${sanitized//\(/}"
    sanitized="${sanitized//\)/}"
    sanitized="${sanitized//|/}"
    sanitized="${sanitized//;/}"
    sanitized="${sanitized//&/}"
    sanitized="${sanitized//>/}"
    sanitized="${sanitized//</}"
    sanitized="${sanitized//\"/}"
    sanitized="${sanitized//\'/}"
    echo "$sanitized"
}

# 安全编码用于 PowerShell 传参
# 组合净化 + Base64 编码
safe_encode_for_pwsh() {
    local input="$1"
    local max_len="${2:-200}"

    # 先净化展示层
    local sanitized
    sanitized=$(sanitize_display "$input" "$max_len")

    # 再 Base64 编码
    to_base64 "$sanitized"
}
