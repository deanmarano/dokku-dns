# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

### Phase 19: Enhanced Features

- [ ] **TTL Support**
  - [ ] Add `--ttl <seconds>` parameter to relevant commands
  - [ ] Store TTL configuration per app
  - [ ] Update provider interface to use configured TTL values

### Phase 20: Command Output Standardization

- [ ] **Subcommand Output Review**
  - [ ] Audit all subcommand outputs for consistency
  - [ ] Remove unnecessary "next step/help" messages from command outputs
  - [ ] Standardize language and formatting across all commands
  - [ ] Ensure outputs are minimal and focused on operation results
  - [ ] Review and standardize error messages for consistency
  - [ ] Verify help text consistency across subcommands

### Phase 21: Provider-Level Reliability & Observability

- [ ] **Provider Abstraction Layer Enhancements**
  - [ ] Create `providers/common.sh` with shared logging and resilience functions
  - [ ] Modify `providers/adapter.sh` to wrap provider calls with retry/fallback logic
  - [ ] Update `providers/loader.sh` to add provider health tracking
  - [ ] Implement graceful degradation when providers are unavailable
  - [ ] Add detailed logging for DNS operations and timing at the provider level
  - [ ] Add circuit breaker patterns to temporarily disable failing providers
  - [ ] Create provider fallback chains (AWS → Cloudflare → DigitalOcean)
  - [ ] Add configurable logging levels and retry policies

### Phase 22: 1.0 Release Preparation (Lower Priority)

- [ ] **Documentation Overhaul**
  - [ ] Create comprehensive README with multi-provider examples
  - [ ] Add separate provider setup guides in docs/\*-provider.md for AWS, Cloudflare, DigitalOcean
  - [ ] Create FAQ section and troubleshooting guide

- [ ] **Testing & Quality Assurance**
  - [ ] Achieve 90%+ test coverage across all providers
  - [ ] Add integration tests for multi-provider scenarios
  - [ ] Perform security audit of provider integrations
  - [ ] Test installation on fresh systems

- [ ] **Release Process**
  - [ ] Create comprehensive changelog
  - [ ] Prepare 1.0 release notes highlighting multi-provider support
  - [ ] Create GitHub release with proper tagging
