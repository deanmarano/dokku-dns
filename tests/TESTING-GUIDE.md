# DNS Plugin Testing Guide

## Overview

The Dokku DNS plugin uses comprehensive BATS-based testing to validate functionality with real cloud provider APIs. The test infrastructure includes both unit tests and integration tests, providing reliable validation for DNS operations that depend on external services.

## Quick Start

### Local Docker Testing (Recommended)
```bash
# Run comprehensive tests in Docker (127 unit + 66 integration tests)
scripts/test-docker.sh

# With AWS credentials for full testing
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy scripts/test-docker.sh

# List available test suites
scripts/test-docker.sh --list

# Run specific BATS integration suite
scripts/test-docker.sh --direct apps-integration.bats

# Run all tests with detailed summary
scripts/test-docker.sh --summary

# Force rebuild and show logs
scripts/test-docker.sh --build --logs
```

### Unit Testing Only
```bash
# Run 127 BATS unit tests (fast, no Docker required)
make unit-tests

# Run specific unit test suite
bats tests/dns_cron.bats
```

### Remote Server Testing
```bash
# Test against actual server with SSH
scripts/test-server.sh your-server.com root nextcloud
```

## Test Architecture

### 1. Unit Tests (127 tests)
✅ **Fast execution** - No Docker required, runs in seconds  
✅ **Comprehensive coverage** - All commands and edge cases  
✅ **BATS framework** - Professional test reporting

**Test files:**
- `dns_add.bats` (8 tests) - App enable/add functionality
- `dns_cron.bats` (16 tests) - Cron job management  
- `dns_help.bats` (9 tests) - Help system
- `dns_namespace_apps.bats` (7 tests) - App namespace commands
- `dns_namespace_zones.bats` (6 tests) - Zone namespace commands
- `dns_report.bats` (9 tests) - Reporting functionality
- `dns_sync_all.bats` (8 tests) - Global sync operations
- `dns_sync.bats` (7 tests) - Individual app sync
- `dns_triggers.bats` (13 tests) - App lifecycle triggers
- `dns_verify.bats` (11 tests) - Provider verification
- `dns_zones.bats` (33 tests) - Zone management

### 2. Integration Tests (66 tests)  
✅ **Docker-based testing** - Isolated, consistent environment  
✅ **Real plugin installation** - Full Dokku integration  
✅ **BATS framework** - Organized by functionality

**Test suites:**
- `apps-integration.bats` (6 tests) - App management functionality
- `cron-integration.bats` (17 tests) - Cron automation and scheduling
- `help-integration.bats` (4 tests) - Help commands and version
- `providers-integration.bats` (3 tests) - Provider configuration
- `report-integration.bats` (6 tests) - DNS reporting
- `triggers-integration.bats` (10 tests) - App lifecycle triggers
- `zones-integration.bats` (20 tests) - Zone operations and integration

### 3. Docker Testing (`scripts/test-docker.sh`)
✅ **Complete test environment** - Runs all 193 tests (127 unit + 66 integration)  
✅ **Enhanced reporting** - Detailed summaries and failure analysis  
✅ **Flexible execution** - Run specific suites or comprehensive testing

### 4. Remote Server Testing (`scripts/test-server.sh`)
✅ **Production validation** - Real AWS Route53 integration  
✅ **Live environment testing** - Tests against actual hosted zones

**Requires:**
- SSH access to Dokku server
- AWS credentials for Route53 testing
- Real domains with hosted zones

## Credentials Setup

### Option 1: .env File (Recommended)
```bash
cp .env.example .env
# Edit .env with your AWS credentials
echo "AWS_ACCESS_KEY_ID=AKIA..." > .env
echo "AWS_SECRET_ACCESS_KEY=your_secret" >> .env
echo "AWS_DEFAULT_REGION=us-east-1" >> .env
```

### Option 2: Environment Variables
```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=your_secret
scripts/test-docker.sh
```

## Key Test Coverage

### DNS Management Tracking
- Apps not under DNS management show warning messages
- LINKS file functionality for tracking managed apps  
- Global reports only show DNS-managed apps
- Proper app lifecycle (add → sync → remove)

### Domain Parsing Improvements
- Multiple space-separated domains display as separate table rows
- No domain concatenation in output
- Proper handling of complex domain lists

### Hosted Zone Validation
- Domain status shows "Yes"/"No (no hosted zone)"/"No (provider not ready)"
- AWS Route53 integration for zone detection
- Proper enabled/disabled logic based on zone availability

### Plugin Installation Fixes
- Elimination of confusing `plugin:install` suggestions
- Helpful configuration messages for installed plugins
- Proper plugin registration and availability

## Docker Architecture

The Docker setup uses two containers:
```
┌─────────────┐  docker exec  ┌─────────────┐
│ Test Runner │ ─────────────▶│   Dokku     │
│ (Ubuntu)    │               │ Container   │
│ • BATS      │               │ • Full      │
│ • AWS CLI   │               │   Dokku     │
│ • Tests     │               │ • Plugin    │
└─────────────┘               └─────────────┘
```

## Expected Test Results

### With AWS Credentials:
```
=====> Domain Status Table for app 'nextcloud':
Domain                    DNS    Status              Provider    Hosted Zone
------                    ---    ------              --------    -----------
nextcloud.example.com     ❌     Yes                 aws         example.com
test.example.com          ❌     Yes                 aws         example.com

=====> Syncing DNS records for app 'nextcloud'
-----> Updated DNS record: nextcloud.example.com -> 192.168.1.100
=====> DNS sync completed successfully
```

### Without AWS Credentials:
```
 !     AWS CLI is not configured or credentials are invalid.
       Run: dokku dns:providers:verify
```

## Troubleshooting

### Container Issues
```bash
# Check Docker status
docker info

# View logs
docker-compose -f docker-compose.yml logs

# Force cleanup
docker-compose -f docker-compose.yml down -v
```

### Plugin Problems
```bash
# Check plugin installation
docker exec dokku-local dokku plugin:list

# Test AWS connectivity  
docker exec dokku-local aws sts get-caller-identity
```

## Test Selection Guide

**Use unit tests (`make unit-tests`) for:**
- Daily development work
- Quick validation of command logic
- Pre-commit testing
- Fast feedback loops

**Use Docker testing (`scripts/test-docker.sh`) for:**
- Comprehensive integration testing
- Full plugin lifecycle validation
- CI/CD pipelines
- Regression testing

**Use specific BATS suites for:**
- Focused testing of specific functionality
- Debugging specific command groups
- Development of new features

**Use remote server testing (`scripts/test-server.sh`) for:**
- Final release validation
- Real hosted zone testing
- Production environment validation
- Performance testing against live AWS APIs

The DNS plugin's comprehensive BATS-based test suite (193 tests total) ensures all implemented functionality works correctly across different environments and validates both local development and production deployment scenarios.