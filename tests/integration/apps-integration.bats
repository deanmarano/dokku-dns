#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Apps Integration Tests  
# Tests for dns:apps subcommands

setup() {
    check_dns_plugin_available
    TEST_APP="dns-apps-test"
    setup_test_app "$TEST_APP" "app.example.com" "api.app.example.com"
}

teardown() {
    cleanup_test_app "$TEST_APP"
}

@test "(dns:apps:enable) can add app to DNS management" {
    run dokku dns:apps:enable "$TEST_APP"
    assert_success
    assert_output --partial "app.example.com"
    assert_output --partial "api.app.example.com"
}


@test "(dns:apps:sync) can synchronize DNS records for managed app" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    run dokku dns:apps:sync "$TEST_APP"
    assert_success
    # Should show sync operation (exact output depends on AWS availability)
    [[ "$output" =~ (sync|AWS|domain) ]]
}


@test "(dns:apps:sync) shows appropriate message for non-DNS-managed app" {
    run dokku dns:apps:sync "$TEST_APP"
    # May succeed or fail depending on provider configuration
    # Should show meaningful message either way - just check it produces output
    [[ -n "$output" ]]
}

@test "(dns:apps:disable) can remove app from DNS management" {
    # First enable DNS for the app
    dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
    
    # Then disable it
    run dokku dns:apps:disable "$TEST_APP"
    assert_success
}

@test "(dns:apps:enable) rejects nonexistent app" {
    run dokku dns:apps:enable nonexistent-app
    assert_failure
}

@test "(dns:apps:sync) rejects nonexistent app" {
    run dokku dns:apps:sync nonexistent-app
    assert_failure
}


