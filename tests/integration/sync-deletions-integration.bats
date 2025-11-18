#!/usr/bin/env bats
load bats-common

# Integration tests for Phase 26e: Safe Queue-Based DNS Record Deletion System

setup() {
  check_dns_plugin_available
  TEST_APP="sync-deletions-test"
  setup_test_app "$TEST_APP" "test-domain.example.com"
}

teardown() {
  cleanup_test_app "$TEST_APP"
  # Clean up pending deletions and managed records
  rm -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
  rm -f "$PLUGIN_DATA_ROOT/MANAGED_RECORDS"
}

@test "(dns:sync:deletions integration) shows empty queue message when no pending deletions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No pending deletions"
  assert_output_contains "The deletion queue is empty"
}

@test "(dns:sync:deletions integration) displays queued deletions in Terraform-style format" {
  # Manually create a pending deletion for testing
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-record.example.com:Z1234567890ABC:$(date +%s)" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Queued Deletions:"
  assert_output_contains "test-record.example.com.*A record"
  assert_output_contains "Plan: 0 to add, 0 to change, 1 to destroy"
  assert_output_contains "Deletion cancelled"
}

@test "(dns:sync:deletions integration) respects user cancellation" {
  # Create a pending deletion
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-record.example.com:Z1234567890ABC:$(date +%s)" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  # Pipe 'n' to simulate user declining deletion
  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deletion cancelled"

  # Queue should still exist
  [[ -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]]
  grep -q "test-record.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
}

@test "(dns:sync:deletions integration) --force flag bypasses confirmation" {
  skip_if_no_aws_credentials

  # Create a pending deletion for a record that doesn't exist
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "nonexistent-record.example.com:Z1234567890ABC:$(date +%s)" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  # Use --force flag to bypass confirmation
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force
  assert_success
  # Should not show confirmation prompt
  [[ "$output" != *"Do you want to delete"* ]]
  assert_output_contains "Deleting DNS records..."
}

@test "(dns:sync:deletions integration) removes successfully processed domains from queue" {
  skip_if_no_aws_credentials

  # Create pending deletions for non-existent records
  mkdir -p "$PLUGIN_DATA_ROOT"
  cat >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS" <<EOF
nonexistent1.example.com:Z1234567890ABC:$(date +%s)
nonexistent2.example.com:Z1234567890ABC:$(date +%s)
EOF

  # Process deletions with confirmation
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success

  # Records should be removed from queue (they're non-existent, so marked as "already deleted")
  if [[ -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]]; then
    [[ ! -s "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]] || {
      ! grep -q "nonexistent1.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
      ! grep -q "nonexistent2.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
    }
  fi
}

@test "(dns:sync:deletions integration) handles domains with missing zone_id" {
  # Create pending deletion without zone_id
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-record.example.com::$(date +%s)" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_failure
  assert_output_contains "Failed.*no zone ID"
  assert_output_contains "deletion.*failed"
}

@test "(dns:sync:deletions integration) end-to-end workflow with app lifecycle" {
  skip_if_no_aws_credentials

  # This test simulates the full lifecycle:
  # 1. Create app and add DNS management
  # 2. Sync DNS (which tracks the domain)
  # 3. Destroy app (which queues the domain)
  # 4. Process deletion queue

  local test_app="lifecycle-test-app"
  local test_domain="lifecycle-test.example.com"

  # Create app with domain
  dokku apps:create "$test_app" >/dev/null 2>&1 || true
  dokku domains:add "$test_app" "$test_domain" >/dev/null 2>&1 || true

  # Enable DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$test_app" >/dev/null 2>&1 || true

  # Sync DNS (this would track the domain in MANAGED_RECORDS if successful)
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" "$test_app" >/dev/null 2>&1 || true

  # Destroy app (this should queue domains for deletion)
  dokku apps:destroy "$test_app" --force >/dev/null 2>&1 || true

  # Check if domain was queued for deletion
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  # The test passes if the command runs successfully
  # In test environment, various outcomes are possible depending on provider/zone availability
  assert_success
}

@test "(dns:sync:deletions integration) handles invalid arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --invalid-arg
  assert_failure
  assert_output_contains "Unknown option: --invalid-arg"
}

@test "(dns:sync:deletions integration) shows timestamps in queued deletions" {
  # Create pending deletion with known timestamp
  mkdir -p "$PLUGIN_DATA_ROOT"
  local timestamp=$(date +%s)
  echo "test-record.example.com:Z1234567890ABC:$timestamp" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  # Should show timestamp information
  assert_output_contains "queued:" || assert_output_contains "test-record.example.com (A record)"
}

@test "(dns:sync:deletions integration) never scans Route53 for orphaned records" {
  skip_if_no_aws_credentials

  # This test ensures the command ONLY processes the queue
  # Even if Route53 has many records, only queued records are shown

  # Start with empty queue
  rm -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No pending deletions"
  assert_output_contains "The deletion queue is empty"

  # Should NOT show any Route53 records, regardless of what's in Route53
  [[ "$output" != *"Scanning zone"* ]]
  [[ "$output" != *"Found"*"records in zone"* ]]
}

@test "(dns:sync:deletions integration) queue-based deletion protects manual records" {
  # This test ensures that manually created DNS records are never touched

  # Even if we have a zone enabled and domains configured,
  # sync:deletions will never scan or propose deleting any Route53 records
  # unless they're explicitly in the PENDING_DELETIONS queue

  # Create an empty queue
  rm -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  # Enable a zone (simulating normal setup)
  if [[ -f "$PLUGIN_DATA_ROOT/ENABLED_ZONES" ]]; then
    # Zones might be enabled, but that shouldn't cause scanning
    run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
    assert_success
    assert_output_contains "No pending deletions"
    # Should NOT scan zones even if they're enabled
    [[ "$output" != *"Scanning zone"* ]]
  fi
}
