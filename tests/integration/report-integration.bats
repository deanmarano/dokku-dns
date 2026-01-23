#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Report Integration Tests
# Tests for dns:report subcommand

setup() {
  check_dns_plugin_available
  TEST_APP="dns-report-test"
  setup_test_app "$TEST_APP" "app.example.com" "api.example.com"
}

teardown() {
  cleanup_test_app "$TEST_APP"
}

@test "(dns:report) shows status for app not in DNS management" {
  run dokku dns:report "$TEST_APP"
  # App not in DNS management shows error
  assert_failure
  assert_output --partial "not in DNS management"
}

@test "(dns:report) shows app info after enabling DNS management" {
  # First enable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report "$TEST_APP"
  assert_success
  # New format shows App:, Server IP:, and domain table
  assert_output --partial "App:"
  assert_output --partial "Server IP:"
}

@test "(dns:report) global report shows managed app" {
  # First enable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report
  assert_success
  assert_output --partial "$TEST_APP"
}

@test "(dns:report) shows not managed after disabling DNS" {
  # First enable then disable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
  dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report "$TEST_APP"
  # After disable, app is not in DNS management
  assert_failure
  assert_output --partial "not in DNS management"
}

@test "(dns:report) global report without apps shows appropriate message" {
  # Ensure no apps are in DNS management
  dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1 || true

  run dokku dns:report
  assert_success
  # Should show header or appropriate message
  [[ -n "$output" ]]
}
