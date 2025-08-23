# DNS Plugin Development TODO

## Current Status

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

**Latest Update**: Pre-commit hook now skips tests for documentation-only changes, speeding up documentation commits.

## Phase 7: Remove Global Provider Concept (High Priority)

- [ ] **Remove concept of a global provider**
  - [ ] Analyze current global provider usage in codebase
  - [ ] Determine if `dns:providers:configure` command is still needed
  - [ ] Update `functions` file to remove global provider logic
  - [ ] Remove global `PROVIDER` file from `/var/lib/dokku/services/dns/`
  - [ ] Update all commands to work without global provider configuration
  - [ ] Update tests to work without global provider concept
  - [ ] Update documentation

## Phase 8: Test Infrastructure Modularization (Medium Priority)

- [ ] **Break up scripts/test-integration.sh**
  - [ ] Analyze current test-integration.sh structure (695+ lines)
  - [ ] Identify logical test suites that can be separated
  - [ ] Create modular test structure:
    - [ ] `tests/integration/core-commands.sh` - Basic command testing
    - [ ] `tests/integration/cron-functionality.sh` - Cron-specific tests  
    - [ ] `tests/integration/zones-management.sh` - Zones testing
    - [ ] `tests/integration/trigger-lifecycle.sh` - App lifecycle triggers
    - [ ] `tests/integration/error-handling.sh` - Edge cases and errors
  - [ ] Create shared test utilities in `tests/integration/common.sh`
  - [ ] Update Docker orchestrator to run modular test suites
  - [ ] Maintain single-command execution for CI (`make docker-test`)
  - [ ] Add individual test suite execution for debugging

## Phase 9: Enhanced Reporting with Sync Necessity Detection (High Priority)

- [ ] **Update report command with sync necessity detection**
  - [ ] Implement `dns_check_sync_needed()` function in `functions` file
  - [ ] Add DNS record comparison logic (current vs expected values)
  - [ ] Detect missing DNS records that need creation
  - [ ] Detect incorrect DNS records that need updating
  - [ ] Detect orphaned DNS records that need deletion
  - [ ] Add "Sync Status" section to `dns:report` output
  - [ ] Show clean, minimal preview of what `dns:apps:sync` would change
  - [ ] Include same sync necessity check in `dns:apps:report`
  - [ ] Create new `dns:zones:report <zone>` command with sync status
  - [ ] Add appropriate emojis and status indicators (✅ ⚠️ ❌)
  - [ ] Update help text and documentation for enhanced reporting

## Phase 10: DNS Cleanup Management (High Priority)

- [ ] **Track DNS records to delete**
  - [ ] Create `PENDING_DELETIONS` file structure in app directories
  - [ ] Update `post-domains-update` trigger to log domains for deletion
  - [ ] Update `post-delete` trigger to log all app domains for cleanup
  - [ ] Update `post-app-rename` trigger to log old domain cleanup
  - [ ] Create `dns_log_pending_deletion()` utility function
  - [ ] Modify report commands to show "Records to Delete" section
  - [ ] Update sync commands to process and remove pending deletions
  - [ ] Add `--cleanup-only` flag to sync commands for deletion-only runs
  - [ ] Include deletion operations in batch sync for efficiency

## Phase 11: AWS Provider Architecture Foundation (Medium Priority)

- [ ] **Restructure AWS Provider Architecture**
  - [ ] Convert `providers/aws` file into `providers/aws/` directory structure
  - [ ] Create `providers/aws/common.sh` with shared AWS utility functions
  - [ ] Move existing AWS provider functions to appropriate files
  - [ ] Ensure all provider scripts import common utilities
  - [ ] Update main provider loading to work with new structure

- [ ] **Implement Provider Function Interface**
  - [ ] Standardize provider function naming convention
  - [ ] Create provider capability detection system
  - [ ] Implement graceful fallbacks for missing provider functions
  - [ ] Update core commands to use standardized provider interface

## Phase 12: AWS Core Operations Modularization (Medium Priority)

- [ ] **Extract AWS Logic from Core DNS Commands**
  - [ ] **add command**: Extract AWS hosted zone checking to `providers/aws/add.sh`
  - [ ] **sync command**: Extract AWS-specific sync logic to `providers/aws/sync.sh`
  - [ ] **sync-all command**: Extract AWS batch optimization to `providers/aws/sync-all.sh`
  - [ ] **report command**: Extract AWS record IP checking to `providers/aws/report.sh`

