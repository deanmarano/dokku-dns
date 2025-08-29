#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  mkdir -p "$PLUGIN_DATA_ROOT"
}

teardown() {
  cleanup_dns_data
}

@test "(dns:sync:deletions) error with invalid zone argument" {
  # Create a mock ZONES_ENABLED file
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" nonexistent-zone.com
  
  # Should still run successfully but find no orphaned records
  assert_success
}

@test "(dns:sync:deletions) shows message when no enabled zones" {
  # Ensure no enabled zones
  rm -f "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No enabled zones found"
  assert_output_contains "Use 'dokku dns:zones:enable <zone>' to enable zones first"
}

@test "(dns:sync:deletions) shows message when no orphaned records found" {
  # Create enabled zones but no orphaned records
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to return no A records
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    echo ""
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No orphaned DNS records found"
  assert_output_contains "All DNS records correspond to active Dokku domains"
}

@test "(dns:sync:deletions) displays Terraform-style plan output for orphaned records" {
  # Create enabled zones
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to return some A records
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    echo -e "old-app.example.com.\norphaned.example.com."
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  # Mock get_app_domains to return no domains (making all DNS records orphaned)
  cat >> "$PLUGIN_ROOT/functions" << 'EOF'

get_app_domains() {
  echo ""
}
EOF
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "Planned Deletions:"
  assert_output_contains "- old-app.example.com (A record)"
  assert_output_contains "- orphaned.example.com (A record)"
  assert_output_contains "Plan: 0 to add, 0 to change, 2 to destroy"
  assert_output_contains "Do you want to delete these 2 orphaned DNS records? [y/N]"
}

@test "(dns:sync:deletions) handles zone-specific cleanup" {
  # Create multiple enabled zones
  echo -e "example.com\ntest.org" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to return records for specific zone only
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    # Only return records if we're querying example.com zone
    if [[ "$*" == *"example.com"* ]]; then
      echo -e "old-app.example.com."
    else
      echo ""
    fi
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" example.com
  assert_success
  assert_output_contains "Scanning zone: example.com"
  assert_output_contains "- old-app.example.com (A record)"
  # Should not contain any test.org records
  refute_output_contains "test.org"
}

@test "(dns:sync:deletions) filters out current app domains from deletion list" {
  # Create test app with domains
  create_test_app current-app
  add_test_domains current-app current.example.com
  
  # Enable DNS for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" current-app >/dev/null 2>&1
  
  # Create enabled zones
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to return both current and orphaned records
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    echo -e "current.example.com.\norphaned.example.com."
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  
  # Should show orphaned record but not current app domain
  assert_output_contains "- orphaned.example.com (A record)"
  refute_output_contains "- current.example.com (A record)"
  assert_output_contains "Plan: 0 to add, 0 to change, 1 to destroy"
  
  cleanup_test_app current-app
}

@test "(dns:sync:deletions) handles user cancellation gracefully" {
  # Create enabled zones with orphaned records
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to return orphaned records
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    echo "orphaned.example.com."
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  # Mock user input to simulate 'n' (no) response
  run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deletion cancelled by user"
}

@test "(dns:sync:deletions) attempts deletion when user confirms" {
  # Create enabled zones with orphaned records
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Track AWS CLI calls
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    if [[ "$*" == *"Name=='orphaned.example.com.'"* ]]; then
      # Return record value for deletion
      echo "192.168.1.100"
    else
      # Return record names for scanning
      echo "orphaned.example.com."
    fi
    ;;
  *"change-resource-record-sets"*)
    # Mock successful deletion
    echo '{"ChangeInfo":{"Id":"/change/C123456789","Status":"PENDING"}}'
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  # Mock user input to simulate 'y' (yes) response
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "Deleting orphaned DNS records..."
  assert_output_contains "Deleting: orphaned.example.com"
  assert_output_contains "✅ Deleted: orphaned.example.com (A record)"
  assert_output_contains "Successfully deleted 1 of 1 orphaned DNS records"
}

@test "(dns:sync:deletions) handles AWS API failures gracefully" {
  # Create enabled zones
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to fail on deletion
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"list-resource-record-sets"*"--query"*"ResourceRecordSets"*)
    if [[ "$*" == *"Name=='orphaned.example.com.'"* ]]; then
      # Return record value for deletion
      echo "192.168.1.100"
    else
      # Return record names for scanning
      echo "orphaned.example.com."
    fi
    ;;
  *"change-resource-record-sets"*)
    # Mock failed deletion
    echo "Error: Access denied" >&2
    exit 1
    ;;
  *"get-caller-identity"*)
    echo '{"Account":"123456789012","UserId":"AIDACKCEVSQ6C2EXAMPLE","Arn":"arn:aws:iam::123456789012:user/test"}'
    ;;
  *)
    echo "Mock AWS CLI - unexpected call: $*" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  # Mock user input to simulate 'y' (yes) response
  run bash -c 'echo "y" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
  assert_success
  assert_output_contains "❌ Failed to delete: orphaned.example.com"
  assert_output_contains "Successfully deleted 0 of 1 orphaned DNS records"
}

@test "(dns:sync:deletions) handles missing AWS credentials" {
  # Create enabled zones
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  # Mock AWS CLI to fail authentication
  cat > "${TEST_BIN_DIR}/aws" << 'EOF'
#!/bin/bash
case "$*" in
  *"get-caller-identity"*)
    echo "Unable to locate credentials" >&2
    exit 1
    ;;
  *)
    echo "Unable to locate credentials" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "${TEST_BIN_DIR}/aws"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  # Should handle gracefully and show warning about hosted zone
  assert_output_contains "Could not find AWS hosted zone for: example.com"
}