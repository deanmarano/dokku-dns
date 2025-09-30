# Manual Testing Guide

This document provides comprehensive manual testing procedures for the Dokku DNS plugin. Use this guide to validate all provider integrations and core functionality before release.

## Overview

The Dokku DNS plugin supports multiple cloud DNS providers (AWS Route53, Cloudflare, DigitalOcean). This guide covers:
- Provider-specific CRUD operations testing
- Multi-provider zone routing validation
- Installation and deployment testing
- Common troubleshooting scenarios

## Prerequisites

Before beginning manual tests, ensure you have:

- [ ] A running Dokku server (0.19.x or later)
- [ ] Valid credentials for each provider you want to test
- [ ] At least one registered domain with DNS zones in each provider
- [ ] SSH access to your Dokku server
- [ ] Test Dokku apps deployed and ready for domain configuration

### Provider Credentials Setup

**AWS Route53:**
```bash
dokku config:set --global AWS_ACCESS_KEY_ID=your_key_id
dokku config:set --global AWS_SECRET_ACCESS_KEY=your_secret_key
# OR configure via AWS CLI: aws configure
# OR use IAM roles (recommended for EC2/ECS)
```

**Cloudflare:**
```bash
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token
```

**DigitalOcean:**
```bash
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token
```

---

## AWS Route53 Testing

### Test Environment Setup

- [ ] AWS credentials configured (see Prerequisites)
- [ ] At least one hosted zone exists in Route53
- [ ] Test app deployed: `dokku apps:create test-aws-app`

### Provider Verification

- [ ] Run `dokku dns:providers:verify aws`
- [ ] Verify output shows "✅ AWS Route53 provider is properly configured"
- [ ] Verify hosted zones are listed correctly
- [ ] Note zone IDs for later reference

### CRUD Operations - AWS Route53

#### CREATE Operations

- [ ] **Enable DNS Zone**
  ```bash
  dokku dns:zones:enable example.com
  ```
  - [ ] Verify zone shows as enabled: `dokku dns:zones`
  - [ ] Verify zone data stored in `/var/lib/dokku/services/dns/zones/`

- [ ] **Add Domain to App**
  ```bash
  dokku domains:add test-aws-app www.example.com
  dokku dns:apps:enable test-aws-app
  ```
  - [ ] Verify app is DNS-enabled: `dokku dns:apps`
  - [ ] Check status before sync: `dokku dns:report test-aws-app`

- [ ] **Create DNS Record**
  ```bash
  dokku dns:apps:sync test-aws-app
  ```
  - [ ] Verify command shows success message
  - [ ] Verify DNS record created in Route53 console
  - [ ] Verify `dokku dns:report test-aws-app` shows "✅ CORRECT"
  - [ ] Test DNS resolution: `dig www.example.com +short`

#### READ Operations

- [ ] **List DNS-Managed Apps**
  ```bash
  dokku dns:apps
  ```
  - [ ] Verify test-aws-app is listed
  - [ ] Verify domains are shown correctly

- [ ] **View DNS Status**
  ```bash
  dokku dns:report test-aws-app
  ```
  - [ ] Verify server IP displayed correctly
  - [ ] Verify all domains listed with DNS status
  - [ ] Verify hosted zone information shown
  - [ ] Check emoji indicators (✅/⚠️/❌) are appropriate

- [ ] **List Zones**
  ```bash
  dokku dns:zones
  ```
  - [ ] Verify enabled zones marked with ✅
  - [ ] Verify provider shown correctly

#### UPDATE Operations

- [ ] **Update DNS Record (Change IP)**
  - [ ] Manually change A record in Route53 console to different IP
  - [ ] Run `dokku dns:apps:sync test-aws-app`
  - [ ] Verify IP updated back to server IP in Route53 console
  - [ ] Verify `dokku dns:report test-aws-app` shows "✅ CORRECT"

- [ ] **Add Additional Domain**
  ```bash
  dokku domains:add test-aws-app api.example.com
  dokku dns:apps:sync test-aws-app
  ```
  - [ ] Verify new DNS record created
  - [ ] Verify both records exist in Route53
  - [ ] Test both domains resolve correctly

- [ ] **Update TTL**
  ```bash
  dokku dns:zones:ttl example.com 7200
  dokku dns:apps:sync test-aws-app
  ```
  - [ ] Verify TTL updated in Route53 console
  - [ ] Verify new TTL persisted: `dokku dns:zones:ttl example.com`

#### DELETE Operations

- [ ] **Remove Domain from App**
  ```bash
  dokku domains:remove test-aws-app api.example.com
  ```
  - [ ] Run `dokku dns:sync:deletions example.com`
  - [ ] Verify DNS record removed from Route53 console
  - [ ] Verify other records remain intact

- [ ] **Disable App DNS Management**
  ```bash
  dokku dns:apps:disable test-aws-app
  ```
  - [ ] Verify app no longer in `dokku dns:apps` list
  - [ ] Verify DNS records remain in Route53 (not auto-deleted)
  - [ ] Verify app data removed from plugin storage

- [ ] **Disable DNS Zone**
  ```bash
  dokku dns:zones:disable example.com
  ```
  - [ ] Verify zone shows as disabled: `dokku dns:zones`
  - [ ] Verify warning message about managed domains
  - [ ] Verify zone data removed from plugin storage

### AWS Route53 Batch Operations

- [ ] **Sync All Apps**
  - [ ] Create multiple test apps with domains in same zone
  - [ ] Run `dokku dns:sync-all`
  - [ ] Verify batch API optimization message shown
  - [ ] Verify all records updated in single API call per zone
  - [ ] Check Route53 console for all records

### Test Results - AWS Route53

**Date:** _______________
**Tester:** _______________
**Server:** _______________

| Operation | Status | Notes |
|-----------|--------|-------|
| Provider Verification | ⬜ Pass / ⬜ Fail | |
| Create Zone | ⬜ Pass / ⬜ Fail | |
| Create Record | ⬜ Pass / ⬜ Fail | |
| Read Status | ⬜ Pass / ⬜ Fail | |
| Update Record | ⬜ Pass / ⬜ Fail | |
| Update TTL | ⬜ Pass / ⬜ Fail | |
| Delete Record | ⬜ Pass / ⬜ Fail | |
| Delete Zone | ⬜ Pass / ⬜ Fail | |
| Batch Operations | ⬜ Pass / ⬜ Fail | |

---

## Cloudflare Testing

### Test Environment Setup

- [ ] Cloudflare API token configured (see Prerequisites)
- [ ] At least one zone exists in Cloudflare
- [ ] Test app deployed: `dokku apps:create test-cf-app`

### Provider Verification

- [ ] Run `dokku dns:providers:verify cloudflare`
- [ ] Verify output shows "✅ Cloudflare provider is properly configured"
- [ ] Verify zones are listed correctly
- [ ] Note zone IDs for later reference

### CRUD Operations - Cloudflare

#### CREATE Operations

- [ ] **Enable DNS Zone**
  ```bash
  dokku dns:zones:enable cf-example.com
  ```
  - [ ] Verify zone shows as enabled: `dokku dns:zones`
  - [ ] Verify provider shown as "cloudflare"

- [ ] **Add Domain to App**
  ```bash
  dokku domains:add test-cf-app www.cf-example.com
  dokku dns:apps:enable test-cf-app
  ```
  - [ ] Verify app is DNS-enabled: `dokku dns:apps`

- [ ] **Create DNS Record**
  ```bash
  dokku dns:apps:sync test-cf-app
  ```
  - [ ] Verify success message
  - [ ] Verify DNS record in Cloudflare dashboard
  - [ ] Verify proxied status (should be false/DNS only)
  - [ ] Test DNS resolution

#### READ Operations

- [ ] **List DNS-Managed Apps**
  ```bash
  dokku dns:apps
  ```
  - [ ] Verify test-cf-app is listed

- [ ] **View DNS Status**
  ```bash
  dokku dns:report test-cf-app
  ```
  - [ ] Verify status shows correctly
  - [ ] Verify Cloudflare zone information

- [ ] **List Zones**
  ```bash
  dokku dns:zones
  ```
  - [ ] Verify Cloudflare zones shown with correct provider

#### UPDATE Operations

