# Contributing to Prism Platform

Thank you for your interest in contributing to the Prism Platform! This document provides guidelines and information for contributors.

## 🎯 Project Goals

Prism is an open-core infrastructure management plane that provides:
- Multi-cloud orchestration via Crossplane
- Cell-based deployment patterns
- Toggle-able observability stack
- eBPF-based networking and security
- Cost transparency and optimization

## 🚀 Getting Started

### Prerequisites

- **Terraform** >= 1.0
- **kubectl** >= 1.24
- **Helm** >= 3.0
- **Go** >= 1.19 (for testing)
- **Docker** (for local development)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/prism-community/prism-platform.git
cd prism-platform

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars
cp backend.conf.example backend.conf

# Edit the configuration files with your values
# Initialize Terraform
terraform init -backend-config=backend.conf

# Validate the configuration
terraform validate
terraform plan
```

## 📝 Contribution Guidelines

### Code Standards

1. **Terraform Code**:
   - Use consistent formatting: `terraform fmt`
   - Validate syntax: `terraform validate`
   - Follow HashiCorp best practices
   - Include comprehensive variable descriptions
   - Provide meaningful output descriptions

2. **Documentation**:
   - Every module must have a `README.md`
   - Include usage examples
   - Document all variables and outputs
   - Keep documentation up-to-date with code changes

3. **Security**:
   - Follow security best practices
   - Use least privilege principle
   - Never commit secrets or credentials
   - Use Terraform sensitive variables where appropriate

### Pull Request Process

1. **Fork and Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes**:
   - Follow the coding standards above
   - Add or update tests as needed
   - Update documentation

3. **Test Locally**:
   ```bash
   # Format code
   terraform fmt -recursive
   
   # Validate syntax
   terraform validate
   
   # Run security scan
   tfsec .
   
   # Test modules individually
   cd modules/your-module
   terraform init -backend=false
   terraform validate
   ```

4. **Commit Changes**:
   - Use descriptive commit messages
   - Reference issue numbers where applicable
   - Keep commits focused and atomic

5. **Submit Pull Request**:
   - Provide clear description of changes
   - Include testing instructions
   - Link to related issues
   - Ensure CI checks pass

### Module Development

When creating new modules:

1. **Structure**:
   ```
   modules/your-module/
   ├── README.md          # Module documentation
   ├── main.tf           # Main resources
   ├── variables.tf      # Input variables
   ├── outputs.tf        # Output values
   ├── versions.tf       # Provider requirements
   └── examples/         # Usage examples
       └── basic/
           ├── main.tf
           └── README.md
   ```

2. **Documentation Template**:
   - Include purpose and features
   - Provide usage examples
   - Document all inputs and outputs
   - Include cost considerations
   - Add troubleshooting section

3. **Testing**:
   - Create example configurations
   - Test with multiple provider versions
   - Validate on different cloud providers
   - Include integration tests where possible

## 🧪 Testing

### Local Testing

```bash
# Validate all Terraform files
find . -name "*.tf" -exec terraform fmt -check {} \;

# Security scanning
tfsec --soft-fail .

# Module validation
for module in modules/*/; do
  echo "Testing $module"
  cd "$module"
  terraform init -backend=false
  terraform validate
  cd ../..
done
```

### CI/CD Pipeline

Our CI pipeline includes:
- Terraform validation and formatting checks
- Security scanning with tfsec
- Module validation across all modules
- Cost estimation with Infracost
- Documentation checks

## 🐛 Bug Reports

When reporting bugs:

1. **Use the Issue Template**
2. **Provide Environment Information**:
   - Terraform version
   - Provider versions
   - Cloud provider and region
   - Cluster configuration

3. **Include Reproduction Steps**:
   - Clear step-by-step instructions
   - Configuration files (sanitized)
   - Error messages and logs
   - Expected vs actual behavior

## 💡 Feature Requests

For new features:

1. **Check Existing Issues**: Avoid duplicates
2. **Use Feature Template**: Provide structured information
3. **Describe Use Case**: Explain the problem being solved
4. **Consider Alternatives**: Discuss other solutions considered
5. **Implementation Ideas**: Suggest approach if you have one

## 📋 Code Review

### Review Criteria

- **Functionality**: Does it work as intended?
- **Security**: Are there security implications?
- **Performance**: Impact on resource usage/costs?
- **Maintainability**: Is the code clear and well-documented?
- **Compatibility**: Works across supported platforms?

### Review Process

1. **Automated Checks**: Must pass CI/CD pipeline
2. **Peer Review**: At least one maintainer approval
3. **Testing**: Verify functionality in test environment
4. **Documentation**: Ensure docs are updated

## 🏷️ Versioning and Releases

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Process

1. **Version Bump**: Update version in relevant files
2. **Changelog**: Document changes in CHANGELOG.md
3. **Tag Release**: Create git tag with version
4. **GitHub Release**: Automated via CI/CD
5. **Documentation**: Update version references

## 🤝 Community Guidelines

### Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers get started
- Assume positive intent

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and ideas
- **Pull Requests**: Code contributions and reviews

## 📚 Resources

### Learning Resources

- [Terraform Documentation](https://terraform.io/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
- [Istio Documentation](https://istio.io/docs)

### Development Tools

- [tfsec](https://github.com/aquasecurity/tfsec): Security scanner
- [Infracost](https://www.infracost.io/): Cost estimation
- [terraform-docs](https://github.com/terraform-docs/terraform-docs): Documentation generation

## 📄 License

By contributing to Prism Platform, you agree that your contributions will be licensed under the Apache 2.0 License.

---

Thank you for contributing to Prism Platform! 🚀 