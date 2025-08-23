# DNS Plugin Testing Guide

## Overview

The Dokku DNS plugin uses integration testing to validate functionality with real cloud provider APIs. This approach is more reliable than unit tests for DNS operations that depend on external services.

## Quick Start

### Local Docker Testing (Recommended)
```bash
# Run comprehensive tests in Docker
scripts/test-docker.sh

# With AWS credentials for full testing
AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy scripts/test-docker.sh

# Force rebuild and show logs
scripts/test-docker.sh --build --logs
```

### Remote Server Testing
```bash
# Test against actual server with SSH
scripts/test-server.sh your-server.com root nextcloud
```

## Test Methods

### 1. Docker Testing (`scripts/test-docker.sh`)
✅ **Best for development** - Fast, isolated, consistent environment  
✅ **No remote server required** - 2-3 minutes execution time  
✅ **Complete test coverage** - All fixes and edge cases verified

**What it tests:**
- Plugin installation and configuration
- All DNS commands (apps:enable, apps:sync, report, apps:disable, providers:configure, providers:verify)
- Domain parsing for multiple domains
- DNS management tracking with LINKS file
- Hosted zone validation
- Error handling and edge cases

### 2. Remote Server Testing (`scripts/test-server.sh`)
✅ **Best for final validation** - Real AWS Route53 integration  
✅ **Production-like environment** - Tests against actual hosted zones  

**Requires:**
- SSH access to Dokku server
- AWS credentials for Route53 testing
- Real domains with hosted zones

### 3. Integration Testing (`scripts/test-integration.sh`)
✅ **Lightweight testing** - Core functionality without Docker overhead  
✅ **CI/CD friendly** - No external dependencies

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

**Use Docker testing (`scripts/test-docker.sh`) for:**
- Daily development work
- Regression testing
- CI/CD pipelines
- Quick validation of changes

**Use remote server testing (`scripts/test-server.sh`) for:**
- Final release validation
- Real hosted zone testing
- Production environment validation
- Performance testing against live AWS APIs

The DNS plugin's comprehensive test suite ensures all implemented fixes work correctly across different environments and validates both local development and production deployment scenarios.