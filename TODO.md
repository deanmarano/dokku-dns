# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

## High Priority Tasks

### Phase 15: Terraform-Style Plan/Apply Workflow (High Priority)

**Note: Phase 14 (Cloudflare Provider Implementation) has been completed ✅ and moved to [DONE.md](./DONE.md)**

Improve user experience with clear change previews before DNS modifications.

- [ ] **Add "plan" functionality to dns:report commands**
  - [ ] Show planned changes in `dns:report` and `dns:apps:report` 
  - [ ] Display: "+ example.com → 192.168.1.1 (A record)" for new records
  - [ ] Display: "~ api.example.com → 192.168.1.1 [was: 192.168.1.2]" for updates
  - [ ] Add change summary: "Plan: 2 to add, 1 to change, 0 to destroy"

- [ ] **Enhance dns:apps:sync with apply-style output**
  - [ ] Show real-time progress with checkmarks
  - [ ] Display what was actually changed after each operation
  - [ ] Add `--dry-run` flag to preview changes without applying
  - [ ] Show "No changes needed" when records are already correct

- [ ] **Create dns_plan_changes() helper function**
  - [ ] Compare current DNS vs expected app domains
  - [ ] Return structured data about planned changes
  - [ ] Support change detection to avoid unnecessary API calls
  - [ ] Work with both single apps and sync-all operations

## Medium Priority Tasks  

### Phase 16: Subcommand Cleanup and Provider Interface Integration (Medium Priority)

Update remaining subcommands to use the new generic provider interface.

- [ ] **Update Core Subcommands**
  - [ ] Update `dns_app()` function to use generic interface
  - [ ] Update `dns_provider_aws_sync_app()` to use generic interface
  - [ ] Update batch sync operations for multi-provider support
  - [ ] Remove legacy AWS-specific function calls

- [ ] **Update Management Commands**
  - [ ] Update `providers:verify` to work with multiple providers
  - [ ] Update zone management commands for provider-agnostic operation
  - [ ] Update reporting commands to show provider information generically

### Phase 17: DigitalOcean Provider Implementation (Medium Priority)

- [ ] **Setup DigitalOcean Provider Structure**
  - [ ] Create `providers/digitalocean/` directory using template
  - [ ] Add DigitalOcean metadata and configuration
  - [ ] Add "digitalocean" to `providers/available`

- [ ] **Implement DigitalOcean API Integration**
  - [ ] Implement 6 core provider functions for DigitalOcean API
  - [ ] Handle DigitalOcean authentication with DIGITALOCEAN_ACCESS_TOKEN
  - [ ] Support DigitalOcean domain and DNS record operations
  - [ ] Handle DigitalOcean-specific API responses and errors

## Lower Priority Tasks

### Phase 18: Enhanced Features (Lower Priority)

- [ ] **TTL Support**
  - [ ] Add `--ttl <seconds>` parameter to relevant commands
  - [ ] Store TTL configuration per app
  - [ ] Update provider interface to use configured TTL values

- [ ] **Selective Domain Sync**
  - [ ] Add domain filtering to `dns:apps:sync <app> [domain...]`
  - [ ] Implement domain validation against app's configured domains  
  - [ ] Add comprehensive tests for selective sync

- [ ] **Additional Triggers**
  - [ ] `post-app-clone-setup` - Handle cloned app domain updates
  - [ ] `post-proxy-ports-set` - Handle port changes affecting DNS

### Phase 19: 1.0 Release Preparation (Lower Priority)

- [ ] **Documentation Overhaul**
  - [ ] Create comprehensive README with multi-provider examples
  - [ ] Add provider setup guides for AWS, Cloudflare, DigitalOcean
  - [ ] Create FAQ section and troubleshooting guide
  - [ ] Add animated GIFs showing key features

- [ ] **Testing & Quality Assurance**
  - [ ] Achieve 90%+ test coverage across all providers
  - [ ] Add integration tests for multi-provider scenarios
  - [ ] Perform security audit of provider integrations
  - [ ] Test installation on fresh systems

- [ ] **Release Process**
  - [ ] Create comprehensive changelog
  - [ ] Prepare 1.0 release notes highlighting multi-provider support
  - [ ] Create GitHub release with proper tagging
