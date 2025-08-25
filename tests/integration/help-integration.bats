#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Help and Version Integration Tests
# Tests: 4 integration tests for help and version commands
# Expected: 4 passing, 0 failing
# Requires: Full Dokku environment with DNS plugin installed

setup() {
    # Check if we're in a Dokku environment
    if ! command -v dokku >/dev/null 2>&1; then
        skip "Dokku not found. These tests require a Dokku environment."
    fi
    
    check_dns_plugin_available
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

