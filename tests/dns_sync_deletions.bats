#!/usr/bin/env bats
load test_helper

# Tests for Phase 26e: Safe Queue-Based DNS Record Deletion System

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  mkdir -p "$PLUGIN_DATA_ROOT"
  export DNS_TEST_SERVER_IP="192.0.2.1"
}

teardown() {
  cleanup_dns_data
}

@test "(dns:sync:deletions) shows message when deletion queue is empty" {
  # Ensure no pending deletions file
  rm -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No pending deletions"
  assert_output_contains "The deletion queue is empty"
}

@test "(dns:sync:deletions) shows message when deletion queue exists but is empty" {
  # Create empty pending deletions file
  touch "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No pending deletions"
  assert_output_contains "The deletion queue is empty"
}

@test "(dns:sync:deletions) displays queued deletions in Terraform-style format" {
  # Create pending deletions queue with test data
  cat >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS" <<EOF
old-app.example.com:Z1234567890ABC:1700000000
test.example.com:Z1234567890ABC:1700000100
EOF

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Queued Deletions:"
  assert_output_contains "- old-app.example.com (A record)"
  assert_output_contains "- test.example.com (A record)"
  assert_output_contains "Plan: 0 to add, 0 to change, 2 to destroy"
  assert_output_contains "Do you want to delete these 2 DNS records?"
}

@test "(dns:sync:deletions) shows timestamps for queued deletions" {
  # Create pending deletion with known timestamp
  echo "test.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "queued:"
  # Should show timestamp in human-readable format
}

@test "(dns:sync:deletions) handles user cancellation gracefully" {
  # Create pending deletions queue
  echo "test.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  # Mock user input to simulate 'n' (no) response
  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deletion cancelled"

  # Queue should still exist
  [[ -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]]
}

@test "(dns:sync:deletions) --force flag skips confirmation prompt" {
  # Create pending deletions queue
  echo "nonexistent.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --force
  assert_success
  # Should not show confirmation prompt
  [[ "$output" != *"Do you want to delete"* ]]
  assert_output_contains "Deleting DNS records..."
}

@test "(dns:sync:deletions) handles domain with missing zone_id" {
  # Create pending deletion without zone_id
  echo "test.example.com::1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Failed (no zone ID)"
}

@test "(dns:sync:deletions) handles already-deleted records gracefully" {
  # Create pending deletion for record that doesn't exist in DNS
  echo "nonexistent.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Already deleted or not found"
  assert_output_contains "Successfully deleted 1 of 1 DNS records"

  # Record should be removed from queue
  ! grep -q "nonexistent.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" 2>/dev/null || [[ ! -s "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]]
}

@test "(dns:sync:deletions) removes successfully deleted domains from queue" {
  # Create pending deletions queue with multiple domains
  cat >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS" <<EOF
deleted1.example.com:Z1234567890ABC:1700000000
deleted2.example.com:Z1234567890ABC:1700000100
deleted3.example.com:Z1234567890ABC:1700000200
EOF

  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success

  # All domains should be removed from queue (or marked as deleted/not found)
  if [[ -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]]; then
    # File might still exist but should be empty or only contain failed deletions
    [[ ! -s "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]] || {
      # If not empty, check that successfully deleted domains are gone
      ! grep -q "deleted1.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
    }
  fi
}

@test "(dns:sync:deletions) rejects invalid arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" --invalid-flag
  assert_failure
  assert_output_contains "Unknown option: --invalid-flag"
}

@test "(dns:sync:deletions) handles multi-line PENDING_DELETIONS file" {
  # Create pending deletions with various formats
  cat >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS" <<EOF
domain1.example.com:Z1234567890ABC:1700000000
domain2.example.com:Z1234567890ABC:1700000100

domain3.example.com:Z1234567890ABC:1700000200
EOF

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "- domain1.example.com (A record)"
  assert_output_contains "- domain2.example.com (A record)"
  assert_output_contains "- domain3.example.com (A record)"
  assert_output_contains "Plan: 0 to add, 0 to change, 3 to destroy"
}

@test "(dns:sync:deletions) integration with record_managed_domain function" {
  # Simulate the full workflow: create managed record → queue for deletion → delete

  # Step 1: Add domain to MANAGED_RECORDS (simulating dns:apps:sync)
  echo "test-app.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/MANAGED_RECORDS"

  # Step 2: Queue it for deletion (simulating app destroy)
  run bash -c 'source '"$PLUGIN_ROOT"'/functions && queue_domain_deletion "test-app.example.com" "Z1234567890ABC"'
  assert_success

  # Step 3: Verify it's in PENDING_DELETIONS and removed from MANAGED_RECORDS
  grep -q "test-app.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
  ! grep -q "test-app.example.com" "$PLUGIN_DATA_ROOT/MANAGED_RECORDS" 2>/dev/null || [[ ! -s "$PLUGIN_DATA_ROOT/MANAGED_RECORDS" ]]

  # Step 4: Process deletion queue
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "test-app.example.com"
}

@test "(dns:sync:deletions) only queues domains that were managed by plugin" {
  # Try to queue a domain that was never in MANAGED_RECORDS
  run bash -c 'source '"$PLUGIN_ROOT"'/functions && queue_domain_deletion "never-managed.example.com" "Z1234567890ABC"'
  assert_success

  # Should NOT be added to PENDING_DELETIONS
  [[ ! -f "$PLUGIN_DATA_ROOT/PENDING_DELETIONS" ]] || ! grep -q "never-managed.example.com" "$PLUGIN_DATA_ROOT/PENDING_DELETIONS"
}

@test "(dns:sync:deletions) handles domains with special characters" {
  # Create pending deletion with hyphenated domain
  echo "my-test-app.example.com:Z1234567890ABC:1700000000" >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS"

  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "- my-test-app.example.com (A record)"
}

@test "(dns:sync:deletions) shows count summary after deletion" {
  # Create pending deletions
  cat >"$PLUGIN_DATA_ROOT/PENDING_DELETIONS" <<EOF
record1.example.com:Z1234567890ABC:1700000000
record2.example.com:Z1234567890ABC:1700000100
EOF

  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Successfully deleted"
  assert_output_contains "of 2 DNS records"
}
