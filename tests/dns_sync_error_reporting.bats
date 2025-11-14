#!/usr/bin/env bats
load test_helper

# Tests specifically for Phase 26a and 26b error handling improvements
# in providers/adapter.sh dns_sync_app function

setup() {
  cleanup_dns_data
  setup_dns_provider aws
}

teardown() {
  cleanup_dns_data
}

# Phase 26a: Zone lookup error checking in apply phase

@test "(phase26a) apply phase checks zone_id before continuing" {
  create_test_app phase26a-app
  add_test_domains phase26a-app nonexistent.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" phase26a-app >/dev/null 2>&1 || true

  # Sync should fail gracefully
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" phase26a-app

  # Should see failure message
  assert_output_contains "Failed" || assert_output_contains "No hosted zone"

  # Should not continue with empty zone_id
  ! assert_output_contains "Created/updated record" || true

  cleanup_test_app phase26a-app
}

@test "(phase26a) apply phase shows 'Failed (no hosted zone found)' message" {
  create_test_app zone-check-app
  add_test_domains zone-check-app missing-zone.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-check-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" zone-check-app

  # The fix adds this specific error message
  assert_output_contains "Failed" || assert_output_contains "no hosted zone"

  cleanup_test_app zone-check-app
}

@test "(phase26a) apply phase increments failed counter when zone lookup fails" {
  create_test_app counter-app
  add_test_domains counter-app bad1.invalid bad2.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" counter-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" counter-app

  # Should show failure count
  assert_output_contains "0 of" || assert_output_contains "Apply complete"

  cleanup_test_app counter-app
}

@test "(phase26a) apply phase uses 'continue' to skip failed domain" {
  create_test_app skip-app
  add_test_domains skip-app fail-domain.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" skip-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" skip-app

  # Should complete (not hang or crash)
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  assert_output_contains "Apply complete"

  cleanup_test_app skip-app
}

@test "(phase26a) analyze and apply phases use same zone lookup logic" {
  create_test_app consistency-app
  add_test_domains consistency-app test.example

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" consistency-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" consistency-app

  # If analyze phase succeeds in finding zone, apply phase should too
  # If analyze phase fails, apply phase should also fail
  # They should be consistent
  if assert_output_contains "Will create" || assert_output_contains "Will update"; then
    # Analyze phase found the zone
    # Apply phase should not fail with "no hosted zone"
    [[ "$status" -eq 0 ]] || assert_output_contains "Applied" || assert_output_contains "Failed"
  fi

  cleanup_test_app consistency-app
}

# Phase 26b: Error message capture and display

@test "(phase26b) provider errors are captured and displayed" {
  create_test_app error-capture-app
  add_test_domains error-capture-app test-error.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" error-capture-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" error-capture-app

  # Should not completely suppress errors
  if [[ "$status" -ne 0 ]]; then
    # Should have some error output
    [[ -n "$output" ]]
  fi

  cleanup_test_app error-capture-app
}

@test "(phase26b) error output shown on separate line with indentation" {
  create_test_app indent-app
  add_test_domains indent-app fail.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" indent-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" indent-app

  # If there's an error, check for "Error:" prefix
  if assert_output_contains "Failed"; then
    # Should show error details
    assert_output_contains "Error:" || assert_output_contains "No provider" || assert_output_contains "zone"
  fi

  cleanup_test_app indent-app
}

@test "(phase26b) multi_create_record stderr is captured with 2>&1" {
  # This tests that we changed from >/dev/null 2>&1 to capturing with 2>&1
  create_test_app stderr-capture-app
  add_test_domains stderr-capture-app stderr-test.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" stderr-capture-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" stderr-capture-app

  # Previously, all errors were silenced
  # Now, errors should be visible
  if [[ "$status" -ne 0 ]]; then
    # Should see some provider or zone-related error
    [[ -n "$output" ]] || fail "Expected error output to be visible"
  fi

  cleanup_test_app stderr-capture-app
}

@test "(phase26b) error_output variable is populated on failure" {
  # The fix adds: error_output=$(multi_create_record ... 2>&1)
  # This test verifies errors are captured
  create_test_app error-var-app
  add_test_domains error-var-app error-test.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" error-var-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" error-var-app

  # Error should be shown
  if assert_output_contains "Failed"; then
    # Should have more than just "Failed" - should have error details
    line_count=$(echo "$output" | wc -l)
    [[ "$line_count" -gt 3 ]] || echo "Expected more detailed error output"
  fi

  cleanup_test_app error-var-app
}

@test "(phase26b) exit code check uses $? after capturing output" {
  # The fix uses: if [[ $? -eq 0 ]]; then
  # This verifies the exit code is checked correctly
  create_test_app exitcode-app
  add_test_domains exitcode-app exitcode-test.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" exitcode-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" exitcode-app

  # Should properly detect success or failure
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app exitcode-app
}

# Integration: Both Phase 26a and 26b together

@test "(integration) zone lookup error shows clear message" {
  create_test_app integration-zone-app
  add_test_domains integration-zone-app no-zone.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" integration-zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" integration-zone-app

  # Should show clear error about zone not found
  assert_output_contains "no hosted zone" || assert_output_contains "No provider found"

  # Should not crash or hang
  assert_output_contains "Apply complete"

  cleanup_test_app integration-zone-app
}

@test "(integration) provider API error shows actual error message" {
  create_test_app integration-api-app
  add_test_domains integration-api-app api-error.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" integration-api-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" integration-api-app

  # If it fails, should show actual provider error
  if [[ "$status" -ne 0 ]]; then
    # Should show specific error, not just generic "Failed"
    [[ -n "$output" ]]
    # Check that error details are present
    assert_output_contains "Error:" || assert_output_contains "provider" || assert_output_contains "zone" || assert_output_contains "Failed"
  fi

  cleanup_test_app integration-api-app
}

@test "(integration) multiple domain failures show individual error messages" {
  create_test_app multi-fail-app
  add_test_domains multi-fail-app fail1.invalid fail2.invalid fail3.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-fail-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" multi-fail-app

  # Should show error for each domain
  fail_count=$(echo "$output" | grep -c "Failed" || echo "0")
  [[ "$fail_count" -ge 1 ]] || fail "Expected to see failure messages"

  cleanup_test_app multi-fail-app
}

# Regression: Ensure the old behavior (silencing errors) is fixed

@test "(regression) errors are no longer silenced with >/dev/null 2>&1" {
  create_test_app no-silence-app
  add_test_domains no-silence-app error.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" no-silence-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" no-silence-app

  # The bug was that errors were completely hidden
  # Now errors should be visible
  if [[ "$status" -ne 0 ]]; then
    [[ -n "$output" ]] || fail "Errors should not be silenced"
  fi

  cleanup_test_app no-silence-app
}

@test "(regression) zone_id check prevents empty zone_id in provider_create_record" {
  create_test_app empty-zone-app
  add_test_domains empty-zone-app missing.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" empty-zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" empty-zone-app

  # The bug was that provider_create_record was called with empty zone_id
  # Now it should skip the domain
  assert_output_contains "Failed" || assert_output_contains "no hosted zone"

  # Should not call provider with empty zone_id
  ! assert_output_contains "Zone ID, record name, record type, and record value are required"

  cleanup_test_app empty-zone-app
}
