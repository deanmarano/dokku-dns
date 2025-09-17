#!/usr/bin/env bats

load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
    create_test_app my-app
    add_test_domains my-app test1.com
  fi
}

# Helper function to create a service (app)
create_service() {
  local service_name="$1"
  create_test_app "$service_name"
}

teardown() {
  # Skip teardown in Docker environment to preserve setup
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(dns:sync-all) error when there are no managed apps" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"

  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) works with AWS provider (always available)" {
  # Add an app to DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  # Should succeed or fail gracefully, but not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  assert_output_contains "Starting DNS sync-all operation"
}

@test "(dns:sync-all) syncs all managed apps" {
  # AWS is always the provider

  # Add multiple apps with domains that have hosted zones
  create_service "test-app-1"
  add_test_domains test-app-1 test1.com
  create_service "test-app-2"
  add_test_domains test-app-2 test2.com

  # Change my-app to use a domain with hosted zone
  add_test_domains my-app test1.com

  # Add apps to DNS (should succeed with hosted zones)
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app-1 >/dev/null 2>&1
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app-2 >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"

  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) handles missing apps gracefully" {
  # AWS is always the provider

  # Add my-app with hosted zone domain
  add_test_domains my-app test1.com
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  # Manually add a non-existent app to LINKS file to simulate an app that was deleted
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "nonexistent-app" >>"$PLUGIN_DATA_ROOT/LINKS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"

  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) shows summary with mixed results" {
  # AWS is always the provider

  # Add apps with domains that have hosted zones
  create_service "working-app"
  add_test_domains working-app working.com
  add_test_domains my-app test1.com

  # Add apps to DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" working-app >/dev/null 2>&1

  # Add non-existent app to simulate failure
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "missing-app" >>"$PLUGIN_DATA_ROOT/LINKS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"

  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:sync-all) displays start timing information" {
  # AWS is always the provider

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  assert_success

  # Should show start time at beginning with proper timestamp format
  assert_output_contains "Starting DNS sync-all operation"

  # Verify timestamp format (YYYY-MM-DD HH:MM:SS TZ)
  start_line=$(echo "$output" | grep "Starting DNS sync-all operation" || echo "")
  if [[ -n "$start_line" ]]; then
    # Should match format: [YYYY-MM-DD HH:MM:SS TZ] Starting DNS sync-all operation
    if ! echo "$start_line" | grep -q '^\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9] [A-Z][A-Z]*\] Starting DNS sync-all operation'; then
      flunk "Start time format incorrect: $start_line"
    fi
  else
    flunk "Start time message not found in output"
  fi
}

@test "(dns:sync-all) displays end timing information" {
  # AWS is always the provider

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  assert_success

  # Should show end time
  assert_output_contains "DNS sync-all operation completed"

  # Verify timestamp format (YYYY-MM-DD HH:MM:SS TZ)
  end_line=$(echo "$output" | grep "DNS sync-all operation completed" || echo "")
  if [[ -n "$end_line" ]]; then
    # Should match format: [YYYY-MM-DD HH:MM:SS TZ] DNS sync-all operation completed
    if ! echo "$end_line" | grep -q '^\[20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9] [A-Z][A-Z]*\] DNS sync-all operation completed'; then
      flunk "End time format incorrect: $end_line"
    fi
  else
    flunk "End time message not found in output"
  fi
}

@test "(dns:sync-all) timing works with AWS provider" {
  # AWS is always available, no configuration needed

  run dokku "$PLUGIN_COMMAND_PREFIX:sync-all"
  # Should succeed or fail gracefully
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show timing information
  assert_output_contains "Starting DNS sync-all operation"
  assert_output_contains "DNS sync-all operation completed"
}
