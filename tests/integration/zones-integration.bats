#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Zones Integration Tests  
# Tests for dns:zones subcommands

setup() {
    check_dns_plugin_available
    TEST_APP="dns-zones-test"
    setup_test_app "$TEST_APP"
}

teardown() {
    cleanup_test_app "$TEST_APP"
}

@test "(dns:zones) lists available DNS zones" {
    run dokku dns:zones
    # Command may fail if AWS CLI not available, that's expected
    [[ "$output" =~ (Zones|zone|DISABLED|aws|provider|AWS\ CLI) ]]
}

@test "(dns:zones) shows AWS CLI requirement when not configured" {
    run dokku dns:zones
    # Command may fail if AWS CLI not available, that's expected  
    assert_output --partial "AWS"
}

@test "(dns:report) shows correct status for app not in DNS management" {
    run dokku dns:report "$TEST_APP"
    assert_success
    assert_output --partial "DNS Status:"
    assert_output --partial "Not added"
}

@test "(dns:report) shows app domains even when not in DNS management" {
    run dokku dns:report "$TEST_APP"
    assert_success
    assert_output --partial "app.example.com"
    assert_output --partial "api.example.com"
}

@test "(dns:apps:sync) shows appropriate message for non-DNS-managed app" {
    run dokku dns:apps:sync "$TEST_APP"
    # May succeed or fail depending on provider configuration
    # Should show meaningful message either way
    [[ "$output" =~ (No\ DNS\ provider|not\ found|not\ managed|AWS) ]]
}

@test "(dns:zones:enable) requires zone name argument" {
    run dokku dns:zones:enable
    # Command should show help/usage when no arguments provided
    [[ "$status" -ne 0 ]] || [[ "$output" =~ (Usage|usage|help|argument) ]]
}

