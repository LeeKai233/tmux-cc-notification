#!/bin/bash
# on-tool-use.sh - PreToolUse hook
# Called on tool use: clear waiting input state, resume periodic timer
# 工具调用时：清除等待输入状态，恢复周期计时
# SEC-2026-0112-0409 H2 修复：输入校验

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load dependencies / 加载依赖
source "${BASE_DIR}/lib/state.sh"
source "${BASE_DIR}/lib/json.sh"
source "${BASE_DIR}/lib/log.sh"

# Read hook input / 读取 hook 输入
INPUT=$(cat)

# SEC-2026-0112-0409 M3：fail-fast JSON 校验
if ! validate_json "$INPUT"; then
    exit 0
fi

# Parse session_id / 解析 session_id
SESSION_ID=$(parse_session_id "$INPUT")

# 校验失败时退出
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# If in waiting state, clear it (user has completed input) / 如果在等待状态，清除它
if is_waiting_input "$SESSION_ID"; then
    clear_waiting_input "$SESSION_ID"
    log_debug "Cleared waiting state: session=$SESSION_ID"
fi
