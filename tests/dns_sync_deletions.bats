#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  mkdir -p "$PLUGIN_DATA_ROOT"

  # Mock the AWS provider function for sync:deletions tests
  dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"

    # Check for credential failure simulation
    if [[ "${AWS_MOCK_FAIL_CREDENTIALS:-}" == "true" ]]; then
      return 1
    fi

    # Mock implementation for testing
    case "$DOMAIN" in
      "example.com" | *.example.com)
        echo "Z1234567890ABC"
        return 0
        ;;
      "test.org" | *.test.org)
        echo "Z0987654321DEF"
        return 0
        ;;
      *)
        return 1
        ;;
    esac
  }
  export -f dns_provider_aws_get_hosted_zone_id
}

teardown() {
  cleanup_dns_data
  # Restore functions file if backup exists
  if [[ -f "${TEST_TMP_DIR}/functions.orig" ]]; then
    cp "${TEST_TMP_DIR}/functions.orig" "$PLUGIN_ROOT/functions"
  fi
  # Restore main AWS mock
  restore_main_aws_mock
  # Clean up AWS mock control
  clear_aws_mock_record_count
}

@test "(dns:sync:deletions) error with invalid zone argument" {
  # Create a mock ZONES_ENABLED file
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" nonexistent-zone.com

  # Should still run successfully but find no orphaned records
  assert_success
}

@test "(dns:sync:deletions) shows message when no enabled zones" {
  # Ensure no enabled zones
  rm -f "$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Use writable bin directory for CI compatibility
  WRITABLE_BIN=$(setup_writable_test_bin)

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No enabled zones found"
  assert_output_contains "Use 'dokku dns:zones:enable <zone>' to enable zones first"
}

@test "(dns:sync:deletions) shows message when no records to be deleted found" {
  # Create enabled zones but no records to be deleted
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 0 records
  set_aws_mock_record_count 0

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No DNS records to be deleted"
  assert_output_contains "All DNS records correspond to active Dokku domains"
}

@test "(dns:sync:deletions) displays Terraform-style plan output for records to be deleted" {
  # Create enabled zones
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 2 records that will be considered for deletion
  set_aws_mock_record_count 2 "old-app"

  # Mock get_app_domains to return no domains (making all DNS records eligible for deletion)
  # Save original functions file and restore it after test
  cp "$PLUGIN_ROOT/functions" "${TEST_TMP_DIR}/functions.orig"

  cat >>"$PLUGIN_ROOT/functions" <<'EOF'

get_app_domains() {
  echo ""
}
EOF

  run bash -c 'echo "n" | dokku '\"$PLUGIN_COMMAND_PREFIX\"':sync:deletions'
  assert_success
  assert_output_contains "Planned Deletions:"
  assert_output_contains "- old-app-1.example.com (A record)"
  assert_output_contains "- old-app-2.example.com (A record)"
  assert_output_contains "Plan: 0 to add, 0 to change, 2 to destroy"

  # Restore original functions file
  cp "${TEST_TMP_DIR}/functions.orig" "$PLUGIN_ROOT/functions"
}

@test "(dns:sync:deletions) handles zone-specific cleanup" {
  # Create multiple enabled zones
  echo -e "example.com\ntest.org" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 1 record for example.com zone only
  set_aws_mock_record_count 1 "old-app"

  run bash -c 'echo "n" | dokku '\"$PLUGIN_COMMAND_PREFIX\"':sync:deletions example.com'
  assert_success
  assert_output_contains "Scanning zone: example.com"
  assert_output_contains "- old-app.example.com (A record)"
  # Should not contain any test.org records (since we're only scanning example.com zone)
  [[ "$output" != *"test.org"* ]]
}

@test "(dns:sync:deletions) filters out current app domains from deletion list" {
  # Create test app with domains
  create_test_app current-app
  add_test_domains current-app current.example.com

  # Enable DNS for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" current-app >/dev/null 2>&1

  # Create enabled zones
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return both current and records to be deleted
  # The mock will return record-to-delete.example.com as a DNS record that should be filtered
  set_aws_mock_record_count 1 "record-to-delete"

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success

  # Should show record to be deleted but not current app domain
  assert_output_contains "- record-to-delete.example.com (A record)"
  [[ "$output" != *"- current.example.com (A record)"* ]]
  assert_output_contains "Plan: 0 to add, 0 to change, 1 to destroy"

  cleanup_test_app current-app
}

@test "(dns:sync:deletions) handles user cancellation gracefully" {
  # Create enabled zones with records to be deleted
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 1 record to be deleted
  set_aws_mock_record_count 1 "record-to-delete"

  # Mock user input to simulate 'n' (no) response
  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deletion cancelled"
}

@test "(dns:sync:deletions) attempts deletion when user confirms" {
  # Create enabled zones with records to be deleted
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 1 record to be deleted
  set_aws_mock_record_count 1 "record-to-delete"

  # Mock user input to simulate 'y' (yes) response
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deleting DNS records..."
  assert_output_contains "Deleting: record-to-delete.example.com"
  assert_output_contains "Deleted: record-to-delete.example.com (A record)"
  assert_output_contains "Deleted 1 of 1 DNS records"
}

@test "(dns:sync:deletions) handles AWS API failures gracefully" {
  # Create enabled zones
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set AWS mock to return 1 record to be deleted
  set_aws_mock_record_count 1 "record-to-delete"

  # Force API failure mode for reliable testing across different CI environments
  export AWS_MOCK_FAIL_API="true"

  # Mock user input to simulate 'y' (yes) response
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Failed to delete: record-to-delete.example.com"
  assert_output_contains "Deleted 0 of 1 DNS records"

  # Clean up environment variable to not affect other tests
  unset AWS_MOCK_FAIL_API
}

@test "(dns:sync:deletions) handles missing AWS credentials" {
  # Create enabled zones
  echo "example.com" >"$PLUGIN_DATA_ROOT/ZONES_ENABLED"

  # Set environment variable to simulate credential failure
  export AWS_MOCK_FAIL_CREDENTIALS=true

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  # Should handle gracefully and show warning about hosted zone
  assert_output_contains "Could not find AWS hosted zone for: example.com"
}
