#!/bin/bash
# log.sh - Optional debug logging / 可选调试日志
# Enable by setting CC_NOTIFY_DEBUG=1
# SEC-2026-0112-0409 L1 修复：日志安全化

CC_NOTIFY_DEBUG="${CC_NOTIFY_DEBUG:-0}"
# Use XDG state dir for persistent logs
_CC_NOTIFY_LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-notify"
CC_NOTIFY_LOG_FILE="${CC_NOTIFY_LOG_FILE:-$_CC_NOTIFY_LOG_DIR/debug.log}"

# 日志初始化标志
_CC_NOTIFY_LOG_INITIALIZED=0

# SEC-2026-0112-0409 L1：初始化日志文件并设置权限
init_log() {
    [[ "$CC_NOTIFY_DEBUG" == "1" ]] || return 0
    [[ "$_CC_NOTIFY_LOG_INITIALIZED" == "1" ]] && return 0

    # 确保日志目录存在
    local log_dir
    log_dir=$(dirname "$CC_NOTIFY_LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null
        chmod 700 "$log_dir" 2>/dev/null
    fi

    # 创建日志文件并设置权限 0600
    touch "$CC_NOTIFY_LOG_FILE" 2>/dev/null
    chmod 600 "$CC_NOTIFY_LOG_FILE" 2>/dev/null

    _CC_NOTIFY_LOG_INITIALIZED=1
}

# SEC-2026-0112-0409 L1：日志消息脱敏
sanitize_log_msg() {
    local msg="$1"
    local max_len="${2:-1024}"

    # 脱敏敏感字段
    msg="${msg//session_id=*/session_id=[REDACTED]}"
    msg="${msg//SessionId */SessionId [REDACTED]}"
    msg="${msg//session=*/session=[REDACTED]}"

    # 控制字符归一化为空格
    msg=$(printf '%s' "$msg" | tr '\n\r\t' '   ')

    # 长度限制
    if [[ ${#msg} -gt $max_len ]]; then
        msg="${msg:0:$max_len}...[TRUNCATED]"
    fi

    printf '%s' "$msg"
}

# Log debug message (only when debug enabled) / 记录调试信息
log_debug() {
    [[ "$CC_NOTIFY_DEBUG" == "1" ]] || return 0
    init_log
    local msg
    msg=$(sanitize_log_msg "$*")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $msg" >> "$CC_NOTIFY_LOG_FILE"
}

# Log info message / 记录信息
log_info() {
    [[ "$CC_NOTIFY_DEBUG" == "1" ]] || return 0
    init_log
    local msg
    msg=$(sanitize_log_msg "$*")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $msg" >> "$CC_NOTIFY_LOG_FILE"
}

# Log error message / 记录错误信息
log_error() {
    [[ "$CC_NOTIFY_DEBUG" == "1" ]] || return 0
    init_log
    local msg
    msg=$(sanitize_log_msg "$*")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $msg" >> "$CC_NOTIFY_LOG_FILE"
}

# Log warning message / 记录警告信息
log_warn() {
    [[ "$CC_NOTIFY_DEBUG" == "1" ]] || return 0
    init_log
    local msg
    msg=$(sanitize_log_msg "$*")
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $msg" >> "$CC_NOTIFY_LOG_FILE"
}

# SEC-2026-0112-0409 L4：执行命令，debug 模式下捕获 stderr
run_quiet() {
    if [[ "$CC_NOTIFY_DEBUG" == "1" ]]; then
        local stderr_output
        stderr_output=$("$@" 2>&1 >/dev/null)
        local exit_code=$?
        if [[ -n "$stderr_output" && $exit_code -ne 0 ]]; then
            log_debug "Command failed: $1 (exit=$exit_code): $stderr_output"
        fi
        return $exit_code
    else
        "$@" 2>/dev/null
    fi
}
