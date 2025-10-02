# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2024-01-15

### Added
- Comprehensive YAML linting and formatting fixes
- Production-ready ArgoCD Helm chart configuration
- Enhanced security configurations for all components
- Improved Vault initialization with environment variable support
- Better Helm chart metadata and documentation

### Changed
- **BREAKING**: Updated Kubernetes version from 1.33 to 1.31 (1.33 doesn't exist)
- Improved ArgoCD installation to use official Helm chart instead of raw YAML
- Enhanced Vault initialization job with proper environment variable handling
- Updated Chart.yaml with proper maintainer information and icon
- Fixed all YAML indentation and formatting issues
- Removed duplicate keys in Prometheus values files

### Fixed
- Fixed trailing spaces in all YAML files
- Fixed missing newlines at end of files
- Fixed incorrect indentation in multiple YAML files
- Fixed duplicate keys in `applications/monitoring/prometheus/values-local.yaml`
- Fixed Helm template syntax issues
- Fixed hardcoded secrets in Vault initialization
- Fixed Terraform version compatibility issues

### Security
- Enhanced security contexts across all deployments
- Improved RBAC configurations
- Added proper Pod Security Standards labels
- Enhanced network policies
- Improved secret management practices
- Added proper resource limits and requests

### Infrastructure
- Updated Terraform Kubernetes version to supported version (1.31)
- Enhanced ArgoCD configuration with proper Helm values
- Improved monitoring and observability configurations
- Better resource allocation and limits

## [1.0.0] - 2024-01-01

### Added
- Initial GitOps repository structure
- EKS cluster configuration with Terraform
- ArgoCD setup and configuration
- Vault integration for secrets management
- Monitoring stack with Prometheus and Grafana
- Web application deployment with Helm
- Comprehensive documentation

### Infrastructure Components
- VPC module with public/private subnets
- EKS cluster with managed node groups
- IAM roles and policies for service accounts
- Backup configuration for EBS volumes
- Network policies and security groups

### Applications
- Production-ready web application
- Monitoring and observability stack
- Secrets management with Vault
- CI/CD pipeline configurations

---

## Migration Notes

### From 1.0.0 to 1.1.0

1. **Kubernetes Version Update**: If you're using the Terraform configuration, update your `terraform.tfvars` to use Kubernetes version 1.31 instead of 1.33.

2. **ArgoCD Installation**: The ArgoCD installation method has been updated to use the official Helm chart. This provides better production practices and easier configuration management.

3. **Vault Configuration**: The Vault initialization now uses environment variables instead of hardcoded values. Update your deployment to provide these environment variables securely.

4. **YAML Formatting**: All YAML files have been reformatted to follow proper indentation and remove trailing spaces. This improves readability and prevents linting errors.

## Contributing

When making changes to this repository, please ensure:

1. All YAML files follow proper formatting (no trailing spaces, correct indentation)
2. Helm charts are properly validated using `helm lint`
3. Terraform configurations are validated using `terraform validate`
4. Security best practices are followed
5. Documentation is updated accordingly
6. Changes are tested in a staging environment before production deployment

## Support

For questions or issues, please:
1. Check the documentation in the `docs/` directory
2. Review the deployment guides
3. Create an issue in the repository
4. Contact the DevOps team
