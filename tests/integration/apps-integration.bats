#!/usr/bin/env bats

# DNS Plugin Apps Integration Tests  
# Tests for dns:apps subcommands

setup() {
    # Ensure we're in the right environment for DNS plugin testing
    if [[ ! -f "/var/lib/dokku/plugins/available/dns/plugin.toml" ]]; then
        skip "DNS plugin not available in test environment"
    fi
    
    # Create test app if it doesn't exist
    TEST_APP="dns-apps-test"
    if ! dokku apps:list 2>/dev/null | grep -q "$TEST_APP"; then
        dokku apps:create "$TEST_APP" >/dev/null 2>&1
    fi
    
    # Add test domains
    dokku domains:add "$TEST_APP" "app.example.com" >/dev/null 2>&1 || true
    dokku domains:add "$TEST_APP" "api.app.example.com" >/dev/null 2>&1 || true
    
    # Ensure app is not in DNS management initially
    dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1 || true
}

teardown() {
    # Clean up test app
    if [[ -n "${TEST_APP:-}" ]]; then
        dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1 || true
        dokku apps:destroy "$TEST_APP" --force >/dev/null 2>&1 || true
    fi
}

@test "(dns:apps:enable) can add app to DNS management" {
    run dokku dns:apps:enable "$TEST_APP"
    assert_success
    assert_output --partial "app.example.com"
    assert_output --partial "api.app.example.com"
}

@test "(dns:report) shows app as added after dns:apps:enable" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    run dokku dns:report "$TEST_APP"
    assert_success
    assert_output --partial "DNS Status:"
    assert_output --partial "Added"
}

@test "(dns:apps:sync) can synchronize DNS records for managed app" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    run dokku dns:apps:sync "$TEST_APP"
    assert_success
    # Should show sync operation (exact output depends on AWS availability)
    [[ "$output" =~ (sync|AWS|domain) ]]
}

@test "(dns:report) global report shows managed app" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    run dokku dns:report
    assert_success
    assert_output --partial "$TEST_APP"
}

@test "(dns:apps:disable) can remove app from DNS management" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    # Then disable it
    run dokku dns:apps:disable "$TEST_APP"
    assert_success
    
    # Verify it's no longer in DNS management
    run dokku dns:report "$TEST_APP"
    assert_success
    assert_output --partial "Not added"
}

# Helper functions for BATS
assert_success() {
    if [[ $status -ne 0 ]]; then
        echo "Command failed with status $status"
        echo "Output: $output"
        return 1
    fi
}

assert_output() {
    local flag="$1"
    local expected="$2"
    
    case "$flag" in
        --partial)
            if [[ ! "$output" =~ $expected ]]; then
                echo "Expected output to contain: '$expected'"
                echo "Actual output: '$output'"
                return 1
            fi
            ;;
        *)
            if [[ "$output" != "$expected" ]]; then
                echo "Expected: '$expected'"
                echo "Actual: '$output'"
                return 1
            fi
            ;;
    esac
}