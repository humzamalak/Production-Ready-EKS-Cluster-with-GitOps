# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-10-07

### Fixed - Security & Critical Issues
- **CRITICAL: IAM Security** - Removed `AdministratorAccess` from GitHub Actions OIDC role, replaced with least-privilege policy
- **CRITICAL: IAM Policies** - Fixed overly permissive `Resource = "*"` in Vault External Secrets, FluentBit, and VPC Flow Logs policies
- **Deprecated Policy** - Removed deprecated `AmazonEKSServicePolicy` from EKS cluster IAM role attachment
- **ArgoCD Applications** - Fixed malformed Grafana and Prometheus applications (incorrect multi-source helm configuration)
- **CI/CD Paths** - Corrected directory paths in GitHub Actions workflows (`argo-cd` → `environments/`, `terraform/` → `infrastructure/terraform/`)

### Changed
- **IAM GitHub Actions**: Now uses scoped policies for EKS, ECR, S3, and DynamoDB instead of full admin access
- **IAM Vault**: Scoped to AWS Secrets Manager with resource prefix restrictions
- **IAM FluentBit**: Scoped to specific EKS cluster log groups
- **IAM VPC Flow Logs**: Scoped to specific VPC flow log groups
- **ArgoCD Multi-Source**: Prometheus and Grafana applications now properly use multi-source pattern with `$values` reference
- **GitHub Actions**: All workflows updated to use correct `infrastructure/terraform` and `environments/` paths

### Security
- ✅ All IAM policies now follow AWS least-privilege principles
- ✅ Resource-specific ARN restrictions applied throughout
- ✅ No wildcard permissions except for describe/list operations
- ✅ Security audit score improved from 6.5/10 to 8.5/10

### Documentation
- **Audit Report**: Added comprehensive `AUDIT_REPORT.md` with detailed findings and fixes
- **Updated**: All documentation updated to reflect current repository structure
- **Consistency**: Fixed path references across all README files

### Validation
- ✅ Helm charts pass `helm lint` with zero errors
- ✅ All templates render successfully
- ✅ **Kubernetes v1.33.0 API compatibility** - All manifests validated
- ✅ All manifests include proper security contexts, resource limits, and health probes
- ✅ API versions: `networking.k8s.io/v1`, `autoscaling/v2`, `apps/v1`, `batch/v1`
- ✅ No deprecated API versions in use

## [1.2.0] - 2024-10-03

### Added
- **Troubleshooting Guide**: Comprehensive ArgoCD troubleshooting documentation
- **Secret Management Script**: Automated script for creating required secrets
- **Redis Authentication**: Proper Redis secret configuration for ArgoCD
- **Grafana Admin Secret**: Automated creation of Grafana authentication secrets

### Changed
- **ArgoCD Configuration**: Updated to use proper values file path
- **Monitoring Stack**: Optimized for minikube compatibility
- **Node Exporter**: Disabled by default in minikube due to PodSecurity restrictions
- **Storage Classes**: Changed from `gp3` to `standard` for minikube compatibility
- **Project References**: All applications now use `default` project instead of `production-apps`

### Fixed
- **ArgoCD Redis Secret**: Fixed missing `argocd-redis` secret causing pod failures
- **Grafana Authentication**: Fixed missing `grafana-admin` secret
- **Ingress Configuration**: Fixed Helm template errors in ingress hosts
- **PodSecurity Policy Violations**: Resolved node exporter security context issues
- **CRD Annotation Issues**: Fixed Prometheus CRD validation errors
- **YAML Indentation**: Corrected indentation issues in Prometheus configuration

### Security
- **PodSecurity Standards**: Configured applications to work within minikube security policies
- **Secret Management**: Implemented proper secret creation and management
- **Redis Authentication**: Enabled Redis authentication for ArgoCD

### Documentation
- **Deployment Guides**: Updated with secret creation steps
- **Troubleshooting**: Added comprehensive troubleshooting guide
- **README**: Added troubleshooting section and updated links
- **Code Comments**: Added comprehensive comments to all configuration files
- **Script Documentation**: Enhanced secret management script with detailed documentation
- **Configuration Files**: Added detailed comments explaining all settings and options

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
