#!/usr/bin/env bash
# DigitalOcean CRUD Operations Test Script
#
# This script automates the DigitalOcean testing procedures documented in TESTING.md.
# It performs CREATE, READ, UPDATE, and DELETE operations to verify provider integration.
#
# Prerequisites:
#   - Dokku server with DNS plugin installed
#   - DigitalOcean API token configured (DIGITALOCEAN_ACCESS_TOKEN)
#   - At least one domain in DigitalOcean
#   - Test domain available in one of your domains
#
# Usage:
#   ./test-digitalocean.sh <test-domain> [test-app-name]
#
# Example:
#   ./test-digitalocean.sh test.example.com test-app

set -eo pipefail

# Load test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/manual-tests/test-lib.sh
source "$SCRIPT_DIR/test-lib.sh"

# Configuration
TEST_DOMAIN="${1:-}"
TEST_APP="${2:-dns-test-app-digitalocean}"

# Validate arguments
if [[ -z "$TEST_DOMAIN" ]]; then
  log_error "Usage: $0 <test-domain> [test-app-name]"
  log_error "Example: $0 test.example.com test-app"
  exit 1
fi

# Extract zone from domain
get_zone_from_domain() {
  local domain="$1"
  echo "$domain" | awk -F. '{print $(NF-1)"."$NF}'
}

TEST_ZONE=$(get_zone_from_domain "$TEST_DOMAIN")

log_info "========================================="
log_info "DigitalOcean CRUD Operations Test"
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
if check_provider_available "digitalocean"; then
  test_pass "Provider verification"
else
  test_fail "Provider verification" "DigitalOcean credentials not configured or invalid"
  exit 1
fi

test_start "Enable domain for auto-discovery"
if expect_success "Enable domain" dokku dns:zones:enable "$TEST_ZONE"; then
  test_pass "Enable domain for auto-discovery"
else
  test_fail "Enable domain for auto-discovery"
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

test_start "Re-sync (simulated update)"
# In a real scenario, you would manually change the record in DigitalOcean
# and then sync to verify it updates back to correct IP
if expect_no_error "Re-sync" dokku dns:apps:sync "$TEST_APP"; then
  test_pass "Re-sync (simulated update)"
else
  test_fail "Re-sync (simulated update)"
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

test_start "Process deletions"
if expect_no_error "Sync deletions" dokku dns:sync:deletions; then
  test_pass "Process deletions"
else
  test_fail "Process deletions"
fi

#
# Cleanup
#

log_info "========================================="
log_info "Cleaning up test resources"
log_info "========================================="

cleanup_test_app "$TEST_APP"

log_info "========================================="
log_info "DigitalOcean CRUD Tests Complete"
log_info "========================================="
