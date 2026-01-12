#!/bin/bash
# test-notification.sh - Test notification tool / 通知测试工具
# Usage: ./test-notification.sh [running|input|done|click|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Source dependencies / 加载依赖
source "${BASE_DIR}/config.sh"
source "${BASE_DIR}/lib/pwsh.sh"

load_all_config

# Detect language (use inherited LANG_CODE if available)
detect_lang() {
    local lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    case "$lang" in
        zh_*|ja_*|ko_*) echo "zh"; return ;;
    esac
    if command -v powershell.exe &>/dev/null; then
        local win_locale
        win_locale=$(powershell.exe -NoProfile -Command '(Get-WinSystemLocale).Name' 2>/dev/null | tr -d '\r')
        case "$win_locale" in
            zh-*|ja-*|ko-*) echo "zh"; return ;;
        esac
    fi
    echo "en"
}

if [[ -z "$LANG_CODE" ]]; then
    LANG_CODE=$(detect_lang)
fi

# Messages
if [[ "$LANG_CODE" == "zh" ]]; then
    MSG_SENDING="发送 %s 通知..."
    MSG_DONE="完成！"
    MSG_TESTING_CLICK="测试点击跳转..."
    MSG_CLICK_HINT="点击通知按钮测试窗口聚焦。"
    MSG_CLEANUP="清理测试通知..."
    MSG_ALL_TESTS="运行所有通知测试"
    MSG_ALL_DONE="所有测试完成！"
    MSG_CLEANUP_HINT="运行 '%s cleanup' 清理测试通知。"
    MSG_UNKNOWN="未知命令："
else
    MSG_SENDING="Sending %s notification..."
    MSG_DONE="Done!"
    MSG_TESTING_CLICK="Testing click-to-focus..."
    MSG_CLICK_HINT="Click the notification button to test window focus."
    MSG_CLEANUP="Cleaning up test notifications..."
    MSG_ALL_TESTS="Running all notification tests"
    MSG_ALL_DONE="All tests completed!"
    MSG_CLEANUP_HINT="Run '%s cleanup' to remove test notifications."
    MSG_UNKNOWN="Unknown command:"
fi

# Get PowerShell and script paths / 获取 PowerShell 和脚本路径
PWSH=$(find_pwsh) || { echo "Error: PowerShell not found"; exit 1; }
PS_SCRIPT="${BASE_DIR}/ps/send-toast.ps1"
WIN_PS_SCRIPT=$(wslpath -w "$PS_SCRIPT" 2>/dev/null || echo "$PS_SCRIPT")

TEST_SESSION_ID="test-$$"
TEST_TITLE="Test Notification"
TEST_TMUX_INFO="%0:0"

send_test() {
    local type="$1"
    local body="$2"
    local extra_args=("${@:3}")

    printf "$MSG_SENDING\n" "$type"

    "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" \
        -Type "$type" \
        -SessionId "$TEST_SESSION_ID" \
        -Title "$TEST_TITLE" \
        -Body "$body" \
        -AppLogo "$CC_NOTIFY_APP_LOGO" \
        -TmuxInfo "$TEST_TMUX_INFO" \
        "${extra_args[@]}" \
        2>/dev/null

    echo "  $MSG_DONE"
}

test_running() {
    send_test "running" "[Running: 5 min] Test task running..." \
        -SoundPath "$CC_NOTIFY_RUNNING_SOUND" \
        -SoundRepeat "$CC_NOTIFY_RUNNING_SOUND_REPEAT" \
        -UpdateSame "1"
}

test_input() {
    send_test "need_input" "Permission/input required - Test" \
        -SoundPath "$CC_NOTIFY_NEED_INPUT_SOUND" \
        -SoundRepeat "$CC_NOTIFY_NEED_INPUT_SOUND_REPEAT"
}

test_done() {
    send_test "done" "[Total: 10 min] Test task completed!" \
        -SoundPath "$CC_NOTIFY_DONE_SOUND" \
        -SoundRepeat "$CC_NOTIFY_DONE_SOUND_REPEAT" \
        -HeroImage "$CC_NOTIFY_HERO_IMAGE"
}

test_click() {
    echo "$MSG_TESTING_CLICK"
    echo "$MSG_CLICK_HINT"

    # Get current window handle / 获取当前窗口句柄
    local hwnd
    hwnd=$("$PWSH" -NoProfile -Command '
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); }
"@
[Win32]::GetForegroundWindow()
' 2>/dev/null | tr -d '\r')

    local pane_id
    pane_id=$(tmux display-message -p '#{pane_id}' 2>/dev/null || echo "%0")

    TEST_TMUX_INFO="${pane_id}:${hwnd}"

    send_test "need_input" "Click the button to test focus!" \
        -SoundPath "$CC_NOTIFY_NEED_INPUT_SOUND" \
        -SoundRepeat "1"
}

cleanup() {
    echo "$MSG_CLEANUP"
    "$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_SCRIPT" \
        -Type "remove" \
        -SessionId "$TEST_SESSION_ID" \
        2>/dev/null || true
    echo "  $MSG_DONE"
}

show_help() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  running   Test 'running' notification (periodic progress)"
    echo "  input     Test 'need_input' notification (permission request)"
    echo "  done      Test 'done' notification (task completion)"
    echo "  click     Test click-to-focus functionality"
    echo "  all       Run all tests"
    echo "  cleanup   Remove test notifications"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all        # Run all tests"
    echo "  $0 done       # Test completion notification"
    echo ""
}

case "${1:-all}" in
    running)
        test_running
        ;;
    input)
        test_input
        ;;
    done)
        test_done
        ;;
    click)
        test_click
        ;;
    all)
        echo "=== $MSG_ALL_TESTS ==="
        echo ""
        test_running
        sleep 2
        test_input
        sleep 2
        test_done
        echo ""
        echo "$MSG_ALL_DONE"
        printf "$MSG_CLEANUP_HINT\n" "$0"
        ;;
    cleanup)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "$MSG_UNKNOWN $1"
        show_help
        exit 1
        ;;
esac
