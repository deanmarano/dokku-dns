# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.



### Phase 26: Pre-Release Testing & Validation

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
