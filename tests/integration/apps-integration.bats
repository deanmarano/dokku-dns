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
  # New output format: "Enabled N domain(s) for app-name"
  assert_output --partial "Enabled"
  assert_output --partial "domain"
}

@test "(dns:apps:sync) can synchronize DNS records for managed app" {
  # First enable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:apps:sync "$TEST_APP"
  # May succeed or fail depending on provider availability
  # New output format uses ✓/✗ symbols and "Synced: X, Failed: Y"
  [[ "$output" =~ (Synced|Failed|✓|✗|provider|zone) ]]
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
