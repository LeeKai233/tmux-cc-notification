#!/bin/bash
# pwsh.sh - PowerShell detection module / PowerShell 检测模块
# Auto-detect available PowerShell installation
# SEC-2026-0112-0409 M2：添加执行策略配置支持
# SEC-2026-0112-0409 L2：支持用户自定义 PowerShell 路径

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/log.sh"

# Cache for PowerShell path / PowerShell 路径缓存
_CC_NOTIFY_PWSH_PATH=""

# SEC-2026-0112-0409 M2：获取配置的执行策略
# 仅允许安全的策略值，默认 RemoteSigned
get_execution_policy() {
    local policy="${CC_NOTIFY_PWSH_EXECUTION_POLICY:-RemoteSigned}"
    case "$policy" in
        AllSigned|RemoteSigned|Bypass)
            echo "$policy"
            ;;
        *)
            echo "RemoteSigned"
            ;;
    esac
}

# Find PowerShell executable / 查找 PowerShell 可执行文件
# Returns: path to pwsh.exe or empty string
# SEC-2026-0112-0409 L2：优先使用用户配置的路径
find_pwsh() {
    # Return cached path if available / 如果有缓存则返回
    if [[ -n "$_CC_NOTIFY_PWSH_PATH" ]]; then
        echo "$_CC_NOTIFY_PWSH_PATH"
        return 0
    fi

    # SEC-2026-0112-0409 L2：优先使用用户配置的路径
    if [[ -n "$CC_NOTIFY_PWSH_PATH" ]]; then
        if [[ -x "$CC_NOTIFY_PWSH_PATH" ]]; then
            _CC_NOTIFY_PWSH_PATH="$CC_NOTIFY_PWSH_PATH"
            echo "$CC_NOTIFY_PWSH_PATH"
            return 0
        else
            log_warn "Configured PWSH path not executable: $CC_NOTIFY_PWSH_PATH"
            # 继续尝试自动探测
        fi
    fi

    # Search candidates in order of preference / 按优先级搜索
    local candidates=(
        "/mnt/c/Program Files/PowerShell/7/pwsh.exe"
        "/mnt/c/Program Files/PowerShell/7-preview/pwsh.exe"
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    )

    for p in "${candidates[@]}"; do
        if [[ -x "$p" ]]; then
            _CC_NOTIFY_PWSH_PATH="$p"
            echo "$p"
            return 0
        fi
    done

    return 1
}

# Get PowerShell path or exit with error / 获取 PowerShell 路径或报错退出
require_pwsh() {
    local pwsh
    pwsh=$(find_pwsh)
    if [[ -z "$pwsh" ]]; then
        echo "ERROR: PowerShell not found. Please install PowerShell 7." >&2
        return 1
    fi
    echo "$pwsh"
}

# Check if PowerShell is available / 检查 PowerShell 是否可用
has_pwsh() {
    find_pwsh &>/dev/null
}
