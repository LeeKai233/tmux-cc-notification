#!/usr/bin/env bats
# sanitize.bats - Tests for lib/sanitize.sh

load 'test_helper'

# to_base64 tests

@test "to_base64 encodes simple string" {
    run to_base64 "hello"
    [ "$status" -eq 0 ]
    [ "$output" = "aGVsbG8=" ]
}

@test "to_base64 encodes empty string" {
    run to_base64 ""
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "to_base64 encodes unicode (CJK)" {
    run to_base64 "测试"
    [ "$status" -eq 0 ]
    # Verify it decodes back correctly
    decoded=$(echo "$output" | base64 -d)
    [ "$decoded" = "测试" ]
}

@test "to_base64 encodes special characters" {
    run to_base64 'test$`"'\''&|;<>'
    [ "$status" -eq 0 ]
    # Should produce valid base64
    [[ "$output" =~ ^[A-Za-z0-9+/=]+$ ]]
}

# validate_base64 tests

@test "validate_base64 accepts valid base64" {
    run validate_base64 "aGVsbG8="
    [ "$status" -eq 0 ]
}

@test "validate_base64 rejects invalid characters" {
    run validate_base64 "hello!"
    [ "$status" -eq 1 ]
}

@test "validate_base64 accepts empty string" {
    run validate_base64 ""
    [ "$status" -eq 0 ]
}

# sanitize_display tests

@test "sanitize_display handles null bytes" {
    # Null bytes truncate strings in bash - this is expected behavior
    run sanitize_display $'test\x00bad'
    [ "$status" -eq 0 ]
    # String is truncated at null byte
    [ "$output" = "test" ]
}

@test "sanitize_display removes control characters" {
    run sanitize_display $'test\x01\x02\x03'
    [ "$status" -eq 0 ]
    [ "$output" = "test" ]
}

@test "sanitize_display converts newlines to spaces" {
    run sanitize_display $'line1\nline2'
    [ "$status" -eq 0 ]
    [ "$output" = "line1 line2" ]
}

@test "sanitize_display truncates long strings" {
    local long_str=$(printf 'a%.0s' {1..250})
    run sanitize_display "$long_str" 200
    [ "$status" -eq 0 ]
    [ ${#output} -eq 203 ]  # 200 + "..."
    [[ "$output" == *"..." ]]
}

@test "sanitize_display preserves short strings" {
    run sanitize_display "short" 200
    [ "$status" -eq 0 ]
    [ "$output" = "short" ]
}

# sanitize_for_shell tests

@test "sanitize_for_shell removes backticks" {
    run sanitize_for_shell 'test`whoami`'
    [ "$status" -eq 0 ]
    [[ "$output" != *'`'* ]]
}

@test "sanitize_for_shell removes dollar sign" {
    run sanitize_for_shell 'test$var'
    [ "$status" -eq 0 ]
    [[ "$output" != *'$'* ]]
}

@test "sanitize_for_shell removes command substitution" {
    run sanitize_for_shell 'test$(id)'
    [ "$status" -eq 0 ]
    [[ "$output" != *'$('* ]]
    [[ "$output" != *')'* ]]
}

@test "sanitize_for_shell removes pipe" {
    run sanitize_for_shell 'test|cat'
    [ "$status" -eq 0 ]
    [[ "$output" != *'|'* ]]
}

@test "sanitize_for_shell removes semicolon" {
    run sanitize_for_shell 'test;rm'
    [ "$status" -eq 0 ]
    [[ "$output" != *';'* ]]
}

@test "sanitize_for_shell removes ampersand" {
    run sanitize_for_shell 'test&bg'
    [ "$status" -eq 0 ]
    [[ "$output" != *'&'* ]]
}

@test "sanitize_for_shell removes redirects" {
    run sanitize_for_shell 'test>file<input'
    [ "$status" -eq 0 ]
    [[ "$output" != *'>'* ]]
    [[ "$output" != *'<'* ]]
}

@test "sanitize_for_shell removes quotes" {
    run sanitize_for_shell "test\"double'single"
    [ "$status" -eq 0 ]
    [[ "$output" != *'"'* ]]
    [[ "$output" != *"'"* ]]
}

# safe_encode_for_pwsh tests

@test "safe_encode_for_pwsh sanitizes and encodes" {
    run safe_encode_for_pwsh "hello world"
    [ "$status" -eq 0 ]
    # Should be valid base64
    [[ "$output" =~ ^[A-Za-z0-9+/=]+$ ]]
    # Should decode to sanitized input
    decoded=$(echo "$output" | base64 -d)
    [ "$decoded" = "hello world" ]
}

@test "safe_encode_for_pwsh handles unicode" {
    run safe_encode_for_pwsh "测试消息"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[A-Za-z0-9+/=]+$ ]]
}

@test "safe_encode_for_pwsh truncates before encoding" {
    local long_str=$(printf 'a%.0s' {1..250})
    run safe_encode_for_pwsh "$long_str" 50
    [ "$status" -eq 0 ]
    decoded=$(echo "$output" | base64 -d)
    [ ${#decoded} -eq 53 ]  # 50 + "..."
}
