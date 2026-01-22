#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  create_test_app my-app
  add_test_domains my-app example.com api.example.com
  # Enable zones so apps:enable works
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:apps:enable) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable"
  assert_failure
  assert_output_contains "app name required"
}

@test "(dns:apps:enable) error when app has no domains" {
  create_test_app empty-app
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" empty-app
  assert_failure
  assert_output_contains "No domains found"
  cleanup_test_app empty-app
}

@test "(dns:apps:enable) success with existing app" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_success
  assert_output_contains "Enabled"
  assert_output_contains "domain"
}

@test "(dns:apps:enable) success with specific domains" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app example.com
  assert_success
  assert_output_contains "Enabled"
}

@test "(dns:apps:enable) success with multiple specific domains" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app example.com api.example.com
  assert_success
  assert_output_contains "Enabled"
}

@test "(dns:apps:enable) fails without enabled zones" {
  cleanup_dns_data # Remove enabled zones
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_failure
  [[ "$output" == *"zone"* ]]
}

@test "(dns:apps:enable) stores domains in DOMAINS file" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_success
  assert_file_exists "$PLUGIN_DATA_ROOT/my-app/DOMAINS"
  run cat "$PLUGIN_DATA_ROOT/my-app/DOMAINS"
  [[ "$output" == *"example.com"* ]]
}

@test "(dns:apps:enable) adds app to LINKS file" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_success
  assert_file_exists "$PLUGIN_DATA_ROOT/LINKS"
  run cat "$PLUGIN_DATA_ROOT/LINKS"
  assert_output_contains "my-app"
}
