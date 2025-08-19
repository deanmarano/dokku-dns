# DNS Plugin Development TODO

## Current Status

The DNS plugin is progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

## Phase 6: Architecture Improvements (Medium Priority)
- [ ] **Remove global provider configuration** - Eliminate `dns:configure` command dependency
- [ ] **Make commands zone-aware** - Each zone can use different providers (AWS vs Cloudflare)
- [ ] **Provider-specific credentials** - Move from global config to per-provider credential storage
- [ ] **Zone-aware sync-all** - Auto-detect providers per zone instead of global setting
- [ ] **Provider-specific verification** - Replace global `dns:verify` with per-zone validation
- [ ] **Simplify command flow** - Direct zone operations instead of configure → add → sync workflow

## Phase 7: Plugin Triggers (In Progress)
- [x] **Implemented Triggers** ✅
  - [x] `post-create` - Initialize DNS management for new apps
  - [x] `post-delete` - Clean up DNS records after app deletion
  - [x] `post-domains-update` - Handle domain additions and removals

- [ ] **Remaining Triggers**
  - [ ] `post-app-clone-setup` - Handle domain updates when apps are cloned
  - [ ] `post-app-rename` - Update DNS records when app is renamed
  - [ ] `post-proxy-ports-set` - Handle port changes that affect DNS records
  - [ ] `post-proxy-ports-clear` - Clean up when proxy ports are removed

## Phase 8: Future Enhancements (Low Priority)
- [ ] **Add support for multiple DNS record types** - CNAME, MX, TXT records
- [ ] **Implement domain validation** - Validate domains before DNS changes
- [ ] **Add DNS record backup/restore** - Safety features for DNS changes
- [ ] **Create DNS health monitoring** - Periodic DNS record validation
- [ ] **Create Cloudflare backend** - Second provider integration
- [ ] **Add domain parameter to dns:sync** - Allow syncing specific domains only

- [ ] **Update zones:enable/zones:disable**
  - [ ] Modify commands to persist domain settings in app configuration
  - [ ] Update other (sync, report) commands to check if domain is in an enabled hosted zone instead of just checking for the app link
  - [ ] Implement proper error handling for invalid domains
  - [ ] Add integration tests for new functionality
  - [ ] Add bats tests for new functionality

- [ ] **Investiate breaking up scripts/test-integration.sh**
- [ ] **Enhance verify command**
  - [ ] Add optional provider argument to `dns:verify` (e.g., `dns:verify aws`)
  - [ ] Document using `dokku config:set` for AWS credentials:
    - [ ] `AWS_ACCESS_KEY_ID`
    - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] Enhance `dns:verify` to perform comprehensive checks for specified provider
  - [ ] If no provider specified, verify all configured providers
  - [ ] Add detailed output showing current configuration and detected credentials
  - [ ] Test connection to provider API using configured credentials
  - [ ] Update help text and documentation with provider-specific setup instructions
  - [ ] Add integration and bats tests for provider verification

- [ ] **Add domain parameter to dns:sync**
  - [ ] Implement domain filtering in sync command
  - [ ] Support multiple domain parameters (space-separated)
  - [ ] Optimize sync to only process specified domains
  - [ ] Use batch if possible
  - [ ] Update help text and documentation
  - [ ] Ensure proper error handling for non-existent domains
  - [ ] Add integration tests for new functionality
  - [ ] Add bats tests for new functionality

## Phase 7: Cloudflare Provider Implementation

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

## Phase 8: 1.0 Release Preparation

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

## Phase 9: DigitalOcean Provider Implementation

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

## Phase 9: Additional Features (Lower Priority)
- [ ] **Add DNS record backup/restore** - Safety features for DNS changes