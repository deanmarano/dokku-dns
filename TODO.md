# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.



### Phase 25: Pre-Release Preparation

- [ ] **Update README Documentation**
  - [ ] Focus on zone management over app management
  - [ ] Remove docker pull image disabling instructions (not relevant)

- [ ] **Update Pre-Commit Hook**
  - [ ] Add DONE.md to documentation-only file pattern in pre-commit hook

- [ ] **Release Testing**
  - [ ] Test fresh Dokku installation on multiple platforms
  - [ ] Validate plugin installation from GitHub releases
  - [ ] Test provider setup and configuration
  - [ ] Validate multi-provider scenarios


### Phase 26: Manual Provider Testing

- [ ] **Create Manual Testing Guide**
  - [ ] Generate markdown document with manual test procedures for all providers
  - [ ] Include checkboxes for each test step (CRUD operations per provider)
  - [ ] Add sections for logging test results and observations
  - [ ] Cover all supported providers (AWS Route53, Cloudflare, DigitalOcean)
  - [ ] Include setup prerequisites and credential configuration steps
  - [ ] Document expected outcomes for each operation


### Phase 27: 1.0 Release

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


### Phase 28: Community & Support

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


## Future Enhancements

### Code Quality Improvements
- [ ] **Add Prettier for Markdown Formatting**
  - [ ] Install and configure Prettier for consistent markdown formatting
  - [ ] Add Prettier to pre-commit hooks alongside shellcheck
  - [ ] Format all existing documentation files with Prettier
  - [ ] Update developer workflow to include markdown formatting
  - [ ] Consider adding .prettierrc configuration for project-specific rules
