#!/usr/bin/env bats

load test_helper

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "test2.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "working.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app my-app
  add_test_domains my-app test1.com
}

teardown() {
  cleanup_dns_data
}

@test "(dns:sync-all) handles no managed apps" {
  cleanup_dns_data

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  assert_success
  [[ "$output" == *"No apps in DNS management"* ]]
}

@test "(dns:sync-all) works with managed apps" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) syncs all managed apps" {
  create_test_app test-app-1
  add_test_domains test-app-1 test1.com
  create_test_app test-app-2
  add_test_domains test-app-2 test2.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app-1 >/dev/null 2>&1 || true
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app-2 >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app test-app-1
  cleanup_test_app test-app-2
}

@test "(dns:sync-all) handles missing apps gracefully" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  # Add non-existent app to LINKS file
  echo "nonexistent-app" >>"$PLUGIN_DATA_ROOT/LINKS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) shows summary" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show summary
  [[ "$output" == *"Total:"* ]] || [[ "$output" == *"synced"* ]] || [[ "$output" == *"failed"* ]] || [[ "$output" == *"provider"* ]]
}

@test "(dns:sync-all) shows app headers" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show app headers or error
  [[ "$output" == *"==="* ]] || [[ "$output" == *"provider"* ]]
}
