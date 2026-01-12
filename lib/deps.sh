#!/bin/bash
# deps.sh - Dependency checker / 依赖检查模块

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/pwsh.sh"

# Detect language (use inherited LANG_CODE if available)
# Also check Windows locale via PowerShell in WSL environment
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
    MSG_DEP_CHECK="依赖检查"
    MSG_NOT_FOUND="未找到"
    MSG_INSTALL_WITH="安装命令："
    MSG_INSTALLED="已安装"
    MSG_AVAILABLE="可用"
    MSG_REQUIRES_WSL="需要 WSL 环境"
else
    MSG_DEP_CHECK="Dependency Check"
    MSG_NOT_FOUND="NOT FOUND"
    MSG_INSTALL_WITH="Install with:"
    MSG_INSTALLED="installed"
    MSG_AVAILABLE="available"
    MSG_REQUIRES_WSL="Requires WSL environment"
fi

# Check if a command exists
has_command() {
    command -v "$1" &>/dev/null
}

# Check all dependencies, return missing ones
check_dependencies() {
    local missing=()
    has_command jq || missing+=("jq")
    has_command tmux || missing+=("tmux")
    has_pwsh || missing+=("PowerShell 7")
    has_command wslpath || missing+=("wslpath (WSL)")
    echo "${missing[*]}"
    [[ ${#missing[@]} -eq 0 ]]
}

# Check BurntToast PowerShell module
check_burnttoast() {
    local pwsh
    pwsh=$(find_pwsh) || return 1
    "$pwsh" -NoProfile -Command '
        if (Get-Module -ListAvailable -Name BurntToast) { exit 0 } else { exit 1 }
    ' 2>/dev/null
}

# Print dependency status
print_dependency_status() {
    echo "=== $MSG_DEP_CHECK ==="
    echo ""

    # jq
    if has_command jq; then
        echo "[✓] jq: $(jq --version 2>/dev/null || echo "$MSG_INSTALLED")"
    else
        echo "[✗] jq: $MSG_NOT_FOUND - $MSG_INSTALL_WITH sudo apt install jq"
    fi

    # tmux
    if has_command tmux; then
        echo "[✓] tmux: $(tmux -V 2>/dev/null || echo "$MSG_INSTALLED")"
    else
        echo "[✗] tmux: $MSG_NOT_FOUND - $MSG_INSTALL_WITH sudo apt install tmux"
    fi

    # PowerShell
    local pwsh
    if pwsh=$(find_pwsh); then
        local ver
        ver=$("$pwsh" -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null | tr -d '\r')
        echo "[✓] PowerShell: $ver"
    else
        echo "[✗] PowerShell: $MSG_NOT_FOUND - $MSG_INSTALL_WITH https://aka.ms/powershell"
    fi

    # BurntToast
    if check_burnttoast; then
        echo "[✓] BurntToast: $MSG_INSTALLED"
    else
        echo "[✗] BurntToast: $MSG_NOT_FOUND - $MSG_INSTALL_WITH Install-Module -Name BurntToast"
    fi

    # wslpath
    if has_command wslpath; then
        echo "[✓] wslpath: $MSG_AVAILABLE"
    else
        echo "[✗] wslpath: $MSG_NOT_FOUND - $MSG_REQUIRES_WSL"
    fi

    echo ""
}

# Check if all dependencies are met
all_dependencies_met() {
    local missing
    missing=$(check_dependencies)
    [[ -z "$missing" ]] && check_burnttoast
}
