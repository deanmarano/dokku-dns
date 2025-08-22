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
  assert_output_contains "dns:add"
  assert_output_contains "dns:configure"
  assert_output_contains "dns:help" 2
  assert_output_contains "dns:remove"
  assert_output_contains "dns:report"
  assert_output_contains "dns:sync <app>"
  assert_output_contains "dns:sync-all"
  assert_output_contains "dns:verify"
  assert_output_contains "dns:version"
}

@test "(dns:configure:help) shows subcommand help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:configure:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:configure" 2
  assert_output_contains "configure or change the global DNS provider"
}

@test "(dns:add:help) shows add command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:add" 3
  assert_output_contains "add app domains to DNS provider for management" 2
}

@test "(dns:verify:help) shows verify command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:verify:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:verify" 2
  assert_output_contains "verify DNS provider setup and connectivity" 2
}

@test "(dns:sync:help) shows sync command help" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:help"
  assert_success
  assert_output_contains "usage"
  assert_output_contains "dns:sync" 2
  assert_output_contains "synchronize DNS records for app"
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
  # Check that all main commands have consistent descriptions
  assert_output_contains "add app domains to DNS provider for management"
  assert_output_contains "configure or change the global DNS provider" 2
  assert_output_contains "show help for DNS commands or specific subcommand"
  assert_output_contains "remove app from DNS management"
  assert_output_contains "display DNS status and domain information for app(s)"
  assert_output_contains "synchronize DNS records for app"
  assert_output_contains "verify DNS provider setup and connectivity" 2
  assert_output_contains "show DNS plugin version and dependency versions"
}

@test "(dns:help) invalid subcommand shows error" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" nonexistent-command
  assert_failure
  assert_output_contains "No such file or directory"
}