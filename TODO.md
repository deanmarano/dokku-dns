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

### Phase 17a: Add New Provider Structure (High Priority)

Add new standardized provider structure while keeping existing system working.

- [x] **AWS Provider Structure Addition**
  - [x] Ensure `providers/aws/provider.sh` has complete 6-function interface
  - [x] Ensure `providers/aws/config.sh` has proper metadata
  - [x] Add comprehensive `providers/aws/README.md` documentation
  - [x] Verify new AWS provider structure matches Cloudflare template pattern

- [x] **Safe Cleanup of Redundant Files**
  - [x] Remove only redundant helper files: `aws/add.sh`, `aws/sync.sh`, `aws/report.sh`, `aws/common.sh`
  - [x] Remove `providers/aws.backup` backup file from repository
  - [x] Keep `providers/aws.sh` (still needed by legacy references)
  - [x] Verify all existing functionality still works

- [x] **Validation**
  - [x] Run tests to ensure no regressions
  - [x] Verify both old and new provider systems work
  - [x] Confirm all commands still function properly

### Phase 17b: Migrate to Modern Provider Interface (High Priority)

Migrate all core files to use the provider adapter system instead of direct provider calls.

- [ ] **Functions File Migration**
  - [ ] Update `functions` file to use `providers/adapter.sh` instead of direct AWS calls
  - [ ] Replace `dns_provider_aws_*` function calls with adapter functions
  - [ ] Remove 4 direct references to `providers/aws.sh` from functions file
  - [ ] Test that all DNS operations work through adapter

- [ ] **Subcommands Migration**
  - [ ] Update `subcommands/sync-all` to use adapter system
  - [ ] Update `subcommands/report` to use adapter system (2 locations)
  - [ ] Update `subcommands/sync:deletions` to use adapter system
  - [ ] Ensure all subcommands work with multi-provider architecture

- [ ] **Test Infrastructure Updates**
  - [ ] Update `tests/dns_zones.bats` to work with new provider structure
  - [ ] Update `tests/test_helper.bash` AWS backup file handling
  - [ ] Verify all tests pass with modern provider interface

### Phase 17c: Remove Legacy Provider Files (High Priority)

Safely remove legacy provider files now that everything uses the modern interface.

- [ ] **Legacy File Removal**
  - [ ] Remove `providers/aws.sh` legacy compatibility layer (now unused)
  - [ ] Clean up any remaining obsolete provider files
  - [ ] Remove any remaining legacy function references

- [ ] **Final Validation**
  - [ ] Run full test suite to ensure no regressions
  - [ ] Verify all DNS commands work properly
  - [ ] Confirm multi-provider architecture functions correctly
  - [ ] Test both AWS and Cloudflare providers work simultaneously

**Strategy:** Additive first (17a), migrate references (17b), then remove legacy (17c). Each phase is safely shipable without breaking existing functionality.

### Phase 18: DigitalOcean Provider Implementation (Medium Priority)

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

### Phase 19: Enhanced Features (Lower Priority)

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

### Phase 20: 1.0 Release Preparation (Lower Priority)

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
