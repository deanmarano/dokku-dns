#!/usr/bin/env bats
load test_helper

setup() {
  # No setup needed for help tests
  true
}

teardown() {
  rm -rf "$PLUGIN_DATA_ROOT" >/dev/null 2>&1 || true
}

@test "(dns:help) shows main help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dokku dns[:COMMAND]"
  assert_output_contains "Manage DNS for your apps with cloud providers"
  assert_output_contains "commands:"
}

@test "(dns) shows main help when called without subcommand" {
  run dokku "$PLUGIN_COMMAND_PREFIX"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dokku dns[:COMMAND]"
  assert_output_contains "Manage DNS for your apps with cloud providers"
}

@test "(dns:help) lists available commands" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_output_contains "dns:apps:enable"
  assert_output_contains "dns:apps:disable"
  assert_output_contains "dns:report"
  assert_output_contains "dns:apps:sync"
  assert_output_contains "dns:sync"
  assert_output_contains "dns:providers:verify"
  assert_output_contains "dns:zones:enable"
  assert_output_contains "dns:zones:disable"
  assert_output_contains "dns:version"
}

@test "(dns:help) command descriptions are consistent" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_output_contains "enable DNS management for an application"
  assert_output_contains "disable DNS management for an application"
  assert_output_contains "show plugin version"
}

@test "(dns:help) unknown command shows error" {
  run dokku "$PLUGIN_COMMAND_PREFIX:nonexistent-command"
  assert_failure
}
