#!/usr/bin/env bats
# state.bats - Tests for lib/state.sh

load 'test_helper'

# get_state_dir tests

@test "get_state_dir returns correct path" {
    run get_state_dir "test-session"
    [ "$status" -eq 0 ]
    [ "$output" = "$STATE_BASE_DIR/test-session" ]
}

@test "get_state_dir rejects invalid session_id" {
    run get_state_dir "../bad"
    [ "$status" -eq 1 ]
}

@test "get_state_dir rejects empty session_id" {
    run get_state_dir ""
    [ "$status" -eq 1 ]
}

# init_state tests

@test "init_state creates session directory" {
    run init_state "test-session"
    [ "$status" -eq 0 ]
    [ -d "$STATE_BASE_DIR/test-session" ]
}

@test "init_state creates base directory if missing" {
    rm -rf "$STATE_BASE_DIR"
    run init_state "test-session"
    [ "$status" -eq 0 ]
    [ -d "$STATE_BASE_DIR" ]
    [ -d "$STATE_BASE_DIR/test-session" ]
}

@test "init_state sets correct permissions on session dir" {
    init_state "perm-test"
    perms=$(stat -c %a "$STATE_BASE_DIR/perm-test")
    [ "$perms" = "700" ]
}

@test "init_state sets correct permissions on base dir" {
    rm -rf "$STATE_BASE_DIR"
    init_state "test-session"
    perms=$(stat -c %a "$STATE_BASE_DIR")
    [ "$perms" = "700" ]
}

# set_task_start / get_task_start_time tests

@test "set_task_start records timestamp" {
    set_task_start "test-session" "test prompt"
    [ -f "$STATE_BASE_DIR/test-session/task-start-time" ]
    timestamp=$(cat "$STATE_BASE_DIR/test-session/task-start-time")
    [[ "$timestamp" =~ ^[0-9]+$ ]]
}

@test "get_task_start_time retrieves timestamp" {
    set_task_start "test-session" "test"
    run get_task_start_time "test-session"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "get_task_start_time returns 0 for missing session" {
    run get_task_start_time "nonexistent"
    [ "$output" = "0" ]
}

# set_task_start / get_user_prompt tests

@test "set_task_start records user prompt" {
    set_task_start "test-session" "my test prompt"
    [ -f "$STATE_BASE_DIR/test-session/user-prompt" ]
}

@test "get_user_prompt retrieves stored prompt" {
    set_task_start "test-session" "my test prompt"
    result=$(get_user_prompt "test-session")
    # Note: set_task_start adds trailing space due to newline->space conversion
    [[ "$result" == "my test prompt"* ]]
}

@test "set_task_start truncates long prompts" {
    local long_prompt=$(printf 'a%.0s' {1..100})
    CC_NOTIFY_PROMPT_MAX_CHARS=60 set_task_start "test-session" "$long_prompt"
    prompt=$(get_user_prompt "test-session")
    # 60 chars + "..." + trailing space = 64
    [ ${#prompt} -ge 63 ]
    [ ${#prompt} -le 64 ]
}

@test "set_task_start converts newlines to spaces" {
    set_task_start "test-session" $'line1\nline2\nline3'
    result=$(get_user_prompt "test-session")
    [[ "$result" != *$'\n'* ]]
    [[ "$result" == *"line1"* ]]
    [[ "$result" == *"line2"* ]]
}

# cleanup_state tests

@test "cleanup_state removes session directory" {
    init_state "test-session"
    [ -d "$STATE_BASE_DIR/test-session" ]
    cleanup_state "test-session"
    [ ! -d "$STATE_BASE_DIR/test-session" ]
}

@test "cleanup_state handles nonexistent session" {
    run cleanup_state "nonexistent"
    # Should not error
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# waiting_input state tests

@test "set_waiting_input creates marker file" {
    init_state "test-session"
    set_waiting_input "test-session"
    [ -f "$STATE_BASE_DIR/test-session/waiting-input" ]
}

@test "is_waiting_input returns true when waiting" {
    init_state "test-session"
    set_waiting_input "test-session"
    run is_waiting_input "test-session"
    [ "$status" -eq 0 ]
}

@test "is_waiting_input returns false when not waiting" {
    init_state "test-session"
    run is_waiting_input "test-session"
    [ "$status" -eq 1 ]
}

@test "clear_waiting_input removes marker file" {
    init_state "test-session"
    set_waiting_input "test-session"
    clear_waiting_input "test-session"
    [ ! -f "$STATE_BASE_DIR/test-session/waiting-input" ]
}

@test "clear_waiting_input resets periodic timer" {
    init_state "test-session"
    atomic_write "$STATE_BASE_DIR/test-session/last-periodic-time" "1000"
    clear_waiting_input "test-session"
    new_time=$(cat "$STATE_BASE_DIR/test-session/last-periodic-time")
    [ "$new_time" -gt 1000 ]
}

# is_task_running tests

@test "is_task_running returns true when task started" {
    set_task_start "test-session" "test"
    run is_task_running "test-session"
    [ "$status" -eq 0 ]
}

@test "is_task_running returns false when no task" {
    init_state "test-session"
    run is_task_running "test-session"
    [ "$status" -eq 1 ]
}

# monitor_pid tests

@test "set_monitor_pid stores PID" {
    init_state "test-session"
    set_monitor_pid "test-session" "12345"
    [ -f "$STATE_BASE_DIR/test-session/monitor.pid" ]
    [ "$(cat "$STATE_BASE_DIR/test-session/monitor.pid")" = "12345" ]
}

@test "get_monitor_pid retrieves PID" {
    init_state "test-session"
    set_monitor_pid "test-session" "12345"
    run get_monitor_pid "test-session"
    [ "$output" = "12345" ]
}

@test "get_monitor_pid returns empty for missing" {
    init_state "test-session"
    run get_monitor_pid "test-session"
    [ "$output" = "" ]
}

# Session isolation tests

@test "sessions are isolated from each other" {
    set_task_start "session-a" "prompt a"
    set_task_start "session-b" "prompt b"

    prompt_a=$(get_user_prompt "session-a")
    prompt_b=$(get_user_prompt "session-b")

    [[ "$prompt_a" == "prompt a"* ]]
    [[ "$prompt_b" == "prompt b"* ]]
}

@test "cleanup one session does not affect others" {
    set_task_start "session-a" "prompt a"
    set_task_start "session-b" "prompt b"

    cleanup_state "session-a"

    [ ! -d "$STATE_BASE_DIR/session-a" ]
    [ -d "$STATE_BASE_DIR/session-b" ]
    prompt_b=$(get_user_prompt "session-b")
    [[ "$prompt_b" == "prompt b"* ]]
}

# get_elapsed_minutes tests

@test "get_elapsed_minutes calculates correctly" {
    init_state "test-session"
    # Set start time to 5 minutes ago
    local five_min_ago=$(($(date +%s) - 300))
    atomic_write "$STATE_BASE_DIR/test-session/task-start-time" "$five_min_ago"

    run get_elapsed_minutes "test-session"
    [ "$status" -eq 0 ]
    [ "$output" -ge 4 ]
    [ "$output" -le 6 ]
}
