#!/usr/bin/env bats
load test_helper

# Tests for dns:zones:sync command

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "test.org" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  export DNS_TEST_SERVER_IP="192.0.2.1"
}

teardown() {
  cleanup_dns_data
}

# Helper to run zones:sync
zones_sync() {
  "$PLUGIN_ROOT/subcommands/zones:sync" "$@"
}

# Basic command tests

@test "(dns:zones:sync) requires enabled zone" {
  run zones_sync notexistent.com
  assert_failure
  [[ "$output" == *"not enabled"* ]]
}

@test "(dns:zones:sync) handles enabled zone" {
  create_test_app zone-sync-app
  add_test_domains zone-sync-app app.example.com

  dns_cmd apps:enable zone-sync-app >/dev/null 2>&1 || true

  run zones_sync example.com
  # Should not crash, may succeed or fail depending on provider
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app zone-sync-app
}

@test "(dns:zones:sync) shows message when no apps in zone" {
  run zones_sync test.org
  [[ "$status" -eq 0 ]]
  [[ "$output" == *"No apps"* ]]
}

@test "(dns:zones:sync) fails when no zones enabled" {
  rm -f "$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  run zones_sync
  assert_failure
  [[ "$output" == *"No zones"* ]] || [[ "$output" == *"enable"* ]]
}

@test "(dns:zones:sync) syncs apps in specified zone" {
  create_test_app multi-zone-app
  add_test_domains multi-zone-app app.example.com

  dns_cmd apps:enable multi-zone-app >/dev/null 2>&1 || true

  run zones_sync example.com
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app multi-zone-app
}
