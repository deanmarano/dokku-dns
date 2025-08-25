#!/usr/bin/env bats
# DNS Plugin Help and Version Integration Tests
# Tests: 4 integration tests for help and version commands
# Expected: 4 passing, 0 failing
# Requires: Full Dokku environment with DNS plugin installed

setup() {
    # Check if we're in a Dokku environment
    if ! command -v dokku >/dev/null 2>&1; then
        skip "Dokku not found. These tests require a Dokku environment."
    fi
    
    # Check if DNS plugin is available
    if ! dokku help | grep -q dns; then
        skip "DNS plugin not installed. Please install the plugin first."
    fi
}

@test "(dns:help) main help shows usage" {
    run dokku dns:help
    assert_success
    assert_output --partial "usage:"
}

@test "(dns:help) main help shows available commands" {
    run dokku dns:help
    assert_success  
    assert_output --partial "dns:apps:enable"
}

@test "(dns:help apps:enable) specific command help works" {
    run dokku dns:help apps:enable
    assert_success
    assert_output --partial "enable DNS management for an application"
}

@test "(dns:version) shows plugin version" {
    run dokku dns:version
    assert_success
    assert_output --partial "dokku-dns plugin version"
}

# Helper functions for BATS assertions
assert_success() {
    if [[ "$status" -ne 0 ]]; then
        echo "Expected success but got exit code: $status"
        echo "Output: $output"
        return 1
    fi
}

assert_output() {
    local expected="$2"
    case "$1" in
        --partial)
            if [[ "$output" != *"$expected"* ]]; then
                echo "Expected output to contain: '$expected'"
                echo "Actual output: '$output'"
                return 1
            fi
            ;;
        *)
            expected="$1"
            if [[ "$output" != "$expected" ]]; then
                echo "Expected output: '$expected'"
                echo "Actual output: '$output'" 
                return 1
            fi
            ;;
    esac
}