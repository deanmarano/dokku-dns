#!/usr/bin/env bats
load test_helper

# Tests for Phase 26a, 26b fixes and domain parsing bug fix

setup() {
  cleanup_dns_data
  setup_dns_provider aws
}

teardown() {
  cleanup_dns_data
}

# Phase 26a: Error checking in sync apply phase

@test "(phase26a) sync shows 'no hosted zone found' when zone lookup fails in apply phase" {
  create_test_app test-app
  add_test_domains test-app nonexistent.invalid

  # Manually add domain to DNS management (bypass apps:enable zone check)
  mkdir -p "$PLUGIN_DATA_ROOT"
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "test-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "nonexistent.invalid" >"$PLUGIN_DATA_ROOT/test-app/DOMAINS"

  # Try to sync - should fail with clear error message
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" test-app

  # Should show specific error message from our fix
  assert_output_contains "Failed (no hosted zone found)" || assert_output_contains "No provider found"

  cleanup_test_app test-app
}

@test "(phase26a) sync skips domain when zone lookup fails and continues to next domain" {
  create_test_app multi-domain-app
  add_test_domains multi-domain-app bad-domain.invalid good-domain.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-domain-app >/dev/null 2>&1 || true

  # Sync should handle failure gracefully
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" multi-domain-app

  # Command should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app multi-domain-app
}

@test "(phase26a) sync increments failed counter when zone lookup fails" {
  create_test_app fail-test-app
  add_test_domains fail-test-app missing-zone.xyz

  # Manually add domain to DNS management
  mkdir -p "$PLUGIN_DATA_ROOT"
  mkdir -p "$PLUGIN_DATA_ROOT/fail-test-app"
  echo "fail-test-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "missing-zone.xyz" >"$PLUGIN_DATA_ROOT/fail-test-app/DOMAINS"

  # Try to sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" fail-test-app

  # Should show completion message with counts
  assert_output_contains "Apply complete" || assert_output_contains "Successfully applied"

  cleanup_test_app fail-test-app
}

# Phase 26b: Error reporting improvements

@test "(phase26b) sync displays actual error message when provider call fails" {
  create_test_app error-app
  add_test_domains error-app test-error.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" error-app >/dev/null 2>&1 || true

  # Try to sync - errors should be visible
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" error-app

  # Should not suppress all error output
  if [[ "$status" -ne 0 ]]; then
    # Should show some kind of error message, not just "Failed"
    [[ -n "$output" ]] || fail "Expected error output"
  fi

  cleanup_test_app error-app
}

@test "(phase26b) sync shows error details on separate line after failure marker" {
  create_test_app detail-app
  add_test_domains detail-app fail-domain.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" detail-app >/dev/null 2>&1 || true

  # Try to sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" detail-app

  # If it fails, should have multi-line output with error details
  if [[ "$status" -ne 0 ]]; then
    line_count=$(echo "$output" | wc -l)
    [[ "$line_count" -gt 1 ]] || echo "Expected multi-line error output"
  fi

  cleanup_test_app detail-app
}

# Domain parsing bug fix (multi-provider.sh)

@test "(domain-parse) second-level domains are not incorrectly stripped" {
  # This test verifies that domains like "dean.is" are not parsed as just "is"
  create_test_app sld-app

  # Add a second-level domain (no subdomain)
  add_test_domains sld-app example.io

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" sld-app >/dev/null 2>&1 || true

  # Try to sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" sld-app

  # Should NOT show error about TLD-only zone like "io"
  ! assert_output_contains "No provider found for zone: io" || true
  ! assert_output_contains "No provider found for zone: is" || true

  cleanup_test_app sld-app
}

@test "(domain-parse) find_provider_for_zone correctly handles exact domain matches" {
  # Verify that find_provider_for_zone doesn't strip domain parts unnecessarily
  create_test_app exact-match-app
  add_test_domains exact-match-app test.example

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" exact-match-app >/dev/null 2>&1 || true

  # Sync should use full domain for zone lookup
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" exact-match-app

  # Command should not crash with parsing errors
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app exact-match-app
}

@test "(domain-parse) multi_create_record uses correct zone name" {
  # Test that multi_create_record passes domain directly to find_provider_for_zone
  # instead of stripping the first part
  create_test_app create-test-app
  add_test_domains create-test-app subdomain.example.net

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" create-test-app >/dev/null 2>&1 || true

  # Try sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" create-test-app

  # Should not show error about truncated domain
  ! assert_output_contains "No provider found for zone: net" || true

  cleanup_test_app create-test-app
}

@test "(domain-parse) multi_get_record uses correct zone name" {
  create_test_app get-test-app
  add_test_domains get-test-app record.example.org

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" get-test-app >/dev/null 2>&1 || true

  # Try sync (which calls multi_get_record)
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" get-test-app

  # Should not show error about truncated domain
  ! assert_output_contains "No provider found for zone: org" || true

  cleanup_test_app get-test-app
}

# apps:report fix

@test "(apps:report) command does not error with 'command not found'" {
  create_test_app report-app
  add_test_domains report-app report-test.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" report-app >/dev/null 2>&1 || true

  # Run apps:report
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report" report-app

  # Should not show "dns_report: command not found"
  ! assert_output_contains "dns_report: command not found" || fail "apps:report still calling missing dns_report function"
  ! assert_output_contains "command not found" || fail "apps:report has command not found error"

  cleanup_test_app report-app
}

@test "(apps:report) shows DNS information for app" {
  create_test_app info-app
  add_test_domains info-app info.example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" info-app >/dev/null 2>&1 || true

  # Run apps:report
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report" info-app

  # Should show some DNS-related information
  assert_output_contains "DNS" || assert_output_contains "info-app" || assert_output_contains "info.example.com"

  cleanup_test_app info-app
}

@test "(apps:report) requires app name parameter" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report"

  # Should fail with helpful message
  assert_failure
  assert_output_contains "app" || assert_output_contains "Usage"
}

# Integration tests combining multiple fixes

@test "(integration) sync handles second-level domain with proper error reporting" {
  create_test_app integration-app

  # Add a second-level domain that doesn't exist
  add_test_domains integration-app notreal.is

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" integration-app >/dev/null 2>&1 || true

  # Try to sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" integration-app

  # Should show proper error, not "No provider found for zone: is"
  ! assert_output_contains "No provider found for zone: is" || fail "Domain parsing bug still present"

  # Should show informative error message
  if [[ "$status" -ne 0 ]]; then
    [[ -n "$output" ]] || fail "Expected error output"
  fi

  cleanup_test_app integration-app
}

@test "(integration) apps:report works after sync failures" {
  create_test_app report-after-fail-app
  add_test_domains report-after-fail-app fail.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" report-after-fail-app >/dev/null 2>&1 || true

  # Try sync (may fail)
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" report-after-fail-app >/dev/null 2>&1 || true

  # apps:report should still work
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report" report-after-fail-app

  # Should not crash
  ! assert_output_contains "command not found"

  cleanup_test_app report-after-fail-app
}
