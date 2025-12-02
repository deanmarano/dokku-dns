#!/usr/bin/env bash
# Multi-Provider Test Script
#
# This script automates the multi-provider testing procedures documented in TESTING.md.
# It verifies that the plugin can correctly route DNS operations to different providers
# based on zone ownership.
#
# Prerequisites:
#   - Dokku server with DNS plugin installed
#   - At least TWO DNS providers configured (e.g., AWS + Cloudflare)
#   - Test domains in different provider zones
#
# Usage:
#   ./test-multi-provider.sh <domain1> <provider1> <domain2> <provider2> [test-app]
#
# Example:
#   ./test-multi-provider.sh api.example.com aws api.test.io cloudflare

set -eo pipefail

# Load test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/manual-tests/test-lib.sh
source "$SCRIPT_DIR/test-lib.sh"

# Configuration
TEST_DOMAIN_1="${1:-}"
PROVIDER_1="${2:-}"
TEST_DOMAIN_2="${3:-}"
PROVIDER_2="${4:-}"
TEST_APP="${5:-dns-test-app-multi}"

# Validate arguments
if [[ -z "$TEST_DOMAIN_1" ]] || [[ -z "$PROVIDER_1" ]] || [[ -z "$TEST_DOMAIN_2" ]] || [[ -z "$PROVIDER_2" ]]; then
  log_error "Usage: $0 <domain1> <provider1> <domain2> <provider2> [test-app]"
  log_error "Example: $0 api.example.com aws api.test.io cloudflare"
  exit 1
fi

# Extract zones from domains
get_zone_from_domain() {
  local domain="$1"
  echo "$domain" | awk -F. '{print $(NF-1)"."$NF}'
}

TEST_ZONE_1=$(get_zone_from_domain "$TEST_DOMAIN_1")
TEST_ZONE_2=$(get_zone_from_domain "$TEST_DOMAIN_2")

log_info "========================================="
log_info "Multi-Provider Test"
log_info "========================================="
log_info "Domain 1: $TEST_DOMAIN_1 (zone: $TEST_ZONE_1, provider: $PROVIDER_1)"
log_info "Domain 2: $TEST_DOMAIN_2 (zone: $TEST_ZONE_2, provider: $PROVIDER_2)"
log_info "Test app: $TEST_APP"
log_info "========================================="

# Get server IP for validation
SERVER_IP=$(get_server_ip)
log_info "Server IP: $SERVER_IP"

#
# Provider Setup Tests
#

test_start "Verify first provider ($PROVIDER_1)"
if check_provider_available "$PROVIDER_1"; then
  test_pass "Verify first provider ($PROVIDER_1)"
else
  test_fail "Verify first provider ($PROVIDER_1)" "Provider not configured"
  exit 1
fi

test_start "Verify second provider ($PROVIDER_2)"
if check_provider_available "$PROVIDER_2"; then
  test_pass "Verify second provider ($PROVIDER_2)"
else
  test_fail "Verify second provider ($PROVIDER_2)" "Provider not configured"
  exit 1
fi

test_start "Verify both providers show in providers:verify"
if dokku dns:providers:verify 2>&1 | grep -q "$PROVIDER_1" && \
   dokku dns:providers:verify 2>&1 | grep -q "$PROVIDER_2"; then
  test_pass "Verify both providers show in providers:verify"
else
  test_fail "Verify both providers show in providers:verify"
  exit 1
fi

#
# Zone Configuration Tests
#

test_start "Enable first zone ($TEST_ZONE_1)"
if expect_success "Enable zone 1" dokku dns:zones:enable "$TEST_ZONE_1"; then
  test_pass "Enable first zone ($TEST_ZONE_1)"
else
  test_fail "Enable first zone ($TEST_ZONE_1)"
  exit 1
fi

test_start "Enable second zone ($TEST_ZONE_2)"
if expect_success "Enable zone 2" dokku dns:zones:enable "$TEST_ZONE_2"; then
  test_pass "Enable second zone ($TEST_ZONE_2)"
else
  test_fail "Enable second zone ($TEST_ZONE_2)"
  exit 1
fi

#
# App Configuration with Multiple Domains
#

test_start "Create test app"
if create_test_app "$TEST_APP"; then
  test_pass "Create test app"
else
  test_fail "Create test app"
  exit 1
fi

test_start "Add first domain to app"
if add_test_domain "$TEST_APP" "$TEST_DOMAIN_1"; then
  test_pass "Add first domain to app"
else
  test_fail "Add first domain to app"
  exit 1
fi

test_start "Add second domain to app (different provider)"
if add_test_domain "$TEST_APP" "$TEST_DOMAIN_2"; then
  test_pass "Add second domain to app (different provider)"
else
  test_fail "Add second domain to app (different provider)"
  exit 1
fi

#
# DNS Management and Routing Tests
#

test_start "Enable DNS management for app"
if expect_no_error "Enable DNS" dokku dns:apps:enable "$TEST_APP"; then
  test_pass "Enable DNS management for app"
else
  test_fail "Enable DNS management for app"
fi

test_start "Verify both domains accepted"
if dokku dns:report "$TEST_APP" 2>&1 | grep -q "$TEST_DOMAIN_1" && \
   dokku dns:report "$TEST_APP" 2>&1 | grep -q "$TEST_DOMAIN_2"; then
  test_pass "Verify both domains accepted"
else
  test_fail "Verify both domains accepted"
fi

test_start "Sync DNS for app (multi-provider)"
if expect_no_error "Sync DNS" dokku dns:apps:sync "$TEST_APP"; then
  test_pass "Sync DNS for app (multi-provider)"
else
  test_fail "Sync DNS for app (multi-provider)"
fi

test_start "Verify routing to correct providers"
OUTPUT=$(dokku dns:report "$TEST_APP" 2>&1)
if echo "$OUTPUT" | grep "$TEST_DOMAIN_1" | grep -qi "$PROVIDER_1" && \
   echo "$OUTPUT" | grep "$TEST_DOMAIN_2" | grep -qi "$PROVIDER_2"; then
  test_pass "Verify routing to correct providers"
  log_info "  Domain 1 routed to: $PROVIDER_1"
  log_info "  Domain 2 routed to: $PROVIDER_2"
else
  test_fail "Verify routing to correct providers" "Domains not routed to expected providers"
  log_error "Report output:"
  log_error "$OUTPUT"
fi

test_start "Verify both records created correctly"
if dokku dns:report "$TEST_APP" 2>&1 | grep "$TEST_DOMAIN_1" | grep -q "CORRECT" && \
   dokku dns:report "$TEST_APP" 2>&1 | grep "$TEST_DOMAIN_2" | grep -q "CORRECT"; then
  test_pass "Verify both records created correctly"
else
  test_fail "Verify both records created correctly"
fi

#
# Batch Operation Tests
#

test_start "Test batch sync across providers"
if expect_no_error "Batch sync all" dokku dns:sync-all; then
  test_pass "Test batch sync across providers"
else
  test_fail "Test batch sync across providers"
fi

test_start "Verify both domains still correct after batch sync"
if dokku dns:report "$TEST_APP" 2>&1 | grep "$TEST_DOMAIN_1" | grep -q "CORRECT" && \
   dokku dns:report "$TEST_APP" 2>&1 | grep "$TEST_DOMAIN_2" | grep -q "CORRECT"; then
  test_pass "Verify both domains still correct after batch sync"
else
  test_fail "Verify both domains still correct after batch sync"
fi

#
# DNS Resolution Tests (Optional - can be slow)
#

test_start "Verify DNS resolution for domain 1"
if verify_dns_record "$TEST_DOMAIN_1" "$SERVER_IP" 120; then
  test_pass "Verify DNS resolution for domain 1"
else
  test_skip "Verify DNS resolution for domain 1" "DNS propagation can take time"
fi

test_start "Verify DNS resolution for domain 2"
if verify_dns_record "$TEST_DOMAIN_2" "$SERVER_IP" 120; then
  test_pass "Verify DNS resolution for domain 2"
else
  test_skip "Verify DNS resolution for domain 2" "DNS propagation can take time"
fi

#
# Cleanup
#

test_start "Disable DNS management"
if expect_success "Disable DNS" dokku dns:apps:disable "$TEST_APP"; then
  test_pass "Disable DNS management"
else
  test_fail "Disable DNS management"
fi

test_start "Process deletions (multi-provider)"
if expect_no_error "Sync deletions" dokku dns:sync:deletions; then
  test_pass "Process deletions (multi-provider)"
else
  test_fail "Process deletions (multi-provider)"
fi

log_info "========================================="
log_info "Cleaning up test resources"
log_info "========================================="

cleanup_test_app "$TEST_APP"

log_info "========================================="
log_info "Multi-Provider Tests Complete"
log_info "========================================="
