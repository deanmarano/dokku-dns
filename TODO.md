# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.



### Phase 26: Fix Test Output Issues (Critical - Pre-Release)

See `test-output-examples/` folder for actual command outputs showing these issues.

- [ ] **Fix provider-verify-output.txt Issues**
  - [ ] Reduce excessive verbosity (multiple heading levels, redundant messages)
  - [ ] Condense zone listing (don't show every zone detail in table)
  - [ ] Remove redundant "checking" messages
  - [ ] Show summary counts instead of full credential detection lists
  - [ ] Add --verbose flag for detailed output if needed

- [ ] **Fix apps-enable.txt Issues**
  - [ ] Fix contradictory "zone enabled" vs "No (no hosted zone)" messages
  - [ ] Ensure status indicators (✅/❌) match actual enablement state
  - [ ] Remove confusing "Provider" column showing "AWS" when zones aren't enabled
  - [ ] Clarify difference between "zone exists" vs "zone enabled for auto-discovery"
  - [ ] Fix Domain Status Table showing wrong information

- [ ] **Fix no-zones-found.txt Issues**
  - [ ] apps:sync fails with "No hosted zone found" despite zone being enabled
  - [ ] Zone lookup logic broken in sync operation
  - [ ] Ensure sync uses same zone detection as apps:enable
  - [ ] Test: recipes.deanoftech.com should find deanoftech.com zone (Z0444961AB4Z3I5DF5NH)

- [ ] **Fix app-create-trigger-fail.txt Issues**
  - [ ] post-create trigger says "No domains configured" but domain exists
  - [ ] Trigger doesn't detect auto-added domain from global vhost
  - [ ] Fix is_domain_in_enabled_zone function or post-create timing
  - [ ] Test: my-test-app.deanoftech.com should be detected in enabled deanoftech.com zone

- [ ] **Fix destroy-trigger.txt Issues**
  - [ ] App destroy queues domains for deletion but sync:deletions fails
  - [ ] sync:deletions says "No enabled zones found" despite zones being enabled
  - [ ] Orphaned DNS records are never deleted from Route53
  - [ ] Fix sync:deletions to use same zone detection as other commands
  - [ ] Test: my-test-app.deanoftech.com should be deleted after app destroy


### Phase 27: Code Quality - Critical Fixes (Pre-Release)

- [ ] **Fix Installation Issues**
  - [ ] Remove "default DNS provider" concept from install script
  - [ ] Update install script to detect DigitalOcean credentials/CLI
  - [ ] Install should report multi-provider mode when multiple providers detected
  - [ ] Remove PROVIDER file creation (deprecated in favor of multi-provider)

- [ ] **Improve Zone Enable Output**
  - [ ] Output copy-pastable commands when enabling a zone
  - [ ] Show `dokku dns:apps:enable <app>` commands with domain as comment
  - [ ] Format: `dokku dns:apps:enable myapp  # example.com`
  - [ ] Group by app to avoid duplicate commands

- [ ] **Update Install Script Next Steps**
  - [ ] Change "Set up AWS credentials" to "Verify provider setup" with [provider] parameter
  - [ ] Add "Enable DNS zones" as step 2 before app management
  - [ ] Update steps to: verify → zones → apps → sync (zone-centric workflow)
  - [ ] Make provider-agnostic (not AWS-specific)

- [ ] **Add Triggers to Getting Started**
  - [ ] Show `dokku dns:triggers:enable` in installation next steps
  - [ ] Add to README Quick Start guide after zone enablement
  - [ ] Explain that triggers enable automatic DNS management on domain changes

- [ ] **Add Missing zones:sync Command**
  - [ ] Create `dns:zones:sync [zone]` subcommand
  - [ ] Sync all apps/domains within a specific zone
  - [ ] If zone parameter omitted, sync all enabled zones
  - [ ] Show progress per domain within the zone

- [ ] **Fix Linting Failures**
  - [ ] Remove unused `dokku_log_fail` function in commands file (line 13)
  - [ ] Add shellcheck disable directive if function is intentionally unused for fallback

- [ ] **Fix Unsafe Error Handling Patterns**
  - [ ] Replace `set +e`/`set -e` patterns in functions:405-408 with subshells
  - [ ] Replace `set +e`/`set -e` patterns in functions:992-994 with command substitution
  - [ ] Replace `set +e`/`set -e` patterns in functions:1006-1008 with if-blocks
  - [ ] Replace `set +e`/`set -e` patterns in functions:1045-1047 with proper error handling

- [ ] **Add Safety to Destructive Operations**
  - [ ] Add explicit validation before rm -rf in post-domains-update:133
  - [ ] Verify APP variable is not empty, not "/", and directory exists before deletion
  - [ ] Add similar validation to any other rm -rf operations in codebase


### Phase 29: Pre-Release Testing & Validation

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


### Phase 30: 1.0 Release

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


### Phase 31: Community & Support (Post-Release)

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


### Phase 32: Code Quality - Medium Priority Cleanup (Post-1.0)

- [ ] **Extract Duplicate Provider Code**
  - [ ] Create `apply_dns_record` helper function in adapter.sh
  - [ ] Replace duplicated code in adapter.sh:204-210 and 221-227
  - [ ] Ensure error messages are preserved (not sent to /dev/null)
  - [ ] Add proper error logging for debugging

- [ ] **Add Comprehensive Input Validation**
  - [ ] Create `validate_dns_domain` helper function for RFC 1035 compliance
  - [ ] Add domain validation to all subcommands that accept domains
  - [ ] Add TTL validation to zones:ttl subcommand (currently missing)
  - [ ] Add TTL validation to ttl subcommand (currently missing)
  - [ ] Ensure consistent validation across all entry points

- [ ] **Define Constants in Config**
  - [ ] Add DNS_DEFAULT_TTL=300 to config file
  - [ ] Add DNS_MIN_TTL=60 to config file
  - [ ] Add DNS_MAX_TTL=86400 to config file
  - [ ] Replace hardcoded "300" in functions:981 with constant
  - [ ] Replace hardcoded TTL values in adapter.sh:202, 218 with constants
  - [ ] Update all TTL validation to use constants

- [ ] **Remove MULTI_PROVIDER_MODE Flag**
  - [ ] Remove MULTI_PROVIDER_MODE environment variable (always true, legacy code)
  - [ ] Remove all `if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]` conditionals in adapter.sh
  - [ ] Always call multi_* functions (multi_get_zone_id, multi_get_record, etc.)
  - [ ] Delete dead code branches that call provider_* directly (lines 147-155 in adapter.sh)
  - [ ] Update init_provider_system to always use multi-provider routing
  - [ ] Remove "Multi-provider mode activated" messages (it's the only mode)


### Phase 28: Code Quality - High Priority Refactoring (Pre-Release)

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


### Phase 29: 1.0 Release

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


### Phase 30: Community & Support (Post-Release)

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


### Phase 33: Code Quality - Low Priority Polish (Post-1.0)

- [ ] **Reduce Logging Verbosity**
  - [ ] Extract logging from functions:347-397 (dns_add_app_domains)
  - [ ] Create `log_domain_check` helper for conditional verbose logging
  - [ ] Add DNS_VERBOSE environment variable support
  - [ ] Reduce function to <80 lines by extracting logging

- [ ] **Create Common Functions File**
  - [ ] Create new `common-functions` file with standard fallback functions
  - [ ] Move dokku_log_info1, dokku_log_info2, dokku_log_warn, dokku_log_fail definitions
  - [ ] Update all files to source common-functions instead of duplicating
  - [ ] Remove duplicate function definitions from 10+ files (commands, subcommands, hooks)

- [ ] **Simplify Complex Conditionals**
  - [ ] Refactor functions:363-397 to use early returns
  - [ ] Extract validation logic to separate functions
  - [ ] Create `handle_no_provider_validation` helper
  - [ ] Create `validate_domains_with_provider` helper
  - [ ] Reduce nesting depth in complex conditionals

- [ ] **Standardize Quoting**
  - [ ] Audit all variable references for missing quotes
  - [ ] Ensure all `$var` become `"$var"`
  - [ ] Ensure all `${array[@]}` become `"${array[@]}"`
  - [ ] Add linting rule to enforce proper quoting



- [ ] **Improve Documentation**
  - [ ] Add detailed comments to providers/aws/provider.sh:8-28
  - [ ] Document complex regex patterns and jq operations
  - [ ] Add function-level documentation for internal helpers
  - [ ] Document expected inputs, outputs, and side effects

- [ ] **Standardize Function Naming**
  - [ ] Create naming convention guide
  - [ ] Public API: `dns_*`
  - [ ] Internal helpers: `_dns_*` (underscore prefix)
  - [ ] Predicates: `is_*` or `has_*`
  - [ ] Getters: `get_*`, Setters: `set_*`
  - [ ] Refactor inconsistent function names across codebase

- [ ] **Add ShellCheck Directives**
  - [ ] Audit all shellcheck warnings
  - [ ] Add explicit `# shellcheck disable=SCXXXX` where needed
  - [ ] Add explanatory comments for each disable directive
  - [ ] Document why each check is disabled


## Future Enhancements

### Code Quality Improvements
- [ ] **Add Prettier for Markdown Formatting**
  - [ ] Install and configure Prettier for consistent markdown formatting
  - [ ] Add Prettier to pre-commit hooks alongside shellcheck
  - [ ] Format all existing documentation files with Prettier
  - [ ] Update developer workflow to include markdown formatting
  - [ ] Consider adding .prettierrc configuration for project-specific rules
