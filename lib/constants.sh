#!/bin/bash
# constants.sh - Centralized constants / 集中常量定义
# All configurable defaults and version info

# Version / 版本
export CC_NOTIFY_VERSION="1.0.0"

# State management / 状态管理
# Use XDG cache dir for persistence across reboots
export STATE_BASE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cc-notify"

# Default intervals / 默认间隔
export DEFAULT_CHECK_INTERVAL=30           # Background monitor check interval (seconds)
export DEFAULT_RUNNING_INTERVAL=5          # Periodic notification interval (minutes)
export DEFAULT_PROMPT_MAX_CHARS=60         # Max chars for user prompt display

# Default sounds (Windows paths) / 默认声音
export DEFAULT_SOUND_RUNNING="C:\\Windows\\Media\\chimes.wav"
export DEFAULT_SOUND_INPUT="C:\\Windows\\Media\\notify.wav"
export DEFAULT_SOUND_DONE="C:\\Windows\\Media\\tada.wav"
