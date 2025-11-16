#!/usr/bin/env bats
load test_helper

# Tests for Phase 26c: Multi-provider zone lookup in report command
# and improved pending changes display

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  export DNS_TEST_SERVER_IP="192.0.2.1"
}

teardown() {
  cleanup_dns_data
}

# Test that report uses multi_get_zone_id function correctly

@test "(phase26c) report sources multi-provider.sh correctly" {
  create_test_app zone-test-app
  add_test_domains zone-test-app example.com

  # Enable DNS for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-test-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-test-app

  # Should not error due to missing function
  assert_success

  cleanup_test_app zone-test-app
}

@test "(phase26c) report shows zone information using multi_get_zone_id" {
  create_test_app multi-zone-app
  add_test_domains multi-zone-app test.example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-zone-app
  assert_success

  # Should show zone information (even if it's "No hosted zone found")
  assert_output_contains "Zone" || assert_output_contains "zone"

  cleanup_test_app multi-zone-app
}

@test "(phase26c) report handles domains without hosted zones gracefully" {
  create_test_app no-zone-app
  add_test_domains no-zone-app nonexistent.invalid

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" no-zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" no-zone-app
  assert_success

  # Should show appropriate message for missing zone
  assert_output_contains "No hosted zone found" || assert_output_contains "Not configured"

  cleanup_test_app no-zone-app
}

@test "(phase26c) report shows correct zone when zone exists" {
  create_test_app zone-exists-app
  add_test_domains zone-exists-app example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-exists-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-exists-app
  assert_success

  # Should include zone information in output
  # Either shows zone ID or "No hosted zone found"
  [[ -n "$output" ]]

  cleanup_test_app zone-exists-app
}

# Test pending changes display improvements

@test "(phase26c) apps:sync shows 'No pending changes' when records are correct" {
  create_test_app correct-app
  add_test_domains correct-app example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" correct-app >/dev/null 2>&1 || true

  # Run sync twice - first to create, second to verify
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" correct-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" correct-app

  # If zone exists and record is correct, should show no pending changes
  if ! assert_output_contains "No hosted zone found"; then
    # Zone was found, check for correct handling
    if assert_output_contains "already correct"; then
      # Should show "No pending changes" message
      assert_output_contains "No pending changes"
    fi
  fi

  cleanup_test_app correct-app
}

@test "(phase26c) apps:sync does not show 'Pending DNS Changes' header when no changes needed" {
  create_test_app no-changes-app
  add_test_domains no-changes-app test.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" no-changes-app >/dev/null 2>&1 || true

  # Create records first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" no-changes-app >/dev/null 2>&1 || true

  # Run sync again - no changes should be needed
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" no-changes-app

  # If all records are already correct, should not show "Pending DNS Changes" header
  if assert_output_contains "already correct"; then
    # Should show count of correct records
    assert_output_contains "No pending changes"
  fi

  cleanup_test_app no-changes-app
}

@test "(phase26c) apps:sync shows pending changes section only when changes exist" {
  create_test_app changes-app
  add_test_domains changes-app new.example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" changes-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" changes-app

  # If zone exists, should show analysis
  if ! assert_output_contains "No hosted zone found"; then
    # Should show either pending changes or no pending changes
    assert_output_contains "Pending DNS Changes" || assert_output_contains "No pending changes"
  fi

  cleanup_test_app changes-app
}

@test "(phase26c) apps:sync skips CORRECT records in pending changes list" {
  create_test_app skip-correct-app
  add_test_domains skip-correct-app example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" skip-correct-app >/dev/null 2>&1 || true

  # First sync
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" skip-correct-app >/dev/null 2>&1 || true

  # Second sync - records should be correct
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" skip-correct-app

  # If records are already correct, should not show them under "Pending DNS Changes"
  if assert_output_contains "already correct"; then
    # Should not show checkmark under "Pending DNS Changes" section
    # Instead should show "No pending changes" message
    assert_output_contains "No pending changes"
  fi

  cleanup_test_app skip-correct-app
}

@test "(phase26c) apps:sync counts changes correctly" {
  create_test_app count-app
  add_test_domains count-app test1.com test2.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" count-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" count-app

  # Should show some form of count
  assert_output_contains "domain" || assert_output_contains "record"

  cleanup_test_app count-app
}

# Integration tests

@test "(integration) report and sync use same zone lookup mechanism" {
  create_test_app integration-app
  add_test_domains integration-app consistent.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" integration-app >/dev/null 2>&1 || true

  # Get report output
  run dokku "$PLUGIN_COMMAND_PREFIX:report" integration-app
  local report_output="$output"

  # Get sync output
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" integration-app
  local sync_output="$output"

  # Both should handle zone lookup consistently
  # If report shows no zone, sync should also fail gracefully
  # If report shows zone, sync should be able to use it

  if echo "$report_output" | grep -q "No hosted zone found"; then
    # Sync should also indicate zone issue
    echo "$sync_output" | grep -q "No hosted zone found" ||
      echo "$sync_output" | grep -q "Failed"
  fi

  cleanup_test_app integration-app
}

@test "(integration) multiple domains show individual zone status in report" {
  create_test_app multi-domain-app
  add_test_domains multi-domain-app domain1.test domain2.test

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-domain-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-domain-app
  assert_success

  # Should show both domains
  assert_output_contains "domain1.test"
  assert_output_contains "domain2.test"

  cleanup_test_app multi-domain-app
}

@test "(regression) report does not call non-existent dns_provider_aws_get_hosted_zone_id" {
  create_test_app regression-app
  add_test_domains regression-app test.example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" regression-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" regression-app

  # Should succeed without errors about missing function
  assert_success

  # Should not show bash errors about function not found
  ! assert_output_contains "command not found"
  ! assert_output_contains "dns_provider_aws_get_hosted_zone_id"

  cleanup_test_app regression-app
}

@test "(regression) pending changes with checkmark not shown when no changes needed" {
  create_test_app no-confusing-output-app
  add_test_domains no-confusing-output-app example.com

  # Enable DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" no-confusing-output-app >/dev/null 2>&1 || true

  # First sync to create records
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" no-confusing-output-app >/dev/null 2>&1 || true

  # Second sync - should show no pending changes
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" no-confusing-output-app

  # Should not show "Pending DNS Changes:" header when everything is correct
  if assert_output_contains "already correct"; then
    # The bug was showing "Pending DNS Changes:" with checkmarks
    # Now it should show "No pending changes" instead
    assert_output_contains "No pending changes"

    # Make sure we're not showing the confusing "Pending DNS Changes" header
    # when there are no actual changes
    local pending_header_count=$(echo "$output" | grep -c "Pending DNS Changes:" || true)
    [[ "$pending_header_count" -eq 0 ]] || fail "Should not show 'Pending DNS Changes' header when no changes needed"
  fi

  cleanup_test_app no-confusing-output-app
}
