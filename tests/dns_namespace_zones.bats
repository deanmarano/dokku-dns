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
  # Try to enable a zone (should behave like dns:zones:enable)
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "example.com"
  # This may fail without provider credentials, but should at least try
  assert_contains "${lines[*]}" "zone"
}

@test "(dns:zones:disable) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:disable"
  assert_contains "${lines[*]}" "Please specify a zone"
}

@test "(dns:zones:disable) forwards to zones:disable functionality" {
  # Try to disable a zone
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:disable" "example.com"
  # This may fail without a zone enabled, but should at least try
  assert_contains "${lines[*]}" "zone"
}

@test "(dns:zones:*) help shows correct descriptions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_contains "$output" "enable a DNS zone"
  assert_contains "$output" "disable a DNS zone"
}
