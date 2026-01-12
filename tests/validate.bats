#!/usr/bin/env bats
# validate.bats - Tests for lib/validate.sh

load 'test_helper'

# validate_session_id tests

@test "validate_session_id accepts alphanumeric" {
    run validate_session_id "abc123"
    [ "$status" -eq 0 ]
    [ "$output" = "abc123" ]
}

@test "validate_session_id accepts hyphens and underscores" {
    run validate_session_id "test-session_123"
    [ "$status" -eq 0 ]
    [ "$output" = "test-session_123" ]
}

@test "validate_session_id rejects empty" {
    run validate_session_id ""
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects path traversal with .." {
    run validate_session_id "../etc/passwd"
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects forward slash" {
    run validate_session_id "test/bad"
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects backslash" {
    run validate_session_id 'test\bad'
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects shell metacharacters \$(...)" {
    run validate_session_id 'test$(whoami)'
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects backticks" {
    run validate_session_id 'test`id`'
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects semicolon" {
    run validate_session_id 'test;rm -rf /'
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects pipe" {
    run validate_session_id 'test|cat /etc/passwd'
    [ "$status" -eq 1 ]
}

@test "validate_session_id rejects too long (65 chars)" {
    local long_id=$(printf 'a%.0s' {1..65})
    run validate_session_id "$long_id"
    [ "$status" -eq 1 ]
}

@test "validate_session_id accepts max length (64 chars)" {
    local max_id=$(printf 'a%.0s' {1..64})
    run validate_session_id "$max_id"
    [ "$status" -eq 0 ]
}

# validate_path_in_base tests

@test "validate_path_in_base accepts path within base" {
    mkdir -p "$TEST_TEMP_DIR/base/sub"
    run validate_path_in_base "$TEST_TEMP_DIR/base/sub" "$TEST_TEMP_DIR/base"
    [ "$status" -eq 0 ]
}

@test "validate_path_in_base rejects path outside base" {
    mkdir -p "$TEST_TEMP_DIR/base"
    run validate_path_in_base "/etc/passwd" "$TEST_TEMP_DIR/base"
    [ "$status" -eq 1 ]
}

@test "validate_path_in_base rejects traversal attempt" {
    mkdir -p "$TEST_TEMP_DIR/base"
    run validate_path_in_base "$TEST_TEMP_DIR/base/../outside" "$TEST_TEMP_DIR/base"
    [ "$status" -eq 1 ]
}

# validate_tmux_pane tests

@test "validate_tmux_pane accepts %N format" {
    run validate_tmux_pane "%42"
    [ "$status" -eq 0 ]
    [ "$output" = "%42" ]
}

@test "validate_tmux_pane accepts @N format" {
    run validate_tmux_pane "@5"
    [ "$status" -eq 0 ]
}

@test "validate_tmux_pane accepts numeric pane" {
    run validate_tmux_pane "0"
    [ "$status" -eq 0 ]
}

@test "validate_tmux_pane accepts session:window.pane format" {
    run validate_tmux_pane "main:0.1"
    [ "$status" -eq 0 ]
}

@test "validate_tmux_pane accepts alphanumeric session name" {
    run validate_tmux_pane "my-session"
    [ "$status" -eq 0 ]
}

@test "validate_tmux_pane rejects empty" {
    run validate_tmux_pane ""
    [ "$status" -eq 1 ]
}

@test "validate_tmux_pane rejects shell injection" {
    run validate_tmux_pane '$(whoami)'
    [ "$status" -eq 1 ]
}

@test "validate_tmux_pane rejects spaces" {
    run validate_tmux_pane "pane 1"
    [ "$status" -eq 1 ]
}