- [ ] **Update DNS Record**
  - [ ] Change A record in Cloudflare dashboard
  - [ ] Run `dokku dns:apps:sync test-cf-app`
  - [ ] Verify IP corrected in Cloudflare dashboard

- [ ] **Add Additional Domain**
  ```bash
  dokku domains:add test-cf-app api.cf-example.com
  dokku dns:apps:sync test-cf-app
  ```
  - [ ] Verify new DNS record created

- [ ] **Update TTL**
  ```bash
  dokku dns:zones:ttl cf-example.com 7200
  dokku dns:apps:sync test-cf-app
  ```
  - [ ] Verify TTL updated in Cloudflare dashboard

#### DELETE Operations

- [ ] **Remove Domain from App**
  ```bash
  dokku domains:remove test-cf-app api.cf-example.com
  dokku dns:sync:deletions cf-example.com
  ```
  - [ ] Verify DNS record removed from Cloudflare

- [ ] **Disable App DNS Management**
  ```bash
  dokku dns:apps:disable test-cf-app
  ```
  - [ ] Verify app removed from DNS management

- [ ] **Disable DNS Zone**
  ```bash
  dokku dns:zones:disable cf-example.com
  ```
  - [ ] Verify zone disabled

### Test Results - Cloudflare

**Date:** _______________
**Tester:** _______________
**Server:** _______________

| Operation | Status | Notes |
|-----------|--------|-------|
| Provider Verification | ⬜ Pass / ⬜ Fail | |
| Create Zone | ⬜ Pass / ⬜ Fail | |
| Create Record | ⬜ Pass / ⬜ Fail | |
| Read Status | ⬜ Pass / ⬜ Fail | |
| Update Record | ⬜ Pass / ⬜ Fail | |
| Update TTL | ⬜ Pass / ⬜ Fail | |
| Delete Record | ⬜ Pass / ⬜ Fail | |
| Delete Zone | ⬜ Pass / ⬜ Fail | |

---

## DigitalOcean Testing

### Test Environment Setup

- [ ] DigitalOcean API token configured (see Prerequisites)
- [ ] At least one domain exists in DigitalOcean
- [ ] Test app deployed: `dokku apps:create test-do-app`

### Provider Verification

- [ ] Run `dokku dns:providers:verify digitalocean`
- [ ] Verify output shows "✅ DigitalOcean provider is properly configured"
- [ ] Verify domains are listed correctly

### CRUD Operations - DigitalOcean

#### CREATE Operations

- [ ] **Enable DNS Zone**
  ```bash
  dokku dns:zones:enable do-example.com
  ```
  - [ ] Verify zone shows as enabled: `dokku dns:zones`
  - [ ] Verify provider shown as "digitalocean"

- [ ] **Add Domain to App**
  ```bash
  dokku domains:add test-do-app www.do-example.com
  dokku dns:apps:enable test-do-app
  ```
  - [ ] Verify app is DNS-enabled: `dokku dns:apps`

- [ ] **Create DNS Record**
  ```bash
  dokku dns:apps:sync test-do-app
  ```
  - [ ] Verify success message
  - [ ] Verify DNS record in DigitalOcean control panel
  - [ ] Test DNS resolution

#### READ Operations

- [ ] **List DNS-Managed Apps**
  ```bash
  dokku dns:apps
  ```
  - [ ] Verify test-do-app is listed

- [ ] **View DNS Status**
  ```bash
  dokku dns:report test-do-app
  ```
  - [ ] Verify status shows correctly
  - [ ] Verify DigitalOcean domain information

- [ ] **List Zones**
  ```bash
  dokku dns:zones
  ```
  - [ ] Verify DigitalOcean domains shown with correct provider

#### UPDATE Operations

- [ ] **Update DNS Record**
  - [ ] Change A record in DigitalOcean control panel
  - [ ] Run `dokku dns:apps:sync test-do-app`
  - [ ] Verify IP corrected in control panel

- [ ] **Add Additional Domain**
  ```bash
  dokku domains:add test-do-app api.do-example.com
  dokku dns:apps:sync test-do-app
  ```
  - [ ] Verify new DNS record created

- [ ] **Update TTL**
  ```bash
  dokku dns:zones:ttl do-example.com 7200
  dokku dns:apps:sync test-do-app
  ```
  - [ ] Verify TTL updated in DigitalOcean control panel

#### DELETE Operations

- [ ] **Remove Domain from App**
  ```bash
  dokku domains:remove test-do-app api.do-example.com
  dokku dns:sync:deletions do-example.com
  ```
  - [ ] Verify DNS record removed from DigitalOcean

- [ ] **Disable App DNS Management**
  ```bash
  dokku dns:apps:disable test-do-app
  ```
  - [ ] Verify app removed from DNS management

- [ ] **Disable DNS Zone**
  ```bash
  dokku dns:zones:disable do-example.com
  ```
  - [ ] Verify zone disabled

### Test Results - DigitalOcean

**Date:** _______________
**Tester:** _______________
**Server:** _______________

| Operation | Status | Notes |
|-----------|--------|-------|
| Provider Verification | ⬜ Pass / ⬜ Fail | |
| Create Zone | ⬜ Pass / ⬜ Fail | |
| Create Record | ⬜ Pass / ⬜ Fail | |
| Read Status | ⬜ Pass / ⬜ Fail | |
| Update Record | ⬜ Pass / ⬜ Fail | |
| Update TTL | ⬜ Pass / ⬜ Fail | |
| Delete Record | ⬜ Pass / ⬜ Fail | |
| Delete Zone | ⬜ Pass / ⬜ Fail | |

---

## Multi-Provider Testing

### Zone Routing Validation

- [ ] **Configure Multiple Providers**
  - [ ] Set up AWS Route53 credentials
  - [ ] Set up Cloudflare credentials
  - [ ] Set up DigitalOcean credentials
  - [ ] Run `dokku dns:providers:verify` (all providers)
  - [ ] Verify all three providers detected and configured

- [ ] **Enable Zones from Different Providers**
  ```bash
  dokku dns:zones:enable aws-example.com
  dokku dns:zones:enable cf-example.com
  dokku dns:zones:enable do-example.com
  ```
  - [ ] Verify `dokku dns:zones` shows all three with correct providers

- [ ] **Test Multi-Provider App**
  ```bash
  dokku apps:create multi-provider-app
  dokku domains:add multi-provider-app www.aws-example.com
  dokku domains:add multi-provider-app www.cf-example.com
  dokku domains:add multi-provider-app www.do-example.com
  dokku dns:apps:enable multi-provider-app
  dokku dns:apps:sync multi-provider-app
  ```
  - [ ] Verify records created in all three providers
  - [ ] Verify `dokku dns:report multi-provider-app` shows all domains correctly
  - [ ] Verify each domain resolves to correct IP

- [ ] **Test Sync-All with Multiple Providers**
  - [ ] Create apps in each provider's zones
  - [ ] Run `dokku dns:sync-all`
  - [ ] Verify all providers updated correctly
  - [ ] Check that AWS uses batch operations, others sync individually

### Provider Failover Testing

- [ ] **Test Partial Provider Failure**
  - [ ] Temporarily invalidate one provider's credentials
  - [ ] Run `dokku dns:apps:sync` on multi-provider app
  - [ ] Verify working providers still update successfully
  - [ ] Verify clear error message for failed provider
  - [ ] Restore credentials and verify recovery

- [ ] **Test Complete Provider Outage**
  - [ ] Simulate API outage (invalid endpoint or network block)
  - [ ] Verify graceful error handling
  - [ ] Verify other providers unaffected

---

## Installation & Deployment Testing

### Fresh Installation Test

- [ ] **Prepare Clean Dokku Instance**
  - [ ] Provision fresh Ubuntu server (20.04 or 22.04)
  - [ ] Install Dokku: `wget -NP . https://dokku.com/install/v0.32.x/bootstrap.sh && sudo DOKKU_TAG=v0.32.x bash bootstrap.sh`
  - [ ] Complete Dokku setup

- [ ] **Install DNS Plugin**
  ```bash
  sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
  ```
  - [ ] Verify installation succeeds
  - [ ] Verify `dokku dns:help` shows all commands
  - [ ] Verify plugin version: `dokku dns:version`

- [ ] **Provider Setup Workflow**
  - [ ] Follow Quick Start guide from README
  - [ ] Configure provider credentials
  - [ ] Run `dokku dns:providers:verify`
  - [ ] Enable zones: `dokku dns:zones:enable example.com`
  - [ ] Verify zones listed correctly

