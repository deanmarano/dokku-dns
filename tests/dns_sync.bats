#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "test2.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app my-app
  add_test_domains my-app test1.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:apps:sync) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync"
  assert_failure
  [[ "$output" == *"app name required"* ]]
}

@test "(dns:apps:sync) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" nonexistent-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]
}

@test "(dns:apps:sync) fails gracefully without provider configuration" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Without a provider, sync should fail with a relevant error message
  assert_failure
  [[ "$output" == *"provider"* ]] || [[ "$output" == *"no provider"* ]] || [[ "$output" == *"not configured"* ]] || [[ "$output" == *"credentials"* ]] || [[ "$output" == *"not in DNS management"* ]]
}

@test "(dns:apps:sync) handles app with no domains" {
  create_test_app empty-app

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" empty-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]

  cleanup_test_app empty-app
}

@test "(dns:apps:sync) shows helpful error when provider not accessible" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Should fail with a provider-related or management error
  assert_failure
  [[ "$output" == *"provider"* ]] || [[ "$output" == *"credentials"* ]] || [[ "$output" == *"not configured"* ]] || [[ "$output" == *"not in DNS management"* ]]
}

@test "(dns:apps:sync) mentions domain or provider in output" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Output should reference either the domain being synced or a provider error
  [[ "$output" == *"test1.com"* ]] || [[ "$output" == *"provider"* ]] || [[ "$output" == *"credentials"* ]]
}
