#!/bin/bash

# Publish Prism Platform to GitHub
# This script helps you publish the prism-platform repository to GitHub

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_header() { echo -e "${BOLD}${BLUE}=== $1 ===${NC}"; }

# Check if we're in the right directory
if [[ ! -f "README.md" ]] || [[ ! -d "modules" ]] || [[ ! -f "main.tf" ]]; then
    log_error "This script must be run from the prism-platform repository root"
    exit 1
fi

log_header "Publishing Prism Platform to GitHub"

# Get GitHub username
read -p "Enter your GitHub username: " GITHUB_USERNAME
if [[ -z "$GITHUB_USERNAME" ]]; then
    log_error "GitHub username is required"
    exit 1
fi

REPO_URL="https://github.com/${GITHUB_USERNAME}/prism-platform.git"

log_info "Target repository: $REPO_URL"

# Step 1: Check current git status
log_header "Step 1: Checking Git Status"
if [[ -n $(git status --porcelain) ]]; then
    log_warning "Working directory has uncommitted changes"
    git status
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 2: Update README with correct GitHub URLs if needed
log_header "Step 2: Updating Documentation"

# Replace any placeholder URLs in README
if grep -q "github.com/your-org" README.md; then
    log_info "Updating README.md with correct GitHub URLs"
    sed -i.bak "s|github.com/your-org/prism-platform|github.com/${GITHUB_USERNAME}/prism-platform|g" README.md
    sed -i.bak "s|your-org|${GITHUB_USERNAME}|g" README.md
    rm README.md.bak 2>/dev/null || true
fi

# Step 3: Add remote origin
log_header "Step 3: Adding GitHub Remote"
if git remote get-url origin >/dev/null 2>&1; then
    CURRENT_ORIGIN=$(git remote get-url origin)
    log_warning "Remote 'origin' already exists: $CURRENT_ORIGIN"
    read -p "Replace it with $REPO_URL? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin "$REPO_URL"
        log_success "Updated remote origin to $REPO_URL"
    fi
else
    git remote add origin "$REPO_URL"
    log_success "Added remote origin: $REPO_URL"
fi

# Step 4: Rename branch to main if needed
log_header "Step 4: Preparing Branch"
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" == "master" ]]; then
    log_info "Renaming branch from 'master' to 'main'"
    git branch -M main
    log_success "Branch renamed to 'main'"
elif [[ "$CURRENT_BRANCH" == "main" ]]; then
    log_info "Already on 'main' branch"
else
    log_warning "Current branch is '$CURRENT_BRANCH', not 'main' or 'master'"
    read -p "Continue with current branch? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Step 5: Commit any final changes
if [[ -n $(git status --porcelain) ]]; then
    log_info "Committing final changes before publish"
    git add .
    git commit -m "Final updates before GitHub publication"
fi

# Step 6: Push to GitHub
log_header "Step 5: Pushing to GitHub"
echo
log_info "About to push to: $REPO_URL"
log_warning "Make sure you've created the repository on GitHub first!"
echo
read -p "Continue with push? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Pushing code to GitHub..."
    git push -u origin main
    log_success "Code pushed to GitHub successfully!"
else
    log_info "Push cancelled. You can push manually later with: git push -u origin main"
fi

# Step 6: Create release tag
log_header "Step 6: Creating Release Tag"
read -p "Create v1.2.0 release tag? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Creating v1.2.0 release tag..."
    
    git tag -a v1.2.0 -m "Initial release: Prism Platform v1.2.0

Features:
- Multi-cloud infrastructure management via Crossplane
- eBPF observability and security with Cilium/Tetragon  
- Service mesh with Istio and Merbridge
- Cell-based deployment architecture
- Toggle-able observability stack (Prometheus, Grafana, Jaeger)
- Privacy-first telemetry agent with granular controls
- Cost estimation with Infracost integration
- Complete CI/CD workflows and security scanning
- Apache 2.0 open source license

This release represents a production-ready infrastructure platform
suitable for enterprise workloads and multi-cloud deployments."

    git push origin v1.2.0
    log_success "Release tag v1.2.0 created and pushed!"
fi

# Step 7: Post-publication steps
log_header "Post-Publication Steps"
echo
log_success "🎉 Prism Platform published to GitHub!"
echo
echo "📁 Repository: ${BOLD}https://github.com/${GITHUB_USERNAME}/prism-platform${NC}"
echo
echo "🔧 ${BOLD}Next Steps:${NC}"
echo "   1. 🌐 Visit your repository: https://github.com/${GITHUB_USERNAME}/prism-platform"
echo "   2. ⚙️  Configure repository settings (see configure-github-repo.md)"
echo "   3. 🔐 Add repository secrets for CI/CD workflows"
echo "   4. 🏷️  Set up branch protection rules"
echo "   5. 📝 Enable GitHub Discussions for community engagement"
echo "   6. 🎯 Create initial GitHub Project for roadmap management"
echo "   7. 📢 Announce the open-source release!"
echo
echo "📚 ${BOLD}Documentation available:${NC}"
echo "   - README.md: Platform overview and quick start"
echo "   - CONTRIBUTING.md: Contribution guidelines"  
echo "   - LICENSE: Apache 2.0 license"
echo "   - ENVIRONMENT_SETUP.md: Development setup"
echo "   - configure-github-repo.md: GitHub configuration guide"
echo
echo "🚀 ${BOLD}Repository Features:${NC}"
echo "   ✅ Complete open-source infrastructure platform"
echo "   ✅ CI/CD workflows with security scanning"
echo "   ✅ Comprehensive documentation"
echo "   ✅ Apache 2.0 license for wide adoption"
echo "   ✅ Release v1.2.0 tagged and ready"
echo
echo "🎖️ ${BOLD}Ready for community adoption and contributions!${NC}" 