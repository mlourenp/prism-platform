# GitHub Repository Configuration Guide

## Repository Settings to Configure

### 1. General Settings
- **Description**: "Open-core infrastructure management platform with multi-cloud orchestration, eBPF observability, and cell-based architecture"
- **Website**: (Add your website URL if available)
- **Topics**: `infrastructure`, `kubernetes`, `crossplane`, `ebpf`, `observability`, `multi-cloud`, `terraform`, `open-source`, `platform-engineering`
- **Features**:
  - ✅ Wikis (for additional documentation)
  - ✅ Issues (for bug reports and feature requests)
  - ✅ Sponsorships (if you want to accept sponsorships)
  - ✅ Projects (for roadmap management)
  - ✅ Discussions (for community engagement)

### 2. Branch Protection Rules
Navigate to Settings → Branches → Add rule

**Rule for `main` branch**:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Required status checks: `ci`, `terraform-validate`, `security-scan`
- ✅ Require branches to be up to date before merging
- ✅ Require linear history
- ✅ Include administrators (apply rules to admins too)

### 3. Security & Analysis
Navigate to Settings → Security & analysis

- ✅ Dependency graph
- ✅ Dependabot alerts
- ✅ Dependabot security updates
- ✅ Code scanning with CodeQL
- ✅ Secret scanning

### 4. Repository Secrets (for CI/CD)
Navigate to Settings → Secrets and variables → Actions

Add these secrets for CI/CD workflows:
```
AWS_ACCESS_KEY_ID          # For Terraform and Infracost
AWS_SECRET_ACCESS_KEY      # For Terraform and Infracost
INFRACOST_API_KEY         # For cost estimation in PRs
SLACK_WEBHOOK_URL         # For build notifications (optional)
```

### 5. Issue Templates
The `.github/` directory already includes:
- Bug report template
- Feature request template
- Pull request template

### 6. Labels for Issues/PRs
Create these labels for better organization:
- `type: bug` (red) - Something isn't working
- `type: feature` (blue) - New feature or request
- `type: documentation` (yellow) - Improvements or additions to documentation
- `type: infrastructure` (purple) - Infrastructure-related changes
- `priority: high` (red) - High priority
- `priority: medium` (orange) - Medium priority
- `priority: low` (green) - Low priority
- `status: triage` (gray) - Needs triage
- `good first issue` (green) - Good for newcomers

### 7. GitHub Pages (Optional)
If you want to host documentation:
- Navigate to Settings → Pages
- Source: Deploy from a branch
- Branch: `main` / `docs` (if you create a docs branch)

### 8. Integrations to Consider
- **Codecov**: Code coverage reporting
- **Slack/Discord**: Notifications
- **Linear/Jira**: Project management integration 