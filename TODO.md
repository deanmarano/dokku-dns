# DNS Plugin Development TODO

## Current Status

The DNS plugin is progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

## Phase 6: Core Enhancements (High Priority)

- [ ] **Update zones:enable/zones:disable**
  - [ ] Modify commands to persist domain settings in app configuration
  - [ ] Update other (sync, report) commands to check if domain is in an enabled hosted zone instead of just checking for the app link
  - [ ] Implement proper error handling for invalid domains
  - [ ] Add integration tests for new functionality
  - [ ] Add bats tests for new functionality

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

## Recent Achievements

- ✅ **dns:sync-all** - Bulk synchronization with AWS batch optimization
- ✅ **Enhanced testing** - 23/23 tests passing with Docker integration
- ✅ **CI/CD pipeline** - Full GitHub Actions workflow with pre-commit hooks
- ✅ **Production testing** - Successfully deployed and tested on real servers
- ✅ **Documentation** - Auto-generated README with comprehensive examples

## Notes

All high-priority features are complete. The plugin is ready for production use with AWS Route53. Future enhancements are nice-to-have features that can be implemented as needed.

For implementation history and detailed accomplishments, see [DONE.md](./DONE.md).