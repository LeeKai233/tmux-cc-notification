#!/usr/bin/env bats
# json.bats - Tests for lib/json.sh

load 'test_helper'

# validate_json tests

@test "validate_json accepts valid JSON object" {
    run validate_json '{"key":"value"}'
    [ "$status" -eq 0 ]
}

@test "validate_json accepts nested JSON" {
    run validate_json '{"outer":{"inner":"value"}}'
    [ "$status" -eq 0 ]
}

@test "validate_json accepts JSON with array" {
    run validate_json '{"items":["a","b","c"]}'
    [ "$status" -eq 0 ]
}

@test "validate_json rejects plain text" {
    run validate_json 'not json'
    [ "$status" -ne 0 ]
}

@test "validate_json rejects empty string" {
    run validate_json ''
    [ "$status" -ne 0 ]
}

@test "validate_json rejects malformed JSON" {
    run validate_json '{"key": value}'
    [ "$status" -ne 0 ]
}

@test "validate_json rejects unclosed brace" {
    run validate_json '{"key":"value"'
    [ "$status" -ne 0 ]
}

# parse_session_id tests

@test "parse_session_id extracts valid session_id" {
    run parse_session_id '{"session_id":"test123"}'
    [ "$status" -eq 0 ]
    [ "$output" = "test123" ]
}

@test "parse_session_id extracts with other fields" {
    run parse_session_id '{"session_id":"abc","prompt":"hello"}'
    [ "$status" -eq 0 ]
    [ "$output" = "abc" ]
}

@test "parse_session_id returns empty for missing field" {
    run parse_session_id '{"other":"value"}'
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "parse_session_id validates extracted value" {
    run parse_session_id '{"session_id":"../bad"}'
    [ "$status" -eq 1 ]
}

@test "parse_session_id rejects invalid JSON" {
    run parse_session_id 'not json'
    [ "$status" -eq 1 ]
}

@test "parse_session_id handles whitespace in JSON" {
    run parse_session_id '{ "session_id" : "test" }'
    [ "$status" -eq 0 ]
    [ "$output" = "test" ]
}

# parse_prompt tests

@test "parse_prompt extracts prompt value" {
    run parse_prompt '{"prompt":"hello world"}'
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "parse_prompt returns empty for missing field" {
    run parse_prompt '{"session_id":"test"}'
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "parse_prompt handles unicode" {
    run parse_prompt '{"prompt":"测试消息"}'
    [ "$status" -eq 0 ]
    [ "$output" = "测试消息" ]
}

# parse_json_field tests

@test "parse_json_field extracts arbitrary field" {
    run parse_json_field '{"custom":"value"}' "custom"
    [ "$status" -eq 0 ]
    [ "$output" = "value" ]
}

@test "parse_json_field returns empty for missing field" {
    run parse_json_field '{"other":"value"}' "missing"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# Fallback parsing tests (without jq)

@test "validate_json fallback accepts valid JSON" {
    # Temporarily hide jq
    PATH_BACKUP="$PATH"
    PATH="/nonexistent"
    run validate_json '{"key":"value"}'
    PATH="$PATH_BACKUP"
    [ "$status" -eq 0 ]
}

@test "validate_json fallback rejects non-JSON" {
    PATH_BACKUP="$PATH"
    PATH="/nonexistent"
    run validate_json 'plain text'
    PATH="$PATH_BACKUP"
    [ "$status" -eq 1 ]
}
