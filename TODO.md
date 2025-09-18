# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

## High Priority Tasks

### Phase 15: Enhanced Reporting with Pending Changes (High Priority)

Improve user experience with clear change previews in report commands.

- [ ] **Add "pending" functionality to dns:report commands**
  - [ ] Show planned changes in `dns:report` and `dns:apps:report`
  - [ ] Display: "+ example.com → 192.168.1.1 (A record)" for new records
  - [ ] Display: "~ api.example.com → 192.168.1.1 [was: 192.168.1.2]" for updates
  - [ ] Add change summary: "Plan: 2 to add, 1 to change, 0 to destroy"
  - [ ] Compare current DNS vs expected app domains (only as needed for reports)
  - [ ] Return structured data about planned changes (only as needed for reports)

### Phase 16: Enhanced Sync Operations ✅ COMPLETED

Improve user experience during DNS sync operations with better feedback.

- [x] **Enhance dns:apps:sync with apply-style output**
  - [x] Show real-time progress with checkmarks
  - [x] Display what was actually changed after each operation
  - [x] Show "No changes needed" when records are already correct

## Medium Priority Tasks  

### Phase 17: Provider Architecture Cleanup and Standardization ✅ COMPLETED

Clean up and standardize provider architecture for consistency and maintainability.

- [x] **AWS Provider Consolidation**
  - [x] Consolidate AWS provider from 6 files into 2 files (config.sh + provider.sh) like Cloudflare
  - [x] Merge `aws/add.sh`, `aws/sync.sh`, `aws/report.sh`, `aws/common.sh` into `aws/provider.sh`
  - [x] Keep only `aws/config.sh` and `aws/provider.sh` for consistency with template pattern
  - [x] Remove redundant AWS helper files that duplicate core functionality

- [x] **Legacy File Cleanup**
  - [x] Remove `providers/aws.sh` legacy compatibility layer (no longer needed)
  - [x] Remove `providers/aws.backup` backup file from repository
  - [x] Clean up any other obsolete provider files

- [x] **Provider Structure Standardization**
  - [x] Ensure all providers follow same 2-file pattern: `config.sh` + `provider.sh`
  - [x] Verify AWS provider implements same 6-function interface as Cloudflare
  - [x] Add missing documentation (AWS provider now has comprehensive README.md)

**Note:** Legacy provider references discovered in `functions` file and subcommands - addressed in Phase 18.

### Phase 18: Legacy Provider Reference Cleanup (High Priority)

Fix legacy references to removed AWS provider files and complete provider interface migration.

- [ ] **Fix Legacy AWS Provider References**
  - [ ] Update `functions` file references to `providers/aws.sh` (4 locations)
  - [ ] Update `subcommands/sync-all` reference to `providers/aws.sh`
  - [ ] Update `subcommands/report` references to `providers/aws.sh` (2 locations)
  - [ ] Update `subcommands/sync:deletions` reference to `providers/aws.sh`
  - [ ] Create compatibility layer or migrate to adapter system

- [ ] **Provider Interface Migration**
  - [ ] Migrate `functions` file to use provider adapter system instead of direct AWS calls
  - [ ] Update subcommands to use generic provider interface through adapter
  - [ ] Remove legacy `dns_provider_aws_*` function calls
  - [ ] Ensure all commands work with multi-provider architecture

- [ ] **Test Infrastructure Updates**
  - [ ] Update `tests/dns_zones.bats` AWS provider mock references
  - [ ] Update `tests/test_helper.bash` AWS backup file handling
  - [ ] Verify all tests pass with new provider structure

### Phase 19: DigitalOcean Provider Implementation (Medium Priority)

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

### Phase 20: Enhanced Features (Lower Priority)

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

### Phase 21: 1.0 Release Preparation (Lower Priority)

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
