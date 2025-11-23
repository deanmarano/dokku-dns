# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.

### Phase 42: Pre-Release Testing & Validation

- [x] **Create Testing Documentation**
  - [x] Create TESTING.md with manual test procedures for all providers
  - [x] Document CRUD operations test checklist for AWS Route53
  - [x] Document CRUD operations test checklist for Cloudflare
  - [x] Document CRUD operations test checklist for DigitalOcean
  - [x] Include test result logging template with pass/fail criteria
  - [x] Document common troubleshooting scenarios and solutions

- [x] **Create Automated Test Scripts**
  - [x] Create test library with shared utilities (test-lib.sh)
  - [x] Implement AWS Route53 CRUD test script
  - [x] Implement Cloudflare CRUD test script
  - [x] Implement DigitalOcean CRUD test script
  - [x] Implement multi-provider routing test script
  - [x] Create test runner orchestration script
  - [x] Document test script usage in scripts/manual-tests/README.md

- [ ] **Provider Integration Testing**
  - [ ] Execute AWS Route53 CRUD operations on production server
  - [ ] Execute Cloudflare CRUD operations on production server
  - [ ] Execute DigitalOcean CRUD operations on production server
  - [ ] Test multi-provider zone routing (domains in different providers)
  - [ ] Validate provider failover and error handling

- [ ] **Installation & Deployment Testing**
  - [ ] Test plugin installation from GitHub on fresh Dokku instance
  - [ ] Validate provider setup workflow for each provider
  - [ ] Test automatic zone discovery after provider configuration
  - [ ] Verify trigger system integration with app lifecycle events
  - [ ] Test sync-all command with multiple apps and providers


### Phase 43: 1.0 Release

- [ ] **GitHub Release Infrastructure**
  - [ ] Create semantic version tagging strategy (v1.0.0)
  - [ ] Set up release branch protection and approval workflows

- [ ] **Release Artifacts**
  - [ ] Generate documentation bundle with all guides and references
  - [ ] Create installation scripts for multiple platforms

- [ ] **Post-Release Validation**
  - [ ] Verify GitHub release visibility and downloads
  - [ ] Validate documentation link accessibility
  - [ ] Coordinate community notifications and announcements
  - [ ] Prepare issue tracking and support channels
  - [ ] Set up performance monitoring and error tracking


### Phase 44: Community & Support (Post-Release)

- [ ] **Community Announcements**
  - [ ] Post to Dokku community forum
  - [ ] Create GitHub repository announcement and pinned issue
  - [ ] Execute social media announcement strategy
  - [ ] Publish technical blog post highlighting key features

- [ ] **Support Infrastructure**
  - [ ] Create issue templates for bug reports and feature requests
  - [ ] Create discussion templates for community support
  - [ ] Write contributing guidelines for community contributors
  - [ ] Establish code of conduct and community standards

- [ ] **Post-Release Maintenance Planning**
  - [ ] Define patch release strategy and versioning scheme
  - [ ] Set up community feedback collection and analysis process
  - [ ] Create bug triage and priority classification system
  - [ ] Design feature request evaluation and roadmap integration


### Phase 46: Standardize Function Naming (Post-1.0)

**Objective:** Create consistent naming conventions across the codebase.

- [ ] Create naming convention guide document
  - [ ] Public API: `dns_*`
  - [ ] Internal helpers: `_dns_*` (underscore prefix)
  - [ ] Predicates: `is_*` or `has_*`
  - [ ] Getters: `get_*`, Setters: `set_*`
- [ ] Audit all function names for consistency
- [ ] Refactor inconsistent function names across codebase
- [ ] Update all call sites

**Effort:** High (many functions to rename)
**Impact:** Improves code consistency and clarity


### Phase 47: Add ShellCheck Directives (Post-1.0)

**Objective:** Document why specific shellcheck warnings are disabled.

- [ ] Audit all current shellcheck warnings
- [ ] Add explicit `# shellcheck disable=SCXXXX` where needed
- [ ] Add explanatory comments for each disable directive
- [ ] Document why each check is disabled

**Effort:** Medium (thorough audit required)
**Impact:** Improves code quality awareness, helps future contributors


### Phase 48: Standardize Shell Quoting (Post-1.0)

**Objective:** Ensure all variables are properly quoted to prevent word splitting.

- [ ] Audit all variable references for missing quotes
- [ ] Ensure all `$var` become `"$var"`
- [ ] Ensure all `${array[@]}` become `"${array[@]}"`
- [ ] Consider adding linting rule to enforce proper quoting

**Effort:** High (affects many lines of code)
**Impact:** Prevents subtle bugs from word splitting/globbing


## Future Enhancements

### Code Quality Improvements
- [ ] **Add Prettier for Markdown Formatting**
  - [ ] Install and configure Prettier for consistent markdown formatting
  - [ ] Add Prettier to pre-commit hooks alongside shellcheck
  - [ ] Format all existing documentation files with Prettier
  - [ ] Update developer workflow to include markdown formatting
  - [ ] Consider adding .prettierrc configuration for project-specific rules
