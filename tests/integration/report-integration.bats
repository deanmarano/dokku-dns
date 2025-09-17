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

@test "(dns:report) shows app as added after enabling DNS management" {
  # First enable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report "$TEST_APP"
  assert_success
  assert_output --partial "DNS Status:"
  assert_output --partial "Added"
}

@test "(dns:report) global report shows managed app" {
  # First enable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report
  assert_success
  assert_output --partial "$TEST_APP"
}

@test "(dns:report) shows app as not added after disabling DNS management" {
  # First enable then disable DNS for the app
  dokku dns:apps:enable "$TEST_APP" >/dev/null 2>&1
  dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1

  run dokku dns:report "$TEST_APP"
  assert_success
  assert_output --partial "DNS Status:"
  assert_output --partial "Not added"
}

@test "(dns:report) global report without apps shows appropriate message" {
  # Ensure no apps are in DNS management
  dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1 || true

  run dokku dns:report
  assert_success
  # Should show header or appropriate message
  [[ -n "$output" ]]
}
