# Testing Guide

This document provides comprehensive manual testing procedures for the Dokku DNS plugin across all supported providers.

> **Automated Testing**: The manual procedures in this guide have been automated as runnable test scripts. See [scripts/manual-tests/README.md](scripts/manual-tests/README.md) for automated testing options.

## Table of Contents

- [Overview](#overview)
- [Automated Testing](#automated-testing)
- [Test Environment Setup](#test-environment-setup)
- [AWS Route53 Testing](#aws-route53-testing)
- [Cloudflare Testing](#cloudflare-testing)
- [DigitalOcean Testing](#digitalocean-testing)
- [Multi-Provider Testing](#multi-provider-testing)
- [Test Result Logging](#test-result-logging)
- [Troubleshooting](#troubleshooting)

## Overview

### Test Types

1. **CRUD Operations** - Create, Read, Update, Delete DNS records
2. **Provider Integration** - Verify provider-specific functionality
3. **Multi-Provider** - Test zone routing across multiple providers
4. **Installation** - Fresh plugin installation and setup
5. **Integration** - App lifecycle and trigger system

### Prerequisites

- Dokku server (0.19.x+)
- Valid credentials for at least one DNS provider
- Test domains with hosted zones configured
- At least one Dokku app deployed

---

## Automated Testing

The manual testing procedures in this guide have been converted into automated test scripts located in `scripts/manual-tests/`.

### Quick Start

```bash
# Run all AWS Route53 tests
./scripts/manual-tests/test-aws-route53.sh test.example.com

# Run all Cloudflare tests
./scripts/manual-tests/test-cloudflare.sh test.example.com

# Run all configured provider tests
./scripts/manual-tests/run-all-tests.sh \
  --aws-domain test.example.com \
  --cf-domain test.cloudflare.com
```

### Features

The automated test scripts provide:

- **Automated CRUD testing** for all providers (AWS, Cloudflare, DigitalOcean)
- **Multi-provider routing** verification
- **Pass/fail reporting** with detailed logs
- **Automatic cleanup** of test resources
- **DNS resolution verification** (optional)
- **Color-coded output** for easy reading

### Documentation

For detailed information about the automated test scripts, see:
- [scripts/manual-tests/README.md](scripts/manual-tests/README.md) - Complete automated testing guide

---

## Test Environment Setup

### Initial Setup

1. **Install the plugin**
   ```bash
   sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
   ```

2. **Verify installation**
   ```bash
   dokku dns:version
   ```

3. **Create test app** (if needed)
   ```bash
   dokku apps:create test-app
   ```

### Test Data

For consistent testing, use these example values:

- **App name**: `test-app`
- **Test domain**: `test.example.com` (replace with your domain)
- **Test IP**: Your server's public IP (get with `curl ifconfig.me`)

---

## AWS Route53 Testing

### Prerequisites

```bash
# Configure AWS credentials (choose one method)
dokku config:set --global AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret
# OR use AWS CLI
aws configure
# OR use IAM role (if running on EC2)
```

### CRUD Operations Checklist

#### ✅ CREATE Operations

- [ ] **Verify provider setup**
  ```bash
  dokku dns:providers:verify aws
  ```
  - **Expected**: Shows AWS zones, credentials valid
  - **Pass criteria**: No errors, zones listed

- [ ] **List available zones**
  ```bash
  dokku dns:zones
  ```
  - **Expected**: Shows zones from Route53
  - **Pass criteria**: At least one zone listed

- [ ] **Enable a zone**
  ```bash
  dokku dns:zones:enable example.com
  ```
  - **Expected**: Zone enabled for auto-discovery
  - **Pass criteria**: Success message, zone marked as enabled

- [ ] **Add domain to app**
  ```bash
  dokku domains:add test-app test.example.com
  ```
  - **Expected**: Domain added to app
  - **Pass criteria**: Domain listed in `dokku domains:report test-app`

- [ ] **Enable DNS management for app**
  ```bash
  dokku dns:apps:enable test-app
  ```
  - **Expected**: Domain added to DNS management
  - **Pass criteria**: Domain status table shows domain with enabled zone

- [ ] **Sync DNS records (create A record)**
  ```bash
  dokku dns:apps:sync test-app
  ```
  - **Expected**: A record created in Route53
  - **Pass criteria**: Success message "Created/updated record"

#### ✅ READ Operations

- [ ] **Check DNS status**
  ```bash
  dokku dns:report test-app
  ```
  - **Expected**: Shows domain with ✅ CORRECT status
  - **Pass criteria**: Domain points to correct IP

- [ ] **Verify in Route53 console**
  - Log into AWS Console
  - Navigate to Route53 → Hosted Zones → Your zone
  - **Expected**: A record exists for test.example.com
  - **Pass criteria**: Record value matches server IP

- [ ] **DNS resolution test**
  ```bash
  dig test.example.com +short
  ```
  - **Expected**: Returns server IP address
  - **Pass criteria**: IP matches server (may take 60s for propagation)

#### ✅ UPDATE Operations

- [ ] **Update record with different IP** (simulated)
  ```bash
  # Manually change record in Route53 to different IP
  # Then sync again
  dokku dns:apps:sync test-app
  ```
  - **Expected**: Record updated back to correct IP
  - **Pass criteria**: `dns:report` shows ✅ CORRECT

- [ ] **Update TTL**
  ```bash
  dokku dns:zones:ttl example.com 600
  dokku dns:apps:sync test-app
  ```
  - **Expected**: New records use TTL=600
  - **Pass criteria**: Check Route53 console for TTL value

#### ✅ DELETE Operations

- [ ] **Remove domain from DNS management**
  ```bash
  dokku dns:apps:disable test-app
  ```
  - **Expected**: Domain removed from DNS management
  - **Pass criteria**: `dns:apps` no longer lists test-app

- [ ] **Queue record for deletion**
  ```bash
  # Records are queued, not immediately deleted
  ```
  - **Expected**: Record added to deletion queue
  - **Pass criteria**: File exists in pending-deletions directory

- [ ] **Process deletions**
  ```bash
  dokku dns:sync:deletions
  ```
  - **Expected**: Record removed from Route53
  - **Pass criteria**: Success message, record gone from Route53

### Batch Operations Test

- [ ] **Sync multiple apps**
  ```bash
  # Create second app with domains
  dokku apps:create test-app-2
  dokku domains:add test-app-2 test2.example.com
  dokku dns:apps:enable test-app-2

  # Batch sync all apps
  dokku dns:sync-all
  ```
  - **Expected**: Both apps synced in single batch operation
  - **Pass criteria**: Success for both domains

---

## Cloudflare Testing

### Prerequisites

```bash
# Configure Cloudflare API token
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token
```

### CRUD Operations Checklist

#### ✅ CREATE Operations

- [ ] **Verify provider setup**
  ```bash
  dokku dns:providers:verify cloudflare
  ```
  - **Expected**: Shows Cloudflare zones, credentials valid
  - **Pass criteria**: No errors, zones listed

- [ ] **Enable a zone**
  ```bash
  dokku dns:zones:enable example.com
  ```
  - **Expected**: Zone enabled for auto-discovery
  - **Pass criteria**: Success message

- [ ] **Create DNS record**
  ```bash
  dokku dns:apps:enable test-app
  dokku dns:apps:sync test-app
  ```
  - **Expected**: A record created in Cloudflare
  - **Pass criteria**: Success message

#### ✅ READ Operations

- [ ] **Check DNS status**
  ```bash
  dokku dns:report test-app
  ```
  - **Expected**: Shows domain with ✅ CORRECT status
  - **Pass criteria**: Domain points to correct IP

- [ ] **Verify in Cloudflare dashboard**
  - Log into Cloudflare
  - Select domain → DNS → Records
  - **Expected**: A record exists for test.example.com
  - **Pass criteria**: Record value matches server IP

#### ✅ UPDATE Operations

- [ ] **Update existing record**
  ```bash
  # Manually change record in Cloudflare
  # Then sync again
  dokku dns:apps:sync test-app
  ```
  - **Expected**: Record updated to correct IP
  - **Pass criteria**: `dns:report` shows ✅ CORRECT

#### ✅ DELETE Operations

- [ ] **Remove and delete record**
  ```bash
  dokku dns:apps:disable test-app
  dokku dns:sync:deletions
  ```
  - **Expected**: Record removed from Cloudflare
  - **Pass criteria**: Record gone from Cloudflare DNS

### Cloudflare-Specific Tests

- [ ] **Proxy status preservation**
  - Enable Cloudflare proxy (orange cloud) in dashboard
  - Run `dokku dns:apps:sync test-app`
  - **Expected**: Proxy status preserved (not disabled by sync)
  - **Pass criteria**: Record still proxied after sync

---

## DigitalOcean Testing

### Prerequisites

```bash
# Configure DigitalOcean API token
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token
```

### CRUD Operations Checklist

#### ✅ CREATE Operations

- [ ] **Verify provider setup**
  ```bash
  dokku dns:providers:verify digitalocean
  ```
  - **Expected**: Shows DigitalOcean domains, credentials valid
  - **Pass criteria**: No errors, domains listed

- [ ] **Enable a domain**
  ```bash
  dokku dns:zones:enable example.com
  ```
  - **Expected**: Domain enabled for auto-discovery
  - **Pass criteria**: Success message

- [ ] **Create DNS record**
  ```bash
  dokku dns:apps:enable test-app
  dokku dns:apps:sync test-app
  ```
  - **Expected**: A record created in DigitalOcean
  - **Pass criteria**: Success message

#### ✅ READ Operations

- [ ] **Check DNS status**
  ```bash
  dokku dns:report test-app
  ```
  - **Expected**: Shows domain with ✅ CORRECT status
  - **Pass criteria**: Domain points to correct IP

- [ ] **Verify in DigitalOcean control panel**
  - Log into DigitalOcean
  - Navigate to Networking → Domains → Your domain
  - **Expected**: A record exists for test.example.com
  - **Pass criteria**: Record value matches server IP

#### ✅ UPDATE Operations

- [ ] **Update existing record**
  ```bash
  # Manually change record in DO
  # Then sync again
  dokku dns:apps:sync test-app
  ```
  - **Expected**: Record updated to correct IP
  - **Pass criteria**: `dns:report` shows ✅ CORRECT

#### ✅ DELETE Operations

- [ ] **Remove and delete record**
  ```bash
  dokku dns:apps:disable test-app
  dokku dns:sync:deletions
  ```
  - **Expected**: Record removed from DigitalOcean
  - **Pass criteria**: Record gone from DO DNS

---

## Multi-Provider Testing

Test zone routing across multiple DNS providers simultaneously.

### Setup

1. **Configure multiple providers**
   ```bash
   # AWS
   dokku config:set --global AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx

   # Cloudflare
   dokku config:set --global CLOUDFLARE_API_TOKEN=xxx
   ```

2. **Enable zones from different providers**
   ```bash
   dokku dns:zones:enable example.com    # AWS
   dokku dns:zones:enable test.io        # Cloudflare
   ```

### Multi-Provider Checklist

- [ ] **Verify both providers recognized**
  ```bash
  dokku dns:providers:verify
  ```
  - **Expected**: Shows zones from both providers
  - **Pass criteria**: Both providers listed with their zones

- [ ] **Create app with domains in different zones**
  ```bash
  dokku domains:add test-app api.example.com   # AWS zone
  dokku domains:add test-app api.test.io       # Cloudflare zone
  ```

- [ ] **Enable DNS and sync**
  ```bash
  dokku dns:apps:enable test-app
  dokku dns:apps:sync test-app
  ```
  - **Expected**: Records created in correct provider for each domain
  - **Pass criteria**: api.example.com in AWS, api.test.io in Cloudflare

- [ ] **Verify routing**
  ```bash
  dokku dns:report test-app
  ```
  - **Expected**: Shows correct provider for each domain
  - **Pass criteria**: Provider column shows aws/cloudflare correctly

- [ ] **Test batch sync across providers**
  ```bash
  dokku dns:sync-all
  ```
  - **Expected**: Updates sent to appropriate providers
  - **Pass criteria**: Success for domains in both providers

---

## Test Result Logging

### Test Session Template

```markdown
## Test Session: [Date]
**Tester**: [Name]
**Environment**: [Production/Staging]
**Dokku Version**: [Version]
**Plugin Version**: [Version]

### Test Results

#### AWS Route53
- [ ] Provider verification: PASS/FAIL
- [ ] CREATE operations: PASS/FAIL
- [ ] READ operations: PASS/FAIL
- [ ] UPDATE operations: PASS/FAIL
- [ ] DELETE operations: PASS/FAIL
- **Notes**: [Any observations]

#### Cloudflare
- [ ] Provider verification: PASS/FAIL
- [ ] CREATE operations: PASS/FAIL
- [ ] READ operations: PASS/FAIL
- [ ] UPDATE operations: PASS/FAIL
- [ ] DELETE operations: PASS/FAIL
- **Notes**: [Any observations]

#### DigitalOcean
- [ ] Provider verification: PASS/FAIL
- [ ] CREATE operations: PASS/FAIL
- [ ] READ operations: PASS/FAIL
- [ ] UPDATE operations: PASS/FAIL
- [ ] DELETE operations: PASS/FAIL
- **Notes**: [Any observations]

#### Multi-Provider
- [ ] Zone routing: PASS/FAIL
- [ ] Batch operations: PASS/FAIL
- **Notes**: [Any observations]

### Issues Encountered
[List any issues, errors, or unexpected behavior]

### Pass/Fail Summary
**Overall Result**: PASS/FAIL
**Confidence Level**: High/Medium/Low
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "AWS credentials not configured or invalid"

**Symptoms**: Provider verification fails
**Causes**:
- Missing AWS credentials
- Invalid access key/secret key
- Insufficient IAM permissions

**Solutions**:
1. Verify credentials are set:
   ```bash
   dokku config:show --global | grep AWS
   ```

2. Test AWS CLI directly:
   ```bash
   aws sts get-caller-identity
   ```

3. Check IAM permissions (need Route53 read/write)

4. Try reconfiguring:
   ```bash
   dokku config:unset --global AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
   dokku config:set --global AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx
   ```

#### Issue: "No hosted zone found for domain"

**Symptoms**: Domain not added to DNS management
**Causes**:
- Zone not created in provider
- Zone not enabled for auto-discovery
- Domain doesn't match zone

**Solutions**:
1. Check if zone exists:
   ```bash
   dokku dns:zones
   ```

2. Enable the zone:
   ```bash
   dokku dns:zones:enable example.com
   ```

3. For subdomains, ensure parent zone exists:
   - `api.example.com` requires `example.com` zone

#### Issue: "DNS record points to wrong IP"

**Symptoms**: `dns:report` shows ⚠️ WARNING
**Causes**:
- Manual changes in provider
- Server IP changed
- Sync not run after changes

**Solutions**:
1. Resync the app:
   ```bash
   dokku dns:apps:sync test-app
   ```

2. Check server IP:
   ```bash
   curl ifconfig.me
   ```

3. Verify record in provider console

#### Issue: "Batch operation failed"

**Symptoms**: `dns:sync-all` reports errors
**Causes**:
- Provider API rate limiting
- Invalid credentials
- Network connectivity

**Solutions**:
1. Check individual app sync:
   ```bash
   dokku dns:apps:sync test-app
   ```

2. Verify provider credentials:
   ```bash
   dokku dns:providers:verify
   ```

3. Check provider status pages for outages

#### Issue: "Zone enabled but domains still skipped"

**Symptoms**: Domains not added despite zone being enabled
**Causes**:
- Case sensitivity mismatch
- Zone format mismatch (with/without trailing dot)
- Cache not refreshed

**Solutions**:
1. Check exact zone name:
   ```bash
   dokku dns:zones
   ```

2. Try disabling and re-enabling:
   ```bash
   dokku dns:zones:disable example.com
   dokku dns:zones:enable example.com
   ```

3. Use verbose mode to see details:
   ```bash
   dokku dns:apps:enable test-app --verbose
   ```

### Getting Help

If you encounter issues not covered here:

1. **Check plugin version**:
   ```bash
   dokku dns:version
   ```

2. **Review logs**:
   ```bash
   dokku trace on
   dokku dns:apps:sync test-app
   dokku trace off
   ```

3. **File an issue**: https://github.com/deanmarano/dokku-dns/issues
   - Include plugin version
   - Include error messages
   - Include steps to reproduce

### Validation Tools

Useful commands for verifying DNS setup:

```bash
# Check DNS propagation
dig @8.8.8.8 test.example.com +short

# Check with specific nameserver
dig @ns1.example.com test.example.com

# Trace DNS lookup
dig test.example.com +trace

# Check all DNS records
dig test.example.com ANY

# Verify nameservers
dig example.com NS +short
```

---

## Next Steps

After completing manual testing:

1. **Document results** using the test session template
2. **Report any issues** on GitHub
3. **Update this guide** with any new findings
4. **Proceed to automated testing** (if implementing CI/CD)

For automated testing, see:
- `scripts/test-docker.sh` - Docker-based integration tests
- `tests/` - BATS test suite
