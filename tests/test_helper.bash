#!/usr/bin/env bash
# test_helper.bash - Common setup/teardown and mocks for bats tests

# Project paths
export PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export LIB_DIR="${PROJECT_DIR}/lib"
export HOOKS_DIR="${PROJECT_DIR}/hooks"

# Test isolation: unique temp dir per test
setup() {
    export TEST_TEMP_DIR=$(mktemp -d "/tmp/cc-notify-test-XXXXXX")

    # Source library files first
    source "${LIB_DIR}/validate.sh"
    source "${LIB_DIR}/sanitize.sh"
    source "${LIB_DIR}/json.sh"
    source "${LIB_DIR}/state.sh"

    # Override STATE_BASE_DIR AFTER sourcing (constants.sh sets it)
    export STATE_BASE_DIR="$TEST_TEMP_DIR"
}

teardown() {
    [[ -d "$TEST_TEMP_DIR" ]] && rm -rf "$TEST_TEMP_DIR"
}

# Mock find_pwsh to avoid Windows dependency
find_pwsh() {
    echo "/mock/pwsh"
}
export -f find_pwsh

# Mock PowerShell execution - captures args to file
mock_pwsh() {
    echo "$@" >> "${TEST_TEMP_DIR}/pwsh_calls.log"
    echo "mock_output"
}