- [ ] **Deploy Test Application**
  ```bash
  dokku apps:create test-app
  dokku domains:add test-app www.example.com
  # Deploy sample app (e.g., Heroku buildpack app)
  ```
  - [ ] Enable DNS: `dokku dns:apps:enable test-app`
  - [ ] Sync DNS: `dokku dns:apps:sync test-app`
  - [ ] Verify DNS records created
  - [ ] Test app accessible via domain

### Trigger System Testing

- [ ] **Enable Automatic Management**
  ```bash
  dokku dns:triggers:enable
  ```
  - [ ] Verify enabled: `dokku dns:triggers`

- [ ] **Test Domain Addition Trigger**
  ```bash
  dokku domains:add test-app api.example.com
  ```
  - [ ] Verify DNS record automatically created
  - [ ] Verify no manual sync needed

- [ ] **Test Domain Removal Trigger**
  ```bash
  dokku domains:remove test-app api.example.com
  ```
  - [ ] Verify DNS record automatically removed

- [ ] **Test App Deployment Trigger**
  - [ ] Deploy update to test-app
  - [ ] Verify DNS records remain correct
  - [ ] Verify no DNS-related errors during deployment

- [ ] **Test App Destruction**
  ```bash
  dokku apps:destroy test-app-temp
  ```
  - [ ] Verify DNS records cleaned up
  - [ ] Verify app removed from DNS management

### Cron Job Testing

- [ ] **Schedule Automatic Sync**
  ```bash
  dokku dns:cron --enable --schedule "*/5 * * * *"
  ```
  - [ ] Verify cron job created: `crontab -l`
  - [ ] Wait for cron execution (5 minutes)
  - [ ] Check cron logs: `grep dns /var/log/syslog`
  - [ ] Verify sync executed successfully

- [ ] **Disable Automatic Sync**
  ```bash
  dokku dns:cron --disable
  ```
  - [ ] Verify cron job removed

---

## Common Troubleshooting Scenarios

### Scenario 1: DNS Records Not Created

**Symptoms:**
- `dokku dns:apps:sync` succeeds but no DNS records appear
- `dokku dns:report` shows "❌ ERROR" or "MISSING"

**Troubleshooting Steps:**
- [ ] Verify zone is enabled: `dokku dns:zones`
- [ ] Verify provider credentials: `dokku dns:providers:verify`
- [ ] Check if hosted zone exists in provider's dashboard
- [ ] Verify domain matches zone exactly (e.g., www.example.com needs example.com zone)
- [ ] Check plugin logs for API errors
- [ ] Verify provider API quotas not exceeded

**Resolution:**
```bash
# Re-enable zone if needed
dokku dns:zones:disable example.com
dokku dns:zones:enable example.com

# Force sync
dokku dns:apps:sync myapp
```

### Scenario 2: Wrong IP Address in DNS

**Symptoms:**
- DNS records created but point to wrong IP
- `dokku dns:report` shows "⚠️ WARNING"

**Troubleshooting Steps:**
- [ ] Verify server IP detection: Check IP in `dokku dns:report`
- [ ] Check if server behind NAT/proxy
- [ ] Verify DNS hasn't cached old IP (check TTL)
- [ ] Manually verify current IP: `curl -4 icanhazip.com`

**Resolution:**
```bash
# Force DNS update
dokku dns:apps:sync myapp

# Wait for TTL expiry, then test
dig www.example.com +short
```

### Scenario 3: Provider Authentication Failures

**Symptoms:**
- `dokku dns:providers:verify` fails
- Error messages about invalid credentials or permissions

**Troubleshooting Steps:**
- [ ] Verify credentials set correctly: `dokku config:show --global | grep -i aws\|cloudflare\|digitalocean`
- [ ] Test credentials directly with provider CLI/API
- [ ] Check IAM permissions (AWS) or token scopes (Cloudflare, DO)
- [ ] Verify no typos in credential values
- [ ] Check for expired tokens