- [ ] **Create Core Provider Scripts**
  - [ ] `providers/aws/add.sh` - AWS hosted zone validation for domain addition
  - [ ] `providers/aws/sync.sh` - AWS DNS record synchronization
  - [ ] `providers/aws/sync-all.sh` - AWS batch operations and optimization
  - [ ] `providers/aws/report.sh` - AWS DNS record checking and IP resolution

## Phase 13: AWS Management Operations Modularization (Medium Priority)

- [ ] **Extract AWS Logic from Management Commands**
  - [ ] **verify command**: Move AWS verification logic to `providers/aws/verify.sh`
    - [ ] AWS CLI installation checks
    - [ ] Credential detection and validation
    - [ ] Route53 permission testing
    - [ ] Hosted zones discovery
    - [ ] Account information display
  - [ ] **zones command**: Move AWS zones logic to `providers/aws/zones.sh`
    - [ ] `zones_list_aws_zones()` function
    - [ ] AWS CLI validation
    - [ ] Route53 zone listing and formatting
  - [ ] **zones:add command**: Move AWS logic to `providers/aws/zones-add.sh`
    - [ ] AWS provider validation
    - [ ] Route53 zone existence checking
    - [ ] Zone ID retrieval
  - [ ] **zones:remove command**: Move AWS logic to `providers/aws/zones-remove.sh`

- [ ] **Create Management Provider Scripts**
  - [ ] `providers/aws/verify.sh` - AWS verification and diagnostics
  - [ ] `providers/aws/zones.sh` - AWS zones listing and management
  - [ ] `providers/aws/zones-add.sh` - AWS zone addition logic
  - [ ] `providers/aws/zones-remove.sh` - AWS zone removal logic

## Phase 14: AWS Provider Testing Infrastructure (Medium Priority)

- [ ] **Provider Testing Infrastructure**
  - [ ] Create `tests/providers/aws/` directory structure
  - [ ] `tests/providers/aws/common.bats` - Test shared AWS utilities
  - [ ] `tests/providers/aws/add.bats` - Test AWS domain addition functions
  - [ ] `tests/providers/aws/sync.bats` - Test AWS sync operations
  - [ ] `tests/providers/aws/report.bats` - Test AWS reporting functions
  - [ ] `tests/providers/aws/verify.bats` - Test AWS verification functions
  - [ ] `tests/providers/aws/zones.bats` - Test AWS zones management
  - [ ] Update existing tests to work with modular provider structure

- [ ] **Documentation and Migration**
  - [ ] Update provider documentation to reflect new structure
  - [ ] Create provider development guide
  - [ ] Ensure backward compatibility during transition
  - [ ] Update integration tests to work with new provider structure

## Phase 15: Cloudflare Provider Implementation

- [ ] **Credential Validation**
  - [ ] Document using `dokku config:set` for Cloudflare credentials:
    - [ ] `CLOUDFLARE_API_TOKEN`
  - [ ] Implement `dns_provider_cloudflare_validate_credentials()`
  - [ ] Add Cloudflare API token validation
  - [ ] Check for required permissions (Zone:Read, DNS:Edit)

- [ ] **Environment Setup**
  - [ ] Implement `dns_provider_cloudflare_setup_env()`
  - [ ] Support CLOUDFLARE_API_TOKEN environment variable
  - [ ] Support .cloudflare.ini configuration file

- [ ] **Zone Management**
  - [ ] Implement `dns_provider_cloudflare_get_zone_id()`
  - [ ] Handle Cloudflare zone lookup by domain
  - [ ] Support subdomain zone lookup

- [ ] **DNS Record Operations**
  - [ ] Implement `dns_provider_cloudflare_get_record_value()`
  - [ ] Implement `dns_provider_cloudflare_create_record()`
  - [ ] Implement `dns_provider_cloudflare_delete_record()`
  - [ ] Support A, CNAME, and other record types

- [ ] **Batch Operations**
  - [ ] Implement `dns_provider_cloudflare_batch_sync_all()`
  - [ ] Optimize for Cloudflare's API rate limits
  - [ ] Implement `dns_provider_cloudflare_sync_app()`

## Phase 16: 1.0 Release Preparation

- [ ] **Documentation Overhaul**
  - [ ] Create comprehensive README with:
    - [ ] Clear installation instructions for all supported providers
    - [ ] Detailed configuration examples
    - [ ] Animated GIFs or screenshots showing key features
    - [ ] FAQ section
    - [ ] Troubleshooting guide
    - [ ] Upgrade instructions
    - [ ] Contributing guidelines
  - [ ] Ensure all command documentation is up-to-date
  - [ ] Add examples for common use cases
  - [ ] Document all environment variables

