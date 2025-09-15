#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Providers Integration Tests  
# Tests for dns:providers subcommands

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
    check_dns_plugin_available
}

@test "(dns:report) shows mock provider when AWS CLI not available" {
    run dokku dns:report
    assert_success
    assert_output --partial "DNS Provider: MOCK"
}

@test "(dns:providers:verify) shows AWS CLI status" {
    run dokku dns:providers:verify
    # Command may succeed or fail depending on AWS CLI availability
    # Should show meaningful AWS CLI status either way
    assert_output --partial "AWS CLI"
}

@test "(dns:providers:verify) shows installation instructions when AWS CLI not available" {
    run dokku dns:providers:verify
    # Should show AWS CLI installation instructions when not available
    [[ "$output" =~ (AWS\ CLI\ is\ not\ installed|Please\ install\ it\ first) ]]
}