#!/usr/bin/env bash
# Main Test Runner for Dokku DNS Plugin
#
# This script runs all manual test procedures documented in TESTING.md.
# It can run tests for specific providers or all available providers.
#
# Prerequisites:
#   - Dokku server with DNS plugin installed
#   - At least one DNS provider configured with credentials
#   - Test domains available in provider zones
#
# Usage:
#   ./run-all-tests.sh [options]
#
# Options:
#   --provider <name>       Run tests for specific provider only (aws, cloudflare, digitalocean)
#   --aws-domain <domain>   Test domain for AWS Route53 tests
#   --cf-domain <domain>    Test domain for Cloudflare tests
#   --do-domain <domain>    Test domain for DigitalOcean tests
#   --multi                 Run multi-provider tests (requires 2+ providers configured)
#   --skip-dns-verify       Skip DNS resolution verification (speeds up tests)
#   --help                  Show this help message
#
# Examples:
#   # Run all tests for AWS Route53
#   ./run-all-tests.sh --provider aws --aws-domain test.example.com
#
#   # Run tests for all configured providers
#   ./run-all-tests.sh --aws-domain test.example.com --cf-domain test.cloudflare.com
#
#   # Run multi-provider tests
#   ./run-all-tests.sh --multi --aws-domain api.example.com --cf-domain api.test.io

set -eo pipefail

# Load test library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/manual-tests/test-lib.sh
source "$SCRIPT_DIR/test-lib.sh"

# Configuration
PROVIDER=""
AWS_DOMAIN=""
CF_DOMAIN=""
DO_DOMAIN=""
RUN_MULTI=false
SKIP_DNS_VERIFY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --provider)
      PROVIDER="$2"
      shift 2
      ;;
    --aws-domain)
      AWS_DOMAIN="$2"
      shift 2
      ;;
    --cf-domain)
      CF_DOMAIN="$2"
      shift 2
      ;;
    --do-domain)
      DO_DOMAIN="$2"
      shift 2
      ;;
    --multi)
      RUN_MULTI=true
      shift
      ;;
    --skip-dns-verify)
      SKIP_DNS_VERIFY=true
      export SKIP_DNS_VERIFY
      shift
      ;;
    --help)
      grep "^#" "$0" | grep -v "^#!/" | sed 's/^# *//'
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      log_error "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Main test execution
log_info "========================================="
log_info "Dokku DNS Plugin - Test Suite"
log_info "========================================="
log_info "Test log: $TEST_LOG"
log_info "========================================="

# Track which tests to run
TESTS_TO_RUN=()

# Determine which tests to run
if [[ -n "$PROVIDER" ]]; then
  # Run tests for specific provider
  case "$PROVIDER" in
    aws)
      if [[ -z "$AWS_DOMAIN" ]]; then
        log_error "AWS tests requested but --aws-domain not specified"
        exit 1
      fi
      TESTS_TO_RUN+=("aws")
      ;;
    cloudflare)
      if [[ -z "$CF_DOMAIN" ]]; then
        log_error "Cloudflare tests requested but --cf-domain not specified"
        exit 1
      fi
      TESTS_TO_RUN+=("cloudflare")
      ;;
    digitalocean)
      if [[ -z "$DO_DOMAIN" ]]; then
        log_error "DigitalOcean tests requested but --do-domain not specified"
        exit 1
      fi
      TESTS_TO_RUN+=("digitalocean")
      ;;
    *)
      log_error "Unknown provider: $PROVIDER"
      log_error "Valid providers: aws, cloudflare, digitalocean"
      exit 1
      ;;
  esac
else
  # Auto-detect which tests to run based on configured providers and domains
  if [[ -n "$AWS_DOMAIN" ]] && check_provider_available "aws" 2>/dev/null; then
    TESTS_TO_RUN+=("aws")
  fi

  if [[ -n "$CF_DOMAIN" ]] && check_provider_available "cloudflare" 2>/dev/null; then
    TESTS_TO_RUN+=("cloudflare")
  fi

  if [[ -n "$DO_DOMAIN" ]] && check_provider_available "digitalocean" 2>/dev/null; then
    TESTS_TO_RUN+=("digitalocean")
  fi
fi

# Check if we have any tests to run
if [[ ${#TESTS_TO_RUN[@]} -eq 0 ]]; then
  log_error "No tests to run!"
  log_error "Please specify at least one provider and domain:"
  log_error "  --aws-domain <domain>   for AWS Route53 tests"
  log_error "  --cf-domain <domain>    for Cloudflare tests"
  log_error "  --do-domain <domain>    for DigitalOcean tests"
  exit 1
fi

log_info "Tests to run: ${TESTS_TO_RUN[*]}"
if [[ "$RUN_MULTI" == "true" ]]; then
  log_info "Multi-provider tests: enabled"
fi
log_info "========================================="
echo ""

# Run provider-specific tests
for provider in "${TESTS_TO_RUN[@]}"; do
  case "$provider" in
    aws)
      log_info "Running AWS Route53 tests..."
      if "$SCRIPT_DIR/test-aws-route53.sh" "$AWS_DOMAIN"; then
        log_success "AWS Route53 tests completed successfully"
      else
        log_error "AWS Route53 tests failed"
      fi
      echo ""
      ;;
    cloudflare)
      log_info "Running Cloudflare tests..."
      if "$SCRIPT_DIR/test-cloudflare.sh" "$CF_DOMAIN"; then
        log_success "Cloudflare tests completed successfully"
      else
        log_error "Cloudflare tests failed"
      fi
      echo ""
      ;;
    digitalocean)
      log_info "Running DigitalOcean tests..."
      if "$SCRIPT_DIR/test-digitalocean.sh" "$DO_DOMAIN"; then
        log_success "DigitalOcean tests completed successfully"
      else
        log_error "DigitalOcean tests failed"
      fi
      echo ""
      ;;
  esac
done

# Run multi-provider tests if requested
if [[ "$RUN_MULTI" == "true" ]]; then
  if [[ ${#TESTS_TO_RUN[@]} -lt 2 ]]; then
    log_warn "Multi-provider tests requested but less than 2 providers configured"
    log_skip "Multi-provider tests" "Need at least 2 providers configured"
  else
    log_info "Running multi-provider tests..."

    # Use first two configured providers
    PROVIDER_1="${TESTS_TO_RUN[0]}"
    PROVIDER_2="${TESTS_TO_RUN[1]}"

    # Get corresponding domains
    DOMAIN_1=""
    DOMAIN_2=""

    case "$PROVIDER_1" in
      aws) DOMAIN_1="$AWS_DOMAIN" ;;
      cloudflare) DOMAIN_1="$CF_DOMAIN" ;;
      digitalocean) DOMAIN_1="$DO_DOMAIN" ;;
    esac

    case "$PROVIDER_2" in
      aws) DOMAIN_2="$AWS_DOMAIN" ;;
      cloudflare) DOMAIN_2="$CF_DOMAIN" ;;
      digitalocean) DOMAIN_2="$DO_DOMAIN" ;;
    esac

    if "$SCRIPT_DIR/test-multi-provider.sh" "$DOMAIN_1" "$PROVIDER_1" "$DOMAIN_2" "$PROVIDER_2"; then
      log_success "Multi-provider tests completed successfully"
    else
      log_error "Multi-provider tests failed"
    fi
    echo ""
  fi
fi

log_info "========================================="
log_info "All Tests Complete"
log_info "========================================="
