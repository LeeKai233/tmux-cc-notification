#!/bin/bash
# json.sh - JSON parsing helpers / JSON 解析辅助函数
# Provides consistent JSON parsing across all hooks
# SEC-2026-0112-0409 M3 修复：强化 JSON 校验，fail-fast

SCRIPT_DIR_JSON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR_JSON}/validate.sh" 2>/dev/null || true
source "${SCRIPT_DIR_JSON}/log.sh" 2>/dev/null || true

# Validate JSON structure / 校验 JSON 结构
# SEC-2026-0112-0409 M3：强制校验，jq 不可用时使用严格 fallback
# SEC-2026-0112-0409 L4：debug 模式下记录解析错误
validate_json() {
    local input="$1"
    if command -v jq &>/dev/null; then
        local jq_err
        if [[ "$CC_NOTIFY_DEBUG" == "1" ]]; then
            jq_err=$(echo "$input" | jq -e . 2>&1 >/dev/null)
            local ret=$?
            [[ $ret -ne 0 && -n "$jq_err" ]] && log_debug "JSON validation failed: $jq_err"
            return $ret
        else
            echo "$input" | jq -e . >/dev/null 2>&1
            return $?
        fi
    fi
    # 严格 fallback：必须以 { 开头，以 } 结尾，且包含引号
    [[ "$input" == "{"*"}" ]] && [[ "$input" == *'"'* ]]
}

# Parse session_id from JSON input / 从 JSON 输入解析 session_id
# SEC-2026-0112-0409 M3：解析前强制校验 JSON，失败时返回错误
parse_session_id() {
    local input="$1"
    local session_id

    # 强制校验 JSON 结构
    if ! validate_json "$input"; then
        echo "ERROR: Invalid JSON input" >&2
        return 1
    fi

    if command -v jq &>/dev/null; then
        session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
    else
        # fallback：提取后立即校验格式
        session_id=$(echo "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | \
            sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    fi

    # 校验 session_id 格式
    if [[ -n "$session_id" ]]; then
        validate_session_id "$session_id" || return 1
    else
        echo ""
    fi
}

# Parse prompt from JSON input / 从 JSON 输入解析 prompt
parse_prompt() {
    local input="$1"

    if command -v jq &>/dev/null; then
        echo "$input" | jq -r '.prompt // empty' 2>/dev/null
    else
        echo "$input" | grep -o '"prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | \
            sed 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
    fi
}

# Parse any field from JSON input / 从 JSON 输入解析任意字段
parse_json_field() {
    local input="$1"
    local field="$2"

    if command -v jq &>/dev/null; then
        echo "$input" | jq -r ".${field} // empty" 2>/dev/null
    else
        echo "$input" | grep -o "\"${field}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | \
            sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/"
    fi
}
