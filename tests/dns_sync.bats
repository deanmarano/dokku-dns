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

@test "(dns:apps:sync) fails gracefully without provider for domain's zone" {
  # Create DOMAINS file with a domain that has no matching zone in mock provider
  mkdir -p "$PLUGIN_DATA_ROOT/my-app"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/my-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Sync should fail - the domain's zone isn't managed by any provider
  assert_failure
  [[ "$output" == *"no zone"* ]] || [[ "$output" == *"no provider"* ]] || [[ "$output" == *"Failed: 1"* ]] || [[ "$output" == *"provider"* ]]
}

@test "(dns:apps:sync) handles app with no domains" {
  create_test_app empty-app

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" empty-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]

  cleanup_test_app empty-app
}

@test "(dns:apps:sync) shows domain name and failure count when zone not found" {
  # Create DOMAINS file with a domain that has no matching zone
  mkdir -p "$PLUGIN_DATA_ROOT/my-app"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/my-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  assert_failure
  [[ "$output" == *"test1.com"* ]]
  [[ "$output" == *"Failed: 1"* ]] || [[ "$output" == *"no zone"* ]]
}

@test "(dns:apps:sync) mentions domain in output" {
  # Create DOMAINS file directly so sync can proceed
  mkdir -p "$PLUGIN_DATA_ROOT/my-app"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/my-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Output should reference the domain being synced
  [[ "$output" == *"test1.com"* ]]
}
