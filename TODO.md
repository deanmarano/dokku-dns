# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.


## Phase 11: Terraform-Style Plan/Apply Workflow (High Priority)

- [ ] **Implement Terraform-style "plan" functionality in dns:report commands**
  - [ ] Add "Planned Changes" section to `dns:report` and `dns:apps:report` output
  - [ ] Show what `dns:apps:sync` would create: "+ example.com → 192.168.1.1 (A record)"
  - [ ] Show what `dns:apps:sync` would update: "~ api.example.com → 192.168.1.1 (A record) [was: 192.168.1.2]"
  - [ ] Add change summary: "Plan: 2 to add, 1 to change, 0 to destroy"
  - [ ] Use Terraform-style symbols and colors: + (green), ~ (yellow)
  - [ ] Show "No changes" when DNS records are already correct

- [ ] **Enhance dns:apps:sync to show "apply" style output**
  - [ ] Show real-time progress: "Creating A record for example.com... ✅"
  - [ ] Show what was actually changed: "Created: example.com → 192.168.1.1 (A record)"
  - [ ] Show updates: "Updated: api.example.com → 192.168.1.1 (A record) [was: 192.168.1.2]"
  - [ ] Add operation summary: "Sync complete! Resources: 2 added, 1 changed, 0 destroyed"
  - [ ] Implement `--dry-run` flag that shows plan without making changes
  - [ ] Show "No changes needed" when all DNS records are already correct

- [ ] **Create dns_plan_changes() function in functions file**
  - [ ] Compare current DNS records with expected app domains (from `dokku domains:report`)
  - [ ] Return structured data about planned additions and updates only
  - [ ] Support both single-app and multi-app planning (for dns:sync-all)
  - [ ] Include change detection logic to avoid unnecessary API calls
  - [ ] Handle cases where DNS records are already correct (no changes needed)


## Phase 13: Generic Provider Interface with Zone-Based Delegation (Medium Priority)

- [x] **Create Generic Provider Interface** ✅
  - [x] Subcommands call generic provider functions (not AWS-specific) ✅
  - [x] Provider system automatically delegates by zone to correct service ✅
  - [x] Clean separation: subcommands → generic provider → zone delegation → service (AWS/Cloudflare/etc.) ✅

- [x] **Core Generic Provider Methods (in providers/aws.sh)** ✅
  - [x] `provider_create_domain_record(domain, ip, ttl)` - Create/update A record, auto-delegates by zone ✅
  - [x] `provider_get_domain_record(domain)` - Get current IP, auto-delegates by zone ✅
  - [x] `provider_delete_domain_record(domain)` - Delete A record, auto-delegates by zone ✅
  - [x] `provider_batch_create_records(domains, ip, ttl)` - Bulk create/update, auto-delegates by zone ✅
  - [x] `provider_validate_domain(domain)` - Check if any provider can manage domain ✅
  - [x] `provider_get_domain_status(domain, server_ip)` - Get status, auto-delegates by zone ✅

- [x] **Update Core Functions to Use Generic Interface** ✅
  - [x] Update `dns_add_app_domains` to call `provider_validate_domain()` ✅
  - [x] Remove AWS-specific references in favor of generic provider calls ✅
  - [x] Provider system handles AWS/Cloudflare/etc. delegation automatically ✅

## Phase 14: AWS Management Operations Modularization (Medium Priority)

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

## Phase 15: AWS Provider Testing Infrastructure (Medium Priority)

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

## Phase 16: Cloudflare Provider Implementation

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

## Phase 17: 1.0 Release Preparation

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

## Phase 18: TTL Support (Post-1.0 Feature)

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

## Phase 19: Selective Domain Sync (Post-1.0 Feature)

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

## Phase 20: DigitalOcean Provider Implementation

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

## Phase 21: Additional Features (Lower Priority)

- [ ] **Additional Triggers** (Future Enhancement)
  - [ ] `post-app-clone-setup` - Handle domain updates when apps are cloned
  - [ ] `post-proxy-ports-set` - Handle port changes that affect DNS records
  - [ ] `post-proxy-ports-clear` - Clean up when proxy ports are removed

- [ ] **Add DNS record backup/restore** - Safety features for DNS changes
