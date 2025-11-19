# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.


### Phase 28: Display and Reporting Fixes (Pre-Release)

**Objective:** Reduce excessive output verbosity in provider verification.

**Note:** Zone lookup fixes completed in PR #66 - see DONE.md Phase 28.

- [ ] **Reduce provider:verify Output Verbosity**
  - [ ] Reduce excessive verbosity (multiple heading levels, redundant messages)
  - [ ] Condense zone listing (don't show every zone detail in table)
  - [ ] Remove redundant "checking" messages
  - [ ] Show summary counts instead of full credential detection lists
  - [ ] Add --verbose flag for detailed output if needed
  - **Problem:** `dns:providers:verify` output is excessively verbose
  - **Reference:** See `test-output-examples/provider-verify-output.txt`


### Phase 29: Trigger System Improvements (Pre-Release)

**Objective:** Fix post-create trigger failing to detect auto-added domains from global vhost.

- [ ] **Fix Post-Create Trigger Domain Detection**
  - [ ] post-create trigger says "No domains configured" but domain exists
  - [ ] Trigger doesn't detect auto-added domain from global vhost
  - [ ] Fix is_domain_in_enabled_zone function or post-create timing
  - [ ] Test: my-test-app.deanoftech.com should be detected in enabled deanoftech.com zone
  - **Problem:** Trigger runs before domain is fully configured
  - **Reference:** See `test-output-examples/app-create-trigger-fail.txt`


### Phase 30: Zone Management UX Improvements (Pre-Release)

**Objective:** Improve user experience for zone management with better output and new sync command.

- [ ] **Improve Zone Enable Output**
  - [ ] Output copy-pastable commands when enabling a zone
  - [ ] Show `dokku dns:apps:enable <app>` commands with domain as comment
  - [ ] Format: `dokku dns:apps:enable myapp  # example.com`
  - [ ] Group by app to avoid duplicate commands
  - **Goal:** Make it easier for users to enable apps after enabling zones

- [ ] **Add zones:sync Command**
  - [ ] Create `dns:zones:sync [zone]` subcommand
  - [ ] Sync all apps/domains within a specific zone
  - [ ] If zone parameter omitted, sync all enabled zones
  - [ ] Show progress per domain within the zone
  - **Goal:** Bulk sync operations at the zone level


### Phase 31: Define TTL Constants (Pre-Release) ⚡ QUICK WIN

**Objective:** Extract magic numbers into named constants for better maintainability.

- [ ] Add DNS_DEFAULT_TTL=300 to config file
- [ ] Add DNS_MIN_TTL=60 to config file
- [ ] Add DNS_MAX_TTL=86400 to config file
- [ ] Replace hardcoded "300" in functions:981 with DNS_DEFAULT_TTL
- [ ] Replace hardcoded TTL values in adapter.sh:202, 218 with DNS_DEFAULT_TTL
- [ ] Update all TTL validation to use DNS_MIN_TTL and DNS_MAX_TTL constants

**Effort:** Low (simple search and replace)
**Impact:** Improves code clarity and makes TTL changes easier


### Phase 32: Extract Duplicate Provider Code (Pre-Release) ⚡ QUICK WIN

**Objective:** DRY up duplicated DNS record application logic.

- [ ] Create `apply_dns_record` helper function in adapter.sh
- [ ] Replace duplicated code in adapter.sh:204-210 and 221-227
- [ ] Ensure error messages are preserved (not sent to /dev/null)
- [ ] Add proper error logging for debugging

**Effort:** Low (small refactor, 2 call sites)
**Impact:** Reduces code duplication, improves maintainability


### Phase 33: Remove MULTI_PROVIDER_MODE Flag (Pre-Release) ⚡ QUICK WIN

**Objective:** Remove legacy feature flag that's always enabled.

- [ ] Remove MULTI_PROVIDER_MODE environment variable (always true, legacy code)
- [ ] Remove all `if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]` conditionals in adapter.sh
- [ ] Always call multi_* functions (multi_get_zone_id, multi_get_record, etc.)
- [ ] Delete dead code branches that call provider_* directly (lines 147-155 in adapter.sh)
- [ ] Update init_provider_system to always use multi-provider routing
- [ ] Remove "Multi-provider mode activated" messages (it's the only mode)

**Effort:** Low (code deletion, already dead code)
**Impact:** Simplifies codebase, removes confusing messages


### Phase 34: Fix Direct provider_get_zone_id Calls (Pre-Release)

**Objective:** Replace direct provider interface calls with multi-provider router in application code.

- [ ] **functions:406** - Replace `provider_get_zone_id` with `multi_get_zone_id` in skipped domains warning
- [ ] **functions:800** - Replace `provider_get_zone_id` with `multi_get_zone_id` in DNS sync logic
- [ ] Verify multi-provider routing works correctly for both call sites

**Effort:** Low (2 specific replacements)
**Impact:** Fixes architectural violations, ensures proper provider routing
**Note:** `provider_get_zone_id` is the provider interface (each provider implements it)
**Note:** `multi_get_zone_id` is the multi-provider router (application code should use this)
**Architecture:** Application → `multi_get_zone_id` → finds provider → `provider_get_zone_id`


### Phase 35: Add TTL Input Validation (Pre-Release)

**Objective:** Add missing validation to TTL subcommands.

- [ ] Add TTL validation to zones:ttl subcommand (currently missing)
- [ ] Add TTL validation to ttl subcommand (currently missing)
- [ ] Use DNS_MIN_TTL and DNS_MAX_TTL constants (from Phase 31)
- [ ] Ensure consistent validation across all entry points
- [ ] Add user-friendly error messages for invalid TTL values

**Effort:** Low (simple validation checks)
**Impact:** Prevents invalid TTL values, improves UX
**Dependency:** Should be done after Phase 31 (TTL constants)


### Phase 36: Pre-Release Testing & Validation

- [ ] **Create Testing Documentation**
  - [ ] Create TESTING.md with manual test procedures for all providers
  - [ ] Document CRUD operations test checklist for AWS Route53
  - [ ] Document CRUD operations test checklist for Cloudflare
  - [ ] Document CRUD operations test checklist for DigitalOcean
  - [ ] Include test result logging template with pass/fail criteria
  - [ ] Document common troubleshooting scenarios and solutions

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


### Phase 37: 1.0 Release

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


### Phase 38: Community & Support (Post-Release)

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


### Phase 39: Add Domain Input Validation (Post-1.0)

**Objective:** Add RFC 1035 domain validation across all entry points.

- [ ] Create `validate_dns_domain` helper function for RFC 1035 compliance
- [ ] Add domain validation to all subcommands that accept domains
- [ ] Ensure consistent validation across all entry points
- [ ] Add user-friendly error messages for invalid domains

**Effort:** Medium (need to identify all entry points)
**Impact:** Prevents invalid domain names, improves robustness


### Phase 40: Audit Legacy Provider Patterns (Post-1.0)

**Objective:** Find and catalog remaining legacy provider-specific code.

- [ ] Search codebase for `dns_provider_` function calls
- [ ] Search for direct provider function calls (aws_*, cloudflare_*, digitalocean_*)
- [ ] Find `dns_provider_aws_get_hosted_zone_id` calls
- [ ] Find `dns_provider_aws_*` calls
- [ ] Audit all hooks for legacy provider patterns
- [ ] Audit all subcommands for legacy provider patterns
- [ ] Audit functions file for legacy provider patterns
- [ ] Document all findings with file:line references

**Effort:** Medium (thorough search required)
**Impact:** Creates roadmap for complete multi-provider migration
**Note:** This is discovery work - actual fixes in later phases


### Phase 41: Create Common Functions File (Post-1.0)

**Objective:** Eliminate duplicate logging function definitions across 10+ files.

- [ ] Create new `common-functions` file with standard fallback functions
- [ ] Move dokku_log_info1, dokku_log_info2, dokku_log_warn, dokku_log_fail definitions
- [ ] Update all files to source common-functions instead of duplicating
- [ ] Remove duplicate function definitions from commands, subcommands, hooks

**Effort:** Medium (many files to update)
**Impact:** Reduces code duplication, ensures consistent logging behavior


### Phase 42: Refactor zones Subcommand to Multi-Provider (Post-1.0)

**Objective:** Make zones subcommand work with all providers, not just AWS.

- [ ] **subcommands/zones** - AWS-specific code remains (lines 74-180, 190-391)
  - [ ] Remove hardcoded AWS provider references (lines 74-75, 190-191)
  - [ ] Replace `zones_list_aws_zones()` with provider-agnostic implementation
  - [ ] Update `zones_show_zone()` to use multi-provider system
  - [ ] Remove AWS CLI direct calls and use provider interface
  - [ ] Update test mocks to work with provider interface
  - **Problem:** Tests expect specific AWS CLI query patterns
  - **Challenge:** Need to update both code and test mocks together
  - **Impact:** zones command only works with AWS Route53 currently

**Effort:** High (complex refactor with test compatibility issues)
**Impact:** Enables zones command for Cloudflare and DigitalOcean
**Note:** Attempted in commit 50655bd but reverted in ce59bcb due to test failures


### Phase 43: Refactor zones:enable to Multi-Provider (Post-1.0)

**Objective:** Make zones:enable work with all providers, not just AWS.

- [ ] **subcommands/zones:enable** - AWS-specific code remains
  - [ ] **zones_add_zone()** function (lines 90-117) uses AWS CLI directly
  - [ ] **zones_add_all()** function (lines 122-154) uses AWS CLI directly
  - [ ] Replace AWS CLI calls with multi-provider system
  - [ ] Load provider loader system to find which provider manages each zone
  - [ ] Use `provider_get_zone_id()` through multi-provider routing
  - [ ] Use `provider_list_zones()` for --all flag
  - **Problem:** Direct AWS CLI usage prevents other providers from working
  - **Impact:** zones:enable only works with AWS Route53 currently

**Effort:** High (complex refactor)
**Impact:** Enables zone management for Cloudflare and DigitalOcean


### Phase 44: Audit Other Zone Subcommands (Post-1.0)

**Objective:** Check zones:disable and zones:ttl for AWS-specific code.

- [ ] **subcommands/zones:disable** - Review and update to use multi-provider system if needed
- [ ] **subcommands/zones:ttl** - Review and update to use multi-provider system if needed
- [ ] Document any AWS-specific code found
- [ ] Create follow-up tasks for any refactoring needed

**Effort:** Low (audit only, fixes may be needed)
**Impact:** Ensures all zone subcommands support multiple providers


### Phase 45: Code Polish - Logging Verbosity (Post-1.0)

**Objective:** Reduce excessive logging in dns_add_app_domains function.

- [ ] Extract logging from functions:347-397 (dns_add_app_domains)
- [ ] Create `log_domain_check` helper for conditional verbose logging
- [ ] Add DNS_VERBOSE environment variable support
- [ ] Reduce function to <80 lines by extracting logging

**Effort:** Medium (requires careful refactoring)
**Impact:** Improves code readability, optional verbose output


### Phase 46: Simplify Complex Conditionals (Post-1.0)

**Objective:** Reduce nesting depth and complexity in validation logic.

- [ ] Refactor functions:363-397 to use early returns
- [ ] Extract validation logic to separate functions
- [ ] Create `handle_no_provider_validation` helper
- [ ] Create `validate_domains_with_provider` helper
- [ ] Reduce nesting depth in complex conditionals

**Effort:** Medium (refactoring complex logic)
**Impact:** Improves code readability and maintainability


### Phase 47: Improve Provider Documentation (Post-1.0)

**Objective:** Add detailed comments to complex provider code.

- [ ] Add detailed comments to providers/aws/provider.sh:8-28
- [ ] Document complex regex patterns and jq operations
- [ ] Add function-level documentation for internal helpers
- [ ] Document expected inputs, outputs, and side effects

**Effort:** Low (documentation only)
**Impact:** Improves code comprehension for contributors


### Phase 48: Standardize Function Naming (Post-1.0)

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


### Phase 49: Add ShellCheck Directives (Post-1.0)

**Objective:** Document why specific shellcheck warnings are disabled.

- [ ] Audit all current shellcheck warnings
- [ ] Add explicit `# shellcheck disable=SCXXXX` where needed
- [ ] Add explanatory comments for each disable directive
- [ ] Document why each check is disabled

**Effort:** Medium (thorough audit required)
**Impact:** Improves code quality awareness, helps future contributors


### Phase 50: Standardize Shell Quoting (Post-1.0)

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
