# DNS Plugin Development TODO

## Current Status

The DNS plugin is progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

## Phase 6: Command Structure Cleanup (High Priority)

- [ ] **Restructure Command Interface for Better UX**
  - [ ] Create new command namespaces for logical grouping
  - [ ] Implement provider namespace: `dns:providers:*`
    - [ ] Move `dns:configure` → `dns:providers:configure`
    - [ ] Move `dns:verify` → `dns:providers:verify`
  - [ ] Implement apps namespace: `dns:apps:*`
    - [ ] Move `dns:add` → `dns:apps:enable`
    - [ ] Move `dns:remove` → `dns:apps:disable`
    - [ ] Move `dns:sync` → `dns:apps:sync`
    - [ ] Add `dns:apps:report` for app-specific reports
    - [ ] Create `dns:apps` (list managed apps)
    - [ ] Keep `dns:report` at top level for global reports
  - [ ] Implement zones namespace: `dns:zones:*`
    - [ ] Move `dns:zones:add` → `dns:zones:enable`
    - [ ] Move `dns:zones:remove` → `dns:zones:disable`
    - [ ] Keep `dns:zones` (list zones)
  - [ ] Update all help documentation for new command structure
  - [ ] Update all tests to use new command structure
  - [ ] Update README and examples with new commands

## Phase 7: Core Enhancements (High Priority)

- [ ] **Investigate breaking up scripts/test-integration.sh**

- [ ] **Add domain parameter to dns:apps:sync**
  - [ ] Implement domain filtering in sync command
  - [ ] Support multiple domain parameters (space-separated)
  - [ ] Optimize sync to only process specified domains
  - [ ] Use batch if possible
  - [ ] Update help text and documentation
  - [ ] Ensure proper error handling for non-existent domains
  - [ ] Add integration tests for new functionality
  - [ ] Add bats tests for new functionality

## Phase 8: AWS Provider Architecture Foundation (High Priority)

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

## Phase 9: AWS Core Operations Modularization (High Priority)

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

## Phase 10: AWS Management Operations Modularization (Medium Priority)

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

## Phase 11: AWS Provider Testing Infrastructure (Medium Priority)

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

## Phase 12: Cloudflare Provider Implementation

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

## Phase 13: 1.0 Release Preparation

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

## Phase 14: DigitalOcean Provider Implementation

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

## Phase 15: Additional Features (Lower Priority)

- [ ] **Additional Triggers** (Future Enhancement)
  - [ ] `post-app-clone-setup` - Handle domain updates when apps are cloned
  - [ ] `post-proxy-ports-set` - Handle port changes that affect DNS records
  - [ ] `post-proxy-ports-clear` - Clean up when proxy ports are removed

- [ ] **Add DNS record backup/restore** - Safety features for DNS changes
