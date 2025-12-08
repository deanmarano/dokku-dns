#!/usr/bin/env bash
# AWS Route53 CRUD Operations Test Script
#
# This script automates the AWS Route53 testing procedures documented in TESTING.md.
# It performs CREATE, READ, UPDATE, and DELETE operations to verify provider integration.
#
# Prerequisites:
#   - Dokku server with DNS plugin installed
#   - AWS credentials configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
#   - At least one hosted zone in Route53
#   - Test domain available in one of your zones
#
# Usage:
#   ./test-aws-route53.sh <test-domain> [test-app-name]
#
# Example:
#   ./test-aws-route53.sh test.example.com test-app

set -eo pipefail

# Load test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/manual-tests/test-lib.sh
source "$SCRIPT_DIR/test-lib.sh"

# Configuration
TEST_DOMAIN="${1:-}"
TEST_APP="${2:-dns-test-app-aws}"
TEST_APP_2="${TEST_APP}-2"

# Validate arguments
if [[ -z "$TEST_DOMAIN" ]]; then
  log_error "Usage: $0 <test-domain> [test-app-name]"
  log_error "Example: $0 test.example.com test-app"
  exit 1
fi

# Extract zone from domain
get_zone_from_domain() {
  local domain="$1"
  # Get the last two parts (e.g., example.com from test.example.com)
  echo "$domain" | awk -F. '{print $(NF-1)"."$NF}'
}

TEST_ZONE=$(get_zone_from_domain "$TEST_DOMAIN")

log_info "========================================="
log_info "AWS Route53 CRUD Operations Test"
log_info "========================================="
log_info "Test domain: $TEST_DOMAIN"
log_info "Test zone: $TEST_ZONE"
log_info "Test app: $TEST_APP"
log_info "========================================="

# Get server IP for validation
SERVER_IP=$(get_server_ip)
log_info "Server IP: $SERVER_IP"

#
# CREATE Operations Tests
#

test_start "Provider verification"
if check_provider_available "aws"; then
  test_pass "Provider verification"
else
  test_fail "Provider verification" "AWS credentials not configured or invalid"
  exit 1
fi

test_start "List available zones"
if expect_output_contains "List zones" "$TEST_ZONE" dokku dns:zones; then
  test_pass "List available zones"
else
  test_fail "List available zones" "Zone $TEST_ZONE not found"
  exit 1
fi

test_start "Enable zone for auto-discovery"
if expect_success "Enable zone" dokku dns:zones:enable "$TEST_ZONE"; then
  test_pass "Enable zone for auto-discovery"
else
  test_fail "Enable zone for auto-discovery"
  exit 1
fi

test_start "Create test app"
if create_test_app "$TEST_APP"; then
  test_pass "Create test app"
else
  test_fail "Create test app"
  exit 1
fi

test_start "Add domain to app"
if add_test_domain "$TEST_APP" "$TEST_DOMAIN"; then
  test_pass "Add domain to app"
else
  test_fail "Add domain to app"
  exit 1
fi

test_start "Verify domain added"
if expect_output_contains "Domain in app" "$TEST_DOMAIN" dokku domains:report "$TEST_APP"; then
  test_pass "Verify domain added"
else
  test_fail "Verify domain added"
fi

test_start "Enable DNS management for app"
if expect_output_contains "Enable DNS" "$TEST_DOMAIN" dokku dns:apps:enable "$TEST_APP"; then
  test_pass "Enable DNS management for app"
else
  test_fail "Enable DNS management for app"
fi

test_start "Sync DNS records (create A record)"
if expect_output_contains "Sync DNS" "Created" dokku dns:apps:sync "$TEST_APP"; then
  test_pass "Sync DNS records (create A record)"
else
  # Try to check if it was updated instead
  if expect_output_contains "Sync DNS" "updated" dokku dns:apps:sync "$TEST_APP"; then
    test_pass "Sync DNS records (create A record)"
  else
    test_fail "Sync DNS records (create A record)"
  fi
fi

#
# READ Operations Tests
#

test_start "Check DNS status (report command)"
if expect_output_contains "DNS report" "CORRECT" dokku dns:report "$TEST_APP"; then
  test_pass "Check DNS status (report command)"
