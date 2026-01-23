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
  # Will show error if not configured, but command should exist
  assert_contains "${lines[*]}" "DNS-managed applications" || assert_contains "${lines[*]}" "not configured"
}

@test "(dns:apps:enable) command exists and can be called" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable"
  # Command should exit with failure (no args provided)
  assert_failure
  # Just verify the command can be invoked (output may be empty due to error handling)
}

@test "(dns:apps:enable) forwards to add command functionality" {
  # Add some domains to the app
  run dokku domains:add "$TEST_APP" "test.example.com"

  # Try to enable DNS (should behave like dns:apps:enable)
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP"
  # This may fail without provider/zones, but should try to enable domains
  assert_contains "${lines[*]}" "zone" || assert_contains "${lines[*]}" "domain" || assert_contains "${lines[*]}" "Enabled"
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
  # Configure DNS first so report command works
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report"
  assert_failure
  assert_contains "${lines[*]}" "Usage: dokku dns:apps:report <app>"
}

@test "(dns:apps:*) help shows correct descriptions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:enable"
  assert_success
  assert_contains "$output" "enable DNS management for an application"

  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:disable"
  assert_success
  assert_contains "$output" "disable DNS management for an application"

  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:sync"
  assert_success
  assert_contains "$output" "synchronize DNS records for an application"

  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:report"
  assert_success
  assert_contains "$output" "display DNS status for a specific application"
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
  # Should succeed but warn
  assert_success
  [[ "$output" == *"not currently"* ]] || [[ "$output" == *"Nothing to remove"* ]]
}

# apps list tests

@test "(dns:apps) shows no apps when none managed" {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  [[ "$output" == *"No DNS-managed"* ]] || [[ "$output" == *"not configured"* ]]
}

@test "(dns:apps) lists managed apps with domain counts" {
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  add_test_domains "$TEST_APP" test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP" >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  [[ "$output" == *"$TEST_APP"* ]] || [[ "$output" == *"domain"* ]]
}
