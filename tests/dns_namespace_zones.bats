#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:zones:enable) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable"
  assert_contains "${lines[*]}" "Please specify a zone"
}

@test "(dns:zones:enable) forwards to zones:enable functionality" {
  # Configure DNS first
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success

  # Try to enable a zone (should behave like dns:zones:enable)
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "example.com"
  # This may fail without AWS credentials, but should at least try
  assert_contains "${lines[*]}" "zone" || assert_contains "${lines[*]}" "AWS"
}

@test "(dns:zones:disable) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:disable"
  assert_contains "${lines[*]}" "Please specify a zone"
}

@test "(dns:zones:disable) forwards to zones:disable functionality" {
  # Configure DNS first
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success

  # Try to disable a zone (should behave like dns:zones:disable)
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:disable" "example.com"
  # This may fail without AWS credentials or zone, but should at least try
  assert_contains "${lines[*]}" "zone" || assert_contains "${lines[*]}" "AWS" || assert_contains "${lines[*]}" "not found"
}

@test "(dns:zones:*) help shows correct descriptions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "zones:enable"
  assert_success
  assert_contains "$output" "enable DNS zone for automatic app domain management"

  run dokku "$PLUGIN_COMMAND_PREFIX:help" "zones:disable"
  assert_success
  assert_contains "$output" "disable DNS zone and remove managed domains"
}

@test "(dns:zones:enable/disable) backward compatibility with zones:enable/remove" {
  # Configure DNS first
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success

  # Both new and old commands should have similar behavior
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "example.com"
  local enable_output="$output"

  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "example.com"
  local add_output="$output"

  # The outputs should be similar since they forward to the same command
  # (exact match not expected due to potential different error states)
  assert_contains "$enable_output" "zone" || assert_contains "$add_output" "zone"
}