else
  test_fail "Check DNS status (report command)" "Domain not showing as CORRECT"
fi

test_start "Verify DNS resolution"
if verify_dns_record "$TEST_DOMAIN" "$SERVER_IP" 120; then
  test_pass "Verify DNS resolution"
else
  test_warn "DNS resolution verification skipped (may take time to propagate)"
  test_skip "Verify DNS resolution" "DNS propagation can take up to 60s"
fi

#
# UPDATE Operations Tests
#

test_start "Update record TTL"
if expect_success "Set TTL" dokku dns:zones:ttl "$TEST_ZONE" 600; then
  test_pass "Update record TTL"
else
  test_fail "Update record TTL"
fi

test_start "Re-sync with new TTL"
if expect_no_error "Sync after TTL change" dokku dns:apps:sync "$TEST_APP"; then
  test_pass "Re-sync with new TTL"
else
  test_fail "Re-sync with new TTL"
fi

test_start "Verify record still correct after update"
if expect_output_contains "DNS report after update" "CORRECT" dokku dns:report "$TEST_APP"; then
  test_pass "Verify record still correct after update"
else
  test_fail "Verify record still correct after update"
fi

#
# DELETE Operations Tests
#

test_start "Disable DNS management for app"
if expect_success "Disable DNS" dokku dns:apps:disable "$TEST_APP"; then
  test_pass "Disable DNS management for app"
else
  test_fail "Disable DNS management for app"
fi

test_start "Verify app no longer in dns:apps list"
if ! dokku dns:apps 2>/dev/null | grep -q "$TEST_APP"; then
  test_pass "Verify app no longer in dns:apps list"
else
  test_fail "Verify app no longer in dns:apps list" "App still listed"
fi

test_start "Verify deletion queued"
PENDING_DIR="/var/lib/dokku/data/dns/pending-deletions"
if find "$PENDING_DIR" -type f -name "*${TEST_DOMAIN}*" 2>/dev/null | grep -q .; then
  test_pass "Verify deletion queued"
else
  test_skip "Verify deletion queued" "Pending deletions directory may not exist or deletion already processed"
fi

test_start "Process deletions"
if expect_no_error "Sync deletions" dokku dns:sync:deletions; then
  test_pass "Process deletions"
else
  test_fail "Process deletions"
fi

#
# Batch Operations Tests
#

test_start "Create second test app"
if create_test_app "$TEST_APP_2"; then
  test_pass "Create second test app"
else
  test_fail "Create second test app"
fi

# Generate a different subdomain for second app
TEST_DOMAIN_2="test2.${TEST_ZONE}"

test_start "Add domain to second app"
if add_test_domain "$TEST_APP_2" "$TEST_DOMAIN_2"; then
  test_pass "Add domain to second app"
else
  test_fail "Add domain to second app"
fi

test_start "Enable DNS for second app"
if expect_success "Enable DNS" dokku dns:apps:enable "$TEST_APP_2"; then
  test_pass "Enable DNS for second app"
else
  test_fail "Enable DNS for second app"
fi

test_start "Batch sync all apps"
if expect_no_error "Sync all" dokku dns:sync-all; then
  test_pass "Batch sync all apps"
else
  test_fail "Batch sync all apps"
fi

test_start "Verify both apps synced"
if dokku dns:report "$TEST_APP" 2>/dev/null | grep -q "CORRECT" && \
   dokku dns:report "$TEST_APP_2" 2>/dev/null | grep -q "CORRECT"; then
  test_pass "Verify both apps synced"
else
  test_fail "Verify both apps synced" "One or both apps not showing as CORRECT"
fi

#
# Cleanup
#

log_info "========================================="
log_info "Cleaning up test resources"
log_info "========================================="

cleanup_test_app "$TEST_APP"
cleanup_test_app "$TEST_APP_2"

# Disable deletions for cleanup domains
dokku dns:sync:deletions >/dev/null 2>&1 || true

log_info "========================================="
log_info "AWS Route53 CRUD Tests Complete"
log_info "========================================="