- [ ] **Testing & Quality Assurance**
  - [ ] Achieve 90%+ test coverage
  - [ ] Add integration tests for all providers
  - [ ] Perform security audit of all external dependencies
  - [ ] Verify all error messages are clear and helpful
  - [ ] Test installation on fresh systems

- [ ] **Release Process**
  - [ ] Create a changelog
  - [ ] Update version numbers
  - [ ] Prepare release notes
  - [ ] Create GitHub release with proper tagging
  - [ ] Announce on relevant channels

- [ ] **User Experience**
  - [ ] Review and improve all command output messages
  - [ ] Add progress indicators for long-running operations
  - [ ] Ensure consistent formatting across all commands
  - [ ] Add helpful hints and tips in command outputs

## Phase 17: TTL Support (Post-1.0 Feature)

- [ ] **Add TTL support for DNS records**
  - [ ] Add `--ttl <seconds>` parameter to `dns:apps:enable` command
  - [ ] Create TTL configuration storage in app directories (`TTL` file)
  - [ ] Update AWS provider to use configured TTL values (default: 300)
  - [ ] Modify `dns_provider_aws_create_record()` to accept TTL parameter
  - [ ] Update sync operations to apply configured TTL values
  - [ ] Add TTL column to domain status tables in report commands
  - [ ] Support TTL inheritance: app-level → zone-level → global default
  - [ ] Add TTL validation (minimum 60 seconds for Route53)
  - [ ] Update help text with TTL examples and best practices
  - [ ] Add BATS tests for TTL configuration and application

## Phase 18: Selective Domain Sync (Post-1.0 Feature)

- [ ] **Add selective domain sync (dns:apps:sync filtering)**
  - [ ] Modify `dns:apps:sync` command signature: `dns:apps:sync <app> [domain...]`
  - [ ] Update argument parsing in `subcommands/apps:sync` 
  - [ ] Implement domain filtering logic in sync operations
  - [ ] Support multiple domain parameters: `dns:apps:sync myapp domain1.com domain2.com`
  - [ ] Add domain validation against app's configured domains
  - [ ] Optimize AWS batch operations for filtered domains
  - [ ] Update error handling for non-existent or unmanaged domains
  - [ ] Add help examples: `dns:apps:sync myapp api.example.com www.example.com`
  - [ ] Create comprehensive BATS tests for domain filtering
  - [ ] Add integration tests for selective sync scenarios

## Phase 19: DigitalOcean Provider Implementation

- [ ] **Credential Validation**
  - [ ] Document using `dokku config:set` for DigitalOcean credentials:
    - [ ] `DIGITALOCEAN_ACCESS_TOKEN`
  - [ ] Implement `dns_provider_digitalocean_validate_credentials()`
  - [ ] Add DigitalOcean API token validation
  - [ ] Check for required permissions (read/write for DNS)

- [ ] **Environment Setup**
  - [ ] Implement `dns_provider_digitalocean_setup_env()`
  - [ ] Support DIGITALOCEAN_ACCESS_TOKEN environment variable
  - [ ] Support ~/.config/doctl/config.yaml configuration

- [ ] **Domain Management**
  - [ ] Implement `dns_provider_digitalocean_get_domain()`
  - [ ] Handle domain verification and lookup
  - [ ] Support subdomain management

- [ ] **DNS Record Operations**
  - [ ] Implement `dns_provider_digitalocean_get_record_value()`
  - [ ] Implement `dns_provider_digitalocean_create_record()`
  - [ ] Implement `dns_provider_digitalocean_delete_record()`
  - [ ] Support A, CNAME, and other record types

- [ ] **Batch Operations**
  - [ ] Implement `dns_provider_digitalocean_batch_sync_all()`
  - [ ] Handle DigitalOcean's API rate limits
  - [ ] Implement `dns_provider_digitalocean_sync_app()`

## Phase 20: Additional Features (Lower Priority)

- [ ] **Additional Triggers** (Future Enhancement)
  - [ ] `post-app-clone-setup` - Handle domain updates when apps are cloned
  - [ ] `post-proxy-ports-set` - Handle port changes that affect DNS records
  - [ ] `post-proxy-ports-clear` - Clean up when proxy ports are removed

- [ ] **Add DNS record backup/restore** - Safety features for DNS changes
