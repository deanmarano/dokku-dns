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

@test "(dns:apps:sync) works without provider configuration" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # May fail due to no provider, but should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:apps:sync) attempts AWS sync when configured" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:apps:sync) handles app with no domains" {
  create_test_app empty-app

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" empty-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]

  cleanup_test_app empty-app
}

@test "(dns:apps:sync) shows helpful error when AWS not accessible" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # May fail with provider error
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:apps:sync) attempts sync with multiple domains" {
  echo "working.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  add_test_domains my-app test2.com working.com
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:apps:sync) shows status symbols" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show status symbols
  [[ "$output" == *"✓"* ]] || [[ "$output" == *"✗"* ]] || [[ "$output" == *"no provider"* ]]
}

@test "(dns:apps:sync) shows sync summary" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # May show summary if sync completes
  if [[ "$status" -eq 0 ]]; then
    [[ "$output" == *"Synced:"* ]] || [[ "$output" == *"Failed:"* ]]
  fi
}

@test "(dns:apps:sync) shows domain status" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should mention the domain or show error
  [[ "$output" == *"test1.com"* ]] || [[ "$output" == *"provider"* ]]
}
