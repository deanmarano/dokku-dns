#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  export TEST_APP="test-app-$$"
  create_test_app "$TEST_APP"
}

teardown() {
  cleanup_test_app "$TEST_APP"
  cleanup_dns_data
}

@test "(dns:apps) lists DNS-managed applications" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  # May fail if PLUGIN_DATA_ROOT doesn't exist yet, but should produce output
  [[ "$output" == *"DNS-managed"* ]] || [[ "$output" == *"No DNS"* ]] || [[ "$output" == *"not configured"* ]]
}

@test "(dns:apps:enable) command exists and can be called" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable"
  # Command should exit with failure (no args provided)
  assert_failure
  # Just verify the command can be invoked (output may be empty due to error handling)
}

@test "(dns:apps:enable) enables DNS for an app with domains" {
  # Add some domains to the app
  dokku domains:add "$TEST_APP" "test.example.com" >/dev/null 2>&1 || true
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Enable DNS management
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP"
  assert_success
  # Should confirm enablement
  [[ "$output" == *"Enabled"* ]] || [[ "$output" == *"enabled"* ]] || [[ "$output" == *"domain"* ]]
}

@test "(dns:apps:disable) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:disable"
  assert_contains "${lines[*]}" "Please specify an app name"
}

@test "(dns:apps:sync) shows error with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync"
  assert_failure
  assert_contains "${lines[*]}" "app name required"
}

@test "(dns:apps:report) requires app name and shows usage without it" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report"
  assert_failure
  assert_contains "${lines[*]}" "Usage: dokku dns:apps:report <app>"
}

@test "(dns:apps:*) help shows correct descriptions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_contains "$output" "enable DNS management for an application"
  assert_contains "$output" "disable DNS management for an application"
  assert_contains "$output" "sync DNS records for an application"
  assert_contains "$output" "show DNS status for an application"
}

# apps:disable tests

@test "(dns:apps:disable) disables DNS-managed app" {
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  add_test_domains "$TEST_APP" test.example.com

  # Enable the app first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP" >/dev/null 2>&1 || true

  # Verify app is in DNS management
  [[ -f "$PLUGIN_DATA_ROOT/$TEST_APP/DOMAINS" ]]

  # Disable it
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:disable" "$TEST_APP"
  assert_success

  # Verify app is removed from DNS management
  [[ ! -f "$PLUGIN_DATA_ROOT/$TEST_APP/DOMAINS" ]] || [[ ! -d "$PLUGIN_DATA_ROOT/$TEST_APP" ]]
}

@test "(dns:apps:disable) handles app not in DNS management" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:disable" "$TEST_APP"
  assert_success
  # Should indicate there's nothing to disable
  [[ "$output" == *"not currently"* ]] || [[ "$output" == *"Nothing"* ]] || [[ "$output" == *"not in DNS"* ]]
}

# apps list tests

@test "(dns:apps) shows no apps when none managed" {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  assert_success
  [[ "$output" == *"No DNS-managed"* ]] || [[ "$output" == *"No DNS"* ]]
}

@test "(dns:apps) lists managed apps with domain counts" {
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  add_test_domains "$TEST_APP" test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP" >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  assert_success
  assert_contains "$output" "$TEST_APP"
}