**Resolution:**
```bash
# AWS - Verify credentials
aws sts get-caller-identity

# Cloudflare - Test API token
curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer YOUR_TOKEN"

# DigitalOcean - Test API token
curl -X GET "https://api.digitalocean.com/v2/account" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Reconfigure with correct credentials
dokku config:set --global AWS_ACCESS_KEY_ID=correct_key AWS_SECRET_ACCESS_KEY=correct_secret
```

### Scenario 4: Zones Not Auto-Discovered

**Symptoms:**
- Provider verification succeeds but no zones shown
- `dokku dns:zones` is empty

**Troubleshooting Steps:**
- [ ] Verify zones/domains exist in provider dashboard
- [ ] Check provider permissions allow zone listing
- [ ] Run verification with verbose output
- [ ] Verify zones are active (not deleted or suspended)

**Resolution:**
```bash
# Re-run provider verification
dokku dns:providers:verify [provider]

# Manually enable zone if known
dokku dns:zones:enable example.com
```

### Scenario 5: Sync-All Takes Too Long

**Symptoms:**
- `dokku dns:sync-all` times out or runs very slowly
- Many apps with DNS enabled

**Troubleshooting Steps:**
- [ ] Check number of DNS-enabled apps: `dokku dns:apps | wc -l`
- [ ] Verify provider API rate limits
- [ ] Check for network latency issues
- [ ] Review which provider is slow (AWS should be fast via batch API)

**Resolution:**
```bash
# Sync apps individually if needed
for app in $(dokku dns:apps); do
  echo "Syncing $app..."
  dokku dns:apps:sync "$app"
done

# Or disable DNS for unused apps
dokku dns:apps:disable unused-app
```

### Scenario 6: Stale DNS Records

**Symptoms:**
- DNS records exist for deleted apps or removed domains
- `dokku dns:zones` shows unexpected records

**Troubleshooting Steps:**
- [ ] List all DNS-managed apps: `dokku dns:apps`
- [ ] Check for orphaned records in provider dashboard
- [ ] Verify app domains: `dokku domains:report`

**Resolution:**
```bash
# Clean up stale records for a zone
dokku dns:sync:deletions example.com

# Review changes before running to ensure safety
```

### Scenario 7: Multi-Provider Conflicts

**Symptoms:**
- App with domains in multiple providers has sync issues
- Some domains update, others don't

**Troubleshooting Steps:**
- [ ] Verify all providers configured: `dokku dns:providers:verify`
- [ ] Check that all zones enabled: `dokku dns:zones`
- [ ] Verify each domain's zone exists in correct provider
- [ ] Review `dokku dns:report app` for each domain's status

**Resolution:**
```bash
# Verify app configuration
dokku dns:report myapp

# Sync app again
dokku dns:apps:sync myapp

# Check each provider individually
dokku dns:providers:verify aws
dokku dns:providers:verify cloudflare
dokku dns:providers:verify digitalocean
```

---

## Test Summary Template

After completing all tests, use this template to summarize results:

### Overall Test Results

**Date:** _______________
**Tester:** _______________
**Environment:** _______________
**Plugin Version:** _______________

### Provider Testing Summary

| Provider | CRUD Tests | Multi-Provider | Notes |
|----------|------------|----------------|-------|
| AWS Route53 | ⬜ Pass / ⬜ Fail | ⬜ Pass / ⬜ Fail | |
| Cloudflare | ⬜ Pass / ⬜ Fail | ⬜ Pass / ⬜ Fail | |
| DigitalOcean | ⬜ Pass / ⬜ Fail | ⬜ Pass / ⬜ Fail | |

### Installation & Integration Testing

| Test | Status | Notes |
|------|--------|-------|
| Fresh Installation | ⬜ Pass / ⬜ Fail | |
| Provider Setup | ⬜ Pass / ⬜ Fail | |
| App Deployment | ⬜ Pass / ⬜ Fail | |
| Trigger System | ⬜ Pass / ⬜ Fail | |
| Cron Jobs | ⬜ Pass / ⬜ Fail | |

### Issues Found

1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

### Recommendations

1. _____________________________________________
2. _____________________________________________
3. _____________________________________________

### Sign-off

- [ ] All critical tests passed
- [ ] All issues documented
- [ ] Ready for release: ⬜ Yes / ⬜ No

**Signature:** _______________
**Date:** _______________
