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
  assert_output_contains "Manage DNS for your apps with cloud providers"
  assert_output_contains "dns commands:"
}

@test "(dns) shows main help when called without subcommand" {
  run dokku "$PLUGIN_COMMAND_PREFIX"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "Manage DNS for your apps with cloud providers"
}

@test "(dns:help) lists available commands" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  assert_output_contains "dns:apps:enable"
  assert_output_contains "dns:apps:disable"
  assert_output_contains "dns:report"
  assert_output_contains "dns:apps:sync"
  assert_output_contains "dns:sync:all"
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

# `dokku help --all` runs `<plugin>/commands help` for every plugin under
# `set -eo pipefail`. Returning DOKKU_NOT_IMPLEMENTED_EXIT there aborts that
# loop and breaks the dokku package postinst, so bare `help` must succeed.
@test "(help) bare help argument succeeds" {
  DOKKU_NOT_IMPLEMENTED_EXIT=10 run "$PLUGIN_ROOT/commands" help
  assert_success
}

@test "(help) bare help emits comma-separated command,description pairs" {
  DOKKU_NOT_IMPLEMENTED_EXIT=10 run "$PLUGIN_ROOT/commands" help
  assert_success
  # every line must carry exactly one comma for `column -c2 -t -s,`
  [ "$(echo "$output" | grep -cv ',')" -eq 0 ]
  [ "$(echo "$output" | awk -F, 'NF>2' | wc -l)" -eq 0 ]
}

@test "(help) bare help lists the same commands as dns:help" {
  DOKKU_NOT_IMPLEMENTED_EXIT=10 run "$PLUGIN_ROOT/commands" help
  assert_success
  assert_output_contains "dns:apps:enable"
  assert_output_contains "dns:report"
  assert_output_contains "dns:sync:all"
  assert_output_contains "dns:version"
}
