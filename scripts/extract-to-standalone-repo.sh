#!/bin/bash

# Prism Platform Repository Extraction Script
# This script prepares the prism directory for extraction as a standalone repository

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PRISM_DIR="$(dirname "$SCRIPT_DIR")"
EXTRACT_DIR="${PRISM_DIR}/../prism-platform-standalone"
TARGET_ORG="${1:-your-org}"
TARGET_REPO="${2:-prism-platform}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${NC} $1 ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────╯${NC}"
}

show_help() {
    cat << EOF
Prism Platform Repository Extraction Script

USAGE:
    $0 [ORG_NAME] [REPO_NAME]

ARGUMENTS:
    ORG_NAME     Your organization name (default: your-org)
    REPO_NAME    Repository name (default: prism-platform)

EXAMPLES:
    $0                              # Use defaults
    $0 mycompany                    # Use mycompany as org
    $0 mycompany my-infra-platform  # Custom org and repo name

This script will:
1. Create a standalone copy of the prism directory
2. Clean up prism-platform references
3. Update configuration files with your organization details
4. Initialize as a new git repository
5. Create initial commit with clean history

EOF
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

log_header "Prism Platform Repository Extraction"

log_info "Configuration:"
log_info "  Source Directory: $PRISM_DIR"
log_info "  Target Directory: $EXTRACT_DIR"
log_info "  Organization: $TARGET_ORG"
log_info "  Repository: $TARGET_REPO"
echo

# Step 1: Create clean copy
log_header "Step 1: Creating Clean Copy"

if [ -d "$EXTRACT_DIR" ]; then
    log_warning "Target directory exists: $EXTRACT_DIR"
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$EXTRACT_DIR"
    else
        log_error "Extraction cancelled"
        exit 1
    fi
fi

log_info "Copying prism directory to $EXTRACT_DIR..."
cp -r "$PRISM_DIR" "$EXTRACT_DIR"

cd "$EXTRACT_DIR"

# Step 2: Clean up files
log_header "Step 2: Cleaning Up Files"

log_info "Removing unnecessary files..."

# Remove terraform state and lock files
find . -name "*.tfstate*" -delete
find . -name ".terraform.lock.hcl" -delete
rm -rf .terraform/

# Remove backup files
find . -name "*.backup" -delete
find . -name "*.bak" -delete

# Remove test results
rm -rf test-results/

# Remove infracost cache
rm -rf .infracost/

log_success "Unnecessary files removed"

# Step 3: Update configuration files
log_header "Step 3: Updating Configuration Files"

log_info "Updating organization-specific references..."

# Update README.md
sed -i.bak "s/your-org/$TARGET_ORG/g" README.md
sed -i.bak "s/prism-platform/$TARGET_REPO/g" README.md
rm README.md.bak

# Update CONTRIBUTING.md
sed -i.bak "s/your-org/$TARGET_ORG/g" CONTRIBUTING.md
sed -i.bak "s/prism-platform/$TARGET_REPO/g" CONTRIBUTING.md
rm CONTRIBUTING.md.bak

# Update terraform.tfvars.example
sed -i.bak "s/your-org/$TARGET_ORG/g" terraform.tfvars.example
rm terraform.tfvars.example.bak

# Update backend.conf.example
sed -i.bak "s/your-org/$TARGET_ORG/g" backend.conf.example
rm backend.conf.example.bak

log_success "Configuration files updated"

# Step 4: Clean up prism-platform references
log_header "Step 4: Cleaning Corrective-Drift References"

log_info "Replacing hardcoded prism-platform references..."

# Function to replace prism-platform references in files
replace_references() {
    local file="$1"
    if [ -f "$file" ]; then
        # Replace prism-platform AWS profile with default
        sed -i.bak 's/default/default/g' "$file"
        
        # Replace prism-platform bucket names with generic ones
        sed -i.bak "s/your-org-terraform-state-bucket[0-9]*/your-org-terraform-state-bucket/g" "$file"
        sed -i.bak 's/your-org-terraform-locks/your-org-terraform-locks/g' "$file"
        
        # Replace prism-platform namespaces
        sed -i.bak 's/prism-platform/prism-platform/g' "$file"
        
        # Clean up backup file
        rm -f "$file.bak"
        
        log_info "  Updated: $file"
    fi
}

# Update configuration files
find . -name "*.sh" -o -name "*.tf" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" | while read -r file; do
    replace_references "$file"
done

log_success "Corrective-drift references cleaned"

# Step 5: Create example configurations
log_header "Step 5: Creating Example Configurations"

# Create terraform.tfvars from example
if [ ! -f "terraform.tfvars" ]; then
    cp terraform.tfvars.example terraform.tfvars
    log_info "Created terraform.tfvars from example"
fi

# Create backend.conf from example
if [ ! -f "backend.conf" ]; then
    cp backend.conf.example backend.conf
    log_info "Created backend.conf from example"
fi

log_success "Example configurations created"

# Step 6: Initialize git repository
log_header "Step 6: Initializing Git Repository"

if [ ! -d ".git" ]; then
    log_info "Initializing git repository..."
    git init
    
    # Add all files
    git add .
    
    # Create initial commit
    git commit -m "Initial commit: Prism Platform v1.2

- Multi-cloud infrastructure orchestration via Crossplane
- Cell-based deployment patterns  
- Toggleable observability stack (Prometheus, Grafana, Jaeger)
- eBPF-based networking and security (Cilium, Tetragon)
- Service mesh with mTLS (Istio + Merbridge)
- Cost estimation via Infracost
- Support for AWS, GCP, Azure, Oracle, IBM, and bare-metal
- Apache 2.0 licensed open-source platform"
    
    log_success "Git repository initialized with initial commit"
else
    log_info "Git repository already exists, skipping initialization"
fi

# Step 7: Validation
log_header "Step 7: Validation"

log_info "Running validation checks..."

# Check for remaining prism-platform references (excluding expected ones)
REMAINING_REFS=$(grep -r "corrective" . --include="*.tf" --include="*.md" --include="*.sh" --include="*.yaml" --include="*.yml" 2>/dev/null | grep -v "# This script" | grep -v "corrective_drift" | grep -v "CORRECTIVE" || echo "")

if [ -n "$REMAINING_REFS" ]; then
    log_warning "Found remaining prism-platform references:"
    echo "$REMAINING_REFS"
    echo
    log_warning "These may need manual cleanup"
else
    log_success "No remaining prism-platform references found"
fi

# Check terraform syntax
if command -v terraform >/dev/null 2>&1; then
    log_info "Validating Terraform syntax..."
    if terraform validate >/dev/null 2>&1; then
        log_success "Terraform validation passed"
    else
        log_warning "Terraform validation failed - may need backend configuration"
    fi
else
    log_warning "Terraform not installed, skipping validation"
fi

# Step 8: Next steps
log_header "Step 8: Next Steps"

cat << EOF
${GREEN}✅ Prism Platform successfully extracted to standalone repository!${NC}

${BLUE}Location:${NC} $EXTRACT_DIR

${YELLOW}Next Steps:${NC}

1. ${BLUE}Review Configuration:${NC}
   cd $EXTRACT_DIR
   # Edit terraform.tfvars and backend.conf with your specific values

2. ${BLUE}Set up Remote Repository:${NC}
   # Create repository on GitHub/GitLab
   git remote add origin https://github.com/$TARGET_ORG/$TARGET_REPO.git
   git branch -M main
   git push -u origin main

3. ${BLUE}Configure Backend:${NC}
   # Set up S3 bucket and DynamoDB table for Terraform state
   # Update backend.conf with your AWS account details
   ./scripts/platform/infrastructure/backend-setup/backend-bootstrap.sh

4. ${BLUE}Initialize Platform:${NC}
   terraform init -backend-config=backend.conf
   terraform plan
   terraform apply

5. ${BLUE}Set up CI/CD:${NC}
   # Configure GitHub Actions secrets:
   # - INFRACOST_API_KEY (optional, for cost estimation)
   # - AWS credentials (for infrastructure deployment)

${GREEN}The Prism Platform is now ready for independent development and community use!${NC}

${BLUE}Documentation:${NC}
- README.md - Platform overview and quick start
- CONTRIBUTING.md - Development and contribution guidelines  
- ENVIRONMENT_SETUP.md - Detailed setup instructions
- docs/ - Architecture and module documentation

${BLUE}Community Resources:${NC}
- Issues: Report bugs and request features
- Discussions: Ask questions and share ideas
- Pull Requests: Contribute improvements
EOF

log_success "Extraction completed successfully!" 