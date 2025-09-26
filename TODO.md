# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.


### Phase 21: Documentation Overhaul

- [ ] **Comprehensive README Enhancement**
  - [ ] Create quick start section
  - [ ] Verify complete command reference with examples for all subcommands
  - [ ] Include workflow examples: domain, app, zone management
  - [ ] Document TTL hierarchy (global → zone → domain) with examples
  - [ ] Add links to provider-specific setup guides

- [ ] **Provider-Specific Documentation**
  - [ ] Create docs/aws-provider.md with complete AWS Route53 setup:
    - [ ] AWS credentials configuration (IAM roles, access keys, profiles)
    - [ ] Required IAM permissions and policy examples
    - [ ] Hosted zone setup and verification steps
    - [ ] AWS CLI installation and configuration
  - [ ] Create docs/cloudflare-provider.md with complete Cloudflare setup:
    - [ ] API token creation and scoping instructions
    - [ ] Zone management and DNS record permissions
    - [ ] Cloudflare-specific features and limitations
  - [ ] Create docs/digital-ocean-provider.md with complete DigitalOcean setup:
    - [ ] API token creation and scoping instructions
    - [ ] Zone management and DNS record permissions
    - [ ] DigitalOcean-specific features and limitations
  - [ ] Document advanced multi-provider scenarios:
    - [ ] Zone delegation between providers
    - [ ] Provider failover and backup strategies
    - [ ] Geographic DNS distribution patterns
    - [ ] Cost optimization across multiple providers

- [ ] **User Experience Documentation**
  - [ ] Create docs/FAQ.md covering comprehensive questions:
    - [ ] Installation and setup questions
    - [ ] Provider configuration and credential issues
    - [ ] DNS propagation and timing questions
    - [ ] Multi-provider behavior and zone routing
    - [ ] TTL configuration and hierarchy questions
    - [ ] Troubleshooting and error recovery
    - [ ] Performance and scaling considerations
  - [ ] Create docs/configuration.md documenting all options:
    - [ ] Environment variable reference (DNS_LOG_LEVEL, etc.)
    - [ ] TTL configuration options and hierarchy
    - [ ] Provider-specific configuration settings
    - [ ] Zone enablement and management options
    - [ ] Cron automation and scheduling configuration
    - [ ] Security considerations and credential storage

### Phase 22: Testing & Quality Assurance

- [ ] **Test Coverage Enhancement**
  - [ ] Audit current test coverage across all 238 existing tests
  - [ ] Identify and fill gaps to achieve 90%+ code coverage
  - [ ] Add comprehensive edge case testing for all provider functions:
    - [ ] Invalid credentials and authentication edge cases
    - [ ] Malformed DNS records and zone names
    - [ ] Network timeouts and connection failures
    - [ ] API rate limiting and quota exhaustion scenarios
    - [ ] Large-scale operations (100+ domains per app)
  - [ ] Enhance error condition testing:
    - [ ] DNS provider service outages and degradation
    - [ ] Partial API failures and inconsistent responses
    - [ ] Concurrent operation conflicts and race conditions
    - [ ] File system permission and storage issues
    - [ ] Memory and resource exhaustion scenarios
  - [ ] Add performance benchmarking tests:
    - [ ] DNS operation timing benchmarks (single vs multi-provider)
    - [ ] Bulk operation performance testing (sync-all command)
    - [ ] Provider comparison performance metrics
    - [ ] Memory usage profiling during large operations
    - [ ] Load testing with multiple concurrent apps

- [ ] **Multi-Provider Integration Tests (using Mock Provider for stubbing)**
  - [ ] Enhance mock provider for comprehensive testing scenarios:
    - [ ] Add configurable failure modes and API error simulation
    - [ ] Implement rate limiting and timeout simulation capabilities
    - [ ] Add zone delegation and cross-provider routing simulation
    - [ ] Create mock provider state persistence for multi-step tests
  - [ ] Test provider failure and recovery scenarios using mock provider:
    - [ ] Single provider failure with mock provider fallback simulation
    - [ ] Partial provider functionality degradation using mock error modes
    - [ ] Network partition simulation using mock provider timeouts
    - [ ] Provider credential expiration testing with mock authentication failures

- [ ] **Security & Reliability Testing**
  - [ ] Test installation on fresh systems:
    - [ ] Ubuntu 20.04 LTS and 22.04 LTS installation testing
    - [ ] CentOS 7 and Rocky Linux 8 installation verification
    - [ ] Debian 10 and 11 compatibility testing
    - [ ] Docker container deployment testing
    - [ ] Minimal system resource requirement validation

### Phase 23: 1.0 Release Process

- [ ] **Release Documentation**
  - [ ] Use DONE.md to create comprehensive CHANGELOG.md with all development phases:
    - [ ] Document all 20+ completed phases with technical details
    - [ ] List all new features, enhancements, and bug fixes
    - [ ] Include performance improvements and optimizations
    - [ ] Document architectural changes and multi-provider additions
    - [ ] Add migration instructions for each major version change
  - [ ] Prepare comprehensive 1.0 release notes:
    - [ ] Executive summary highlighting multi-provider support
    - [ ] Feature showcase with before/after comparisons
    - [ ] Performance benchmarks and reliability improvements
    - [ ] User testimonials and success stories (if available)
    - [ ] Technical architecture overview and design decisions
  - [ ] Document breaking changes and migration paths:
    - [ ] API changes and deprecated command mappings
    - [ ] Configuration file format changes
    - [ ] Provider configuration migration requirements
    - [ ] Data migration scripts and procedures
    - [ ] Rollback procedures for failed upgrades
  - [ ] Create upgrade guide from previous versions:
    - [ ] Version compatibility matrix
    - [ ] Step-by-step upgrade procedures
    - [ ] Pre-upgrade checklist and backup procedures
    - [ ] Post-upgrade validation and testing steps
    - [ ] Troubleshooting common upgrade issues

- [ ] **Release Packaging**
  - [ ] Prepare GitHub release infrastructure:
    - [ ] Create semantic version tagging strategy (v1.0.0)
    - [ ] Set up release branch protection and approval workflows
    - [ ] Configure automated release notes generation
    - [ ] Set up release artifact generation and signing
  - [ ] Generate comprehensive release artifacts:
    - [ ] Source code archives with proper exclusions
    - [ ] Documentation bundle with all guides and references
    - [ ] Installation scripts for multiple platforms
    - [ ] Provider setup automation scripts
    - [ ] Test suite and validation tools package
  - [ ] Test release installation process:
    - [ ] Fresh Dokku installation testing on multiple platforms
    - [ ] Plugin installation from GitHub releases
    - [ ] Provider setup and configuration testing
    - [ ] Multi-provider scenario validation
    - [ ] Rollback and downgrade procedure testing
  - [ ] Create post-release validation checklist:
    - [ ] GitHub release visibility and download verification
    - [ ] Documentation link validation and accessibility
    - [ ] Community notification and announcement coordination
    - [ ] Issue tracking and support channel preparation
    - [ ] Performance monitoring and error tracking setup

- [ ] **Community and Marketing**
  - [ ] Prepare community announcements:
    - [ ] Dokku community forum announcement
    - [ ] GitHub repository announcement and pinned issue
    - [ ] Social media announcement strategy
    - [ ] Technical blog post highlighting key features
  - [ ] Set up release support infrastructure:
    - [ ] Issue templates for bug reports and feature requests
    - [ ] Discussion templates for community support
    - [ ] Contributing guidelines for community contributors
    - [ ] Code of conduct and community standards
  - [ ] Plan post-release maintenance:
    - [ ] Patch release strategy and versioning scheme
    - [ ] Community feedback collection and analysis process
    - [ ] Bug triage and priority classification system
    - [ ] Feature request evaluation and roadmap integration

## Future Enhancements

### Code Quality Improvements
- [ ] **Add Prettier for Markdown Formatting**
  - [ ] Install and configure Prettier for consistent markdown formatting
  - [ ] Add Prettier to pre-commit hooks alongside shellcheck
  - [ ] Format all existing documentation files with Prettier
  - [ ] Update developer workflow to include markdown formatting
  - [ ] Consider adding .prettierrc configuration for project-specific rules
