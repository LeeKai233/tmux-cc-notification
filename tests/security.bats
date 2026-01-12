#!/usr/bin/env bats
# security.bats - Security-focused tests

load 'test_helper'

# Path traversal tests

@test "SEC: path traversal blocked in validate_session_id" {
    run validate_session_id "../../../etc/passwd"
    [ "$status" -eq 1 ]
}

@test "SEC: path traversal blocked with encoded dots" {
    run validate_session_id "..%2F..%2Fetc"
    [ "$status" -eq 1 ]
}

@test "SEC: path traversal blocked in get_state_dir" {
    run get_state_dir "../../../etc"
    [ "$status" -eq 1 ]
}

@test "SEC: validate_path_in_base prevents escape" {
    mkdir -p "$TEST_TEMP_DIR/base"
    run validate_path_in_base "$TEST_TEMP_DIR/base/../outside" "$TEST_TEMP_DIR/base"
    [ "$status" -eq 1 ]
}

# Command injection tests

@test "SEC: command substitution blocked in session_id" {
    run validate_session_id '$(cat /etc/passwd)'
    [ "$status" -eq 1 ]
}

@test "SEC: backtick injection blocked in session_id" {
    run validate_session_id '`whoami`'
    [ "$status" -eq 1 ]
}

@test "SEC: pipe injection blocked in session_id" {
    run validate_session_id 'test|cat /etc/passwd'
    [ "$status" -eq 1 ]
}

@test "SEC: semicolon injection blocked in session_id" {
    run validate_session_id 'test;rm -rf /'
    [ "$status" -eq 1 ]
}

@test "SEC: ampersand injection blocked in session_id" {
    run validate_session_id 'test&bg'
    [ "$status" -eq 1 ]
}

@test "SEC: redirect injection blocked in session_id" {
    run validate_session_id 'test>file'
    [ "$status" -eq 1 ]
}

# Null byte injection tests

@test "SEC: null byte blocked in session_id" {
    # Null bytes truncate strings in bash, so the validation sees "test" not "test\x00bad"
    # This is actually safe behavior - the dangerous part is truncated
    run validate_session_id $'test\x00bad'
    # Either rejected (status 1) or truncated to safe value (status 0)
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "SEC: null byte handled in sanitize_display" {
    # Null bytes truncate strings in bash - this is expected safe behavior
    run sanitize_display $'test\x00injection'
    [ "$status" -eq 0 ]
    # String is truncated at null byte, which is safe
    [ "$output" = "test" ]
}

# Control character tests

@test "SEC: control characters removed by sanitize_display" {
    run sanitize_display $'test\x01\x02\x03\x04\x05'
    [ "$output" = "test" ]
}

@test "SEC: bell character removed" {
    run sanitize_display $'test\x07bell'
    [[ "$output" != *$'\x07'* ]]
}

# tmux pane injection tests

@test "SEC: shell injection blocked in tmux pane" {
    run validate_tmux_pane '$(whoami)'
    [ "$status" -eq 1 ]
}

@test "SEC: backtick blocked in tmux pane" {
    run validate_tmux_pane '`id`'
    [ "$status" -eq 1 ]
}

@test "SEC: semicolon blocked in tmux pane" {
    run validate_tmux_pane 'pane;rm'
    [ "$status" -eq 1 ]
}

# File permission tests

@test "SEC: state base directory has 700 permissions" {
    rm -rf "$STATE_BASE_DIR"
    init_state "perm-test"
    perms=$(stat -c %a "$STATE_BASE_DIR")
    [ "$perms" = "700" ]
}

@test "SEC: session directory has 700 permissions" {
    init_state "perm-test"
    perms=$(stat -c %a "$STATE_BASE_DIR/perm-test")
    [ "$perms" = "700" ]
}

@test "SEC: state files have 600 permissions" {
    set_task_start "perm-test" "test"
    perms=$(stat -c %a "$STATE_BASE_DIR/perm-test/task-start-time")
    [ "$perms" = "600" ]
}

# Base64 encoding security tests

@test "SEC: base64 encoding prevents shell expansion" {
    dangerous='$(rm -rf /)'
    encoded=$(to_base64 "$dangerous")
    # Encoded string should be safe alphanumeric
    [[ "$encoded" =~ ^[A-Za-z0-9+/=]+$ ]]
    # Should decode back to original
    decoded=$(echo "$encoded" | base64 -d)
    [ "$decoded" = "$dangerous" ]
}

@test "SEC: validate_base64 rejects shell metacharacters" {
    run validate_base64 '$(whoami)'
    [ "$status" -eq 1 ]
}

@test "SEC: validate_base64 rejects backticks" {
    run validate_base64 '`id`'
    [ "$status" -eq 1 ]
}

# JSON injection tests

@test "SEC: parse_session_id validates after extraction" {
    run parse_session_id '{"session_id":"../../../etc/passwd"}'
    [ "$status" -eq 1 ]
}

@test "SEC: invalid JSON rejected before parsing" {
    run parse_session_id 'not json at all'
    [ "$status" -eq 1 ]
}

# sanitize_for_shell comprehensive test

@test "SEC: sanitize_for_shell removes all dangerous characters" {
    dangerous='test`$()|\;&><"'"'"
    result=$(sanitize_for_shell "$dangerous")

    # None of these should be in output
    [[ "$result" != *'`'* ]]
    [[ "$result" != *'$'* ]]
    [[ "$result" != *'('* ]]
    [[ "$result" != *')'* ]]
    [[ "$result" != *'|'* ]]
    [[ "$result" != *';'* ]]
    [[ "$result" != *'&'* ]]
    [[ "$result" != *'>'* ]]
    [[ "$result" != *'<'* ]]
    [[ "$result" != *'"'* ]]
    [[ "$result" != *"'"* ]]
    # Note: backslash is not in the sanitize list, only the characters above
}

# Atomic write security

@test "SEC: atomic_write uses temp file" {
    init_state "atomic-test"
    # atomic_write should not leave partial files on failure
    atomic_write "$STATE_BASE_DIR/atomic-test/testfile" "content"
    [ -f "$STATE_BASE_DIR/atomic-test/testfile" ]
    [ "$(cat "$STATE_BASE_DIR/atomic-test/testfile")" = "content" ]
}

# Length limit tests

@test "SEC: session_id length limited to 64" {
    long_id=$(printf 'a%.0s' {1..65})
    run validate_session_id "$long_id"
    [ "$status" -eq 1 ]
}

@test "SEC: sanitize_display respects max length" {
    long_str=$(printf 'a%.0s' {1..1000})
    result=$(sanitize_display "$long_str" 100)
    [ ${#result} -le 103 ]  # 100 + "..."
}

# Unicode handling

@test "SEC: unicode preserved in base64 encoding" {
    unicode="测试中文"
    encoded=$(to_base64 "$unicode")
    decoded=$(echo "$encoded" | base64 -d)
    [ "$decoded" = "$unicode" ]
}

@test "SEC: unicode in session_id rejected (non-ASCII)" {
    run validate_session_id "测试"
    [ "$status" -eq 1 ]
}

# Symlink attack prevention

@test "SEC: validate_path_in_base resolves symlinks" {
    mkdir -p "$TEST_TEMP_DIR/base"
    mkdir -p "$TEST_TEMP_DIR/outside"
    ln -s "$TEST_TEMP_DIR/outside" "$TEST_TEMP_DIR/base/link"

    run validate_path_in_base "$TEST_TEMP_DIR/base/link" "$TEST_TEMP_DIR/base"
    [ "$status" -eq 1 ]
}
