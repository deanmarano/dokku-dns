# Manual Test Scripts

This directory contains automated test scripts for the Dokku DNS plugin manual testing procedures documented in [TESTING.md](../../TESTING.md).

## Overview

These scripts convert the manual test checklists into runnable, automated test procedures that verify:

- CRUD operations (Create, Read, Update, Delete) for each DNS provider
- Multi-provider zone routing
- Batch operations across apps and providers
- DNS record verification and propagation

## Scripts

### Test Library

- **test-lib.sh** - Common utilities and functions shared by all test scripts
  - Logging functions with color output
  - Test result tracking (pass/fail/skip)
  - Command execution with validation
  - DNS verification helpers
  - App and domain management utilities

### Provider-Specific Tests

- **test-aws-route53.sh** - AWS Route53 CRUD operations test
- **test-cloudflare.sh** - Cloudflare CRUD operations test
- **test-digitalocean.sh** - DigitalOcean CRUD operations test
- **test-multi-provider.sh** - Multi-provider zone routing test

### Test Runner

- **run-all-tests.sh** - Main test orchestrator that runs all configured provider tests

## Prerequisites

Before running the tests, ensure:

1. **Dokku Installation**
   - Dokku server (0.19.x+) with DNS plugin installed
   - `dokku dns:version` should show plugin version

2. **Provider Credentials**
   - Configure at least one DNS provider with valid credentials:
     ```bash
     # AWS Route53
     dokku config:set --global AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx

     # Cloudflare
     dokku config:set --global CLOUDFLARE_API_TOKEN=xxx

     # DigitalOcean
     dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=xxx
     ```

3. **Test Domains**
   - Have at least one test domain/subdomain available in each provider's zones
   - Domains should be in zones you control
   - Example: `test.example.com` where `example.com` is a zone in your provider

4. **DNS Tools** (for verification)
   - `dig` command available
   - `curl` for getting server IP

## Usage

### Run Tests for Specific Provider

```bash
# AWS Route53
./test-aws-route53.sh test.example.com

# Cloudflare
./test-cloudflare.sh test.example.com

# DigitalOcean
./test-digitalocean.sh test.example.com
```

### Run All Tests

```bash
# Run all configured provider tests
./run-all-tests.sh \
  --aws-domain test.example.com \
  --cf-domain test.cloudflare.com \
  --do-domain test.digitalocean.com

# Run tests for specific provider only
./run-all-tests.sh --provider aws --aws-domain test.example.com

# Run multi-provider tests (requires 2+ providers)
./run-all-tests.sh \
  --multi \
  --aws-domain api.example.com \
  --cf-domain api.test.io
```

### Options

The `run-all-tests.sh` script supports these options:

- `--provider <name>` - Run tests for specific provider only (aws, cloudflare, digitalocean)
- `--aws-domain <domain>` - Test domain for AWS Route53 tests
- `--cf-domain <domain>` - Test domain for Cloudflare tests
- `--do-domain <domain>` - Test domain for DigitalOcean tests
- `--multi` - Run multi-provider tests (requires 2+ providers configured)
- `--skip-dns-verify` - Skip DNS resolution verification (speeds up tests)
- `--help` - Show help message

## Test Output

### Console Output

Tests provide color-coded output:

- **[INFO]** (blue) - Informational messages
- **[PASS]** (green) - Test passed successfully
- **[FAIL]** (red) - Test failed
- **[SKIP]** (yellow) - Test skipped
- **[WARN]** (yellow) - Warning message

### Test Logs

All test output is logged to a file in `/tmp/`:

```
/tmp/dokku-dns-manual-tests-YYYYMMDD-HHMMSS.log
```

The log file path is displayed at the start and end of test execution.

### Test Summary

At the end of each test run, a summary is displayed:

```
========================================
Test Summary
========================================
Total tests:  25
Passed:       23
Failed:       0
Skipped:      2
========================================
```

## Test Coverage

### AWS Route53 Tests

The AWS Route53 test script covers:

- Provider credential verification
- Zone listing and enablement
- App creation and domain addition
- DNS management enablement
- DNS record creation (A records)
- DNS status reporting
- DNS resolution verification
- Record TTL updates
- Record re-synchronization
- DNS management disablement
- Record deletion queueing and processing
- Batch operations with multiple apps

### Cloudflare Tests

The Cloudflare test script covers:

- Provider credential verification
- Zone enablement
- DNS record CRUD operations
- Proxy status preservation (manual verification)
- DNS resolution verification
- Record deletion

### DigitalOcean Tests

The DigitalOcean test script covers:

- Provider credential verification
- Domain enablement
- DNS record CRUD operations
- DNS resolution verification
- Record deletion

### Multi-Provider Tests

The multi-provider test script covers:

- Multiple provider verification
- Zone enablement across providers
- App with domains in different provider zones
- Correct provider routing for each domain
- Batch synchronization across providers
- Multi-provider deletions

## Cleanup

All test scripts automatically clean up test resources:

- Test apps are destroyed
- DNS management is disabled
- Deletion queue is processed
- Cleanup happens even if tests fail

Test apps are named:
- `dns-test-app-aws` (AWS tests)
- `dns-test-app-cloudflare` (Cloudflare tests)
- `dns-test-app-digitalocean` (DigitalOcean tests)
- `dns-test-app-multi` (multi-provider tests)

## Troubleshooting

### Tests Fail Immediately

**Symptom**: Provider verification fails at start of tests

**Solutions**:
1. Verify credentials are configured:
   ```bash
   dokku config:show --global | grep -E 'AWS|CLOUDFLARE|DIGITALOCEAN'
   ```

2. Test provider manually:
   ```bash
   dokku dns:providers:verify aws
   ```

### DNS Resolution Tests Fail

**Symptom**: Tests pass but DNS verification times out

**Cause**: DNS propagation can take 60-300 seconds

**Solutions**:
- Use `--skip-dns-verify` option to skip resolution checks
- Wait longer and verify manually with `dig <domain> +short`
- DNS verification is optional for most test scenarios

### Domain Not Found in Zone

**Symptom**: "No hosted zone found for domain" error

**Solutions**:
1. Verify zone exists and is enabled:
   ```bash
   dokku dns:zones
   dokku dns:zones:enable example.com
   ```

2. Ensure domain matches zone:
   - `test.example.com` requires `example.com` zone
   - Use correct zone apex domain

### Permission Errors

**Symptom**: "Permission denied" or "Command not found"

**Solutions**:
1. Ensure scripts are executable:
   ```bash
   chmod +x scripts/manual-tests/*.sh
   ```

2. Run from Dokku server with appropriate permissions

## Development

To modify or extend these tests:

1. **test-lib.sh** - Add new utility functions here
2. **test-*.sh** - Modify provider-specific test procedures
3. **run-all-tests.sh** - Update test orchestration logic

Follow these patterns:
- Use `test_start "description"` before each test
- Use `test_pass "description"` on success
- Use `test_fail "description" "reason"` on failure
- Use `test_skip "description" "reason"` to skip
- Use helper functions from test-lib.sh

## CI/CD Integration

These scripts can be integrated into CI/CD pipelines:

```bash
# Example GitHub Actions workflow
- name: Run DNS Plugin Tests
  run: |
    ./scripts/manual-tests/run-all-tests.sh \
      --aws-domain ${{ secrets.TEST_DOMAIN_AWS }} \
      --skip-dns-verify
```

Exit codes:
- `0` - All tests passed
- `1` - One or more tests failed

## Related Documentation

- [TESTING.md](../../TESTING.md) - Full manual testing procedures
- [README.md](../../README.md) - Plugin documentation
- [TODO.md](../../TODO.md) - Development roadmap
