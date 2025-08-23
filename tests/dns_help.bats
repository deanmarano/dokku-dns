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
  # providers:configure command removed
  assert_output_contains "dns:help" 2
  assert_output_contains "dns:apps:disable"
  assert_output_contains "dns:report"
  assert_output_contains "dns:apps:sync"
  assert_output_contains "dns:sync-all"
  assert_output_contains "dns:providers:verify"
  assert_output_contains "dns:zones:enable"
  assert_output_contains "dns:zones:disable"
  assert_output_contains "dns:version"
}

# providers:configure command removed - test no longer needed

@test "(dns:help apps:enable) shows add command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:enable"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:apps:enable" 3
  assert_output_contains "enable DNS management for an application" 2
}

@test "(dns:help providers:verify) shows verify command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "providers:verify"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:providers:verify" 2
  assert_output_contains "verify DNS provider setup and connectivity" 2
}

@test "(dns:help apps:sync) shows sync command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:sync"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:apps:sync" 2
  assert_output_contains "synchronize DNS records for an application" 2
}

@test "(dns:report:help) shows report command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:report" 2
  assert_output_contains "display DNS status and domain information for app(s)" 2
}

@test "(dns:help) command descriptions are consistent" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help"
  assert_success
  # Check that all main commands have consistent descriptions - using new namespace commands
  assert_output_contains "enable DNS management for an application"
  # providers:configure command removed - AWS is always the provider
  assert_output_contains "show help for DNS commands or specific subcommand"
  assert_output_contains "disable DNS management for an application"
  assert_output_contains "display DNS status and domain information for app(s)"
  assert_output_contains "synchronize DNS records for an application"
  assert_output_contains "verify DNS provider setup and connectivity"
  assert_output_contains "show DNS plugin version and dependency versions"
}

@test "(dns:help) invalid subcommand shows error" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" nonexistent-command
  assert_failure
  assert_output_contains "No such file or directory"
}