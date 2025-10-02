# Security Best Practices

This guide outlines essential security practices for operating a production-grade EKS cluster with GitOps.

## Authentication & Access
- Use OIDC for GitHub Actions authentication (never use static AWS keys in CI/CD).
- Apply Pod Security Standards and Kubernetes Network Policies.
- Use IRSA (IAM Roles for Service Accounts) for fine-grained permissions.

## Secrets Management
- Store secrets in HashiCorp Vault with KV v2 secret engine.
- Inject secrets at runtime using Vault Agent Injector (avoid Kubernetes Secret objects).
- Never commit secrets to version control. Only commit references to secret keys and properties.
- Use environment variables for Vault initialization to avoid hardcoded secrets.
- Use Vault policies for fine-grained access control and audit logging.
- Implement Vault unsealing with multiple key shares for high availability.
- Enhanced Vault initialization with proper RBAC and service account configurations.

## Image & Code Security
- Scan container images and Infrastructure as Code (IaC) for vulnerabilities (Trivy, Checkov).
- Enable branch protection and required status checks in GitHub.
- Use dependency scanning tools to detect vulnerable packages.
- Implement proper YAML linting and validation using `.yamllint` configuration.

## Infrastructure Security
- Use supported Kubernetes versions (currently 1.31+).
- Implement proper Terraform module structure and validation.
- Use official Helm charts for production deployments.
- Configure proper resource limits and security contexts.

## Monitoring & Auditing
- Enable CloudTrail and VPC Flow Logs for auditing.
- Regularly review IAM roles and policies for least-privilege.
- Implement comprehensive logging and monitoring with Prometheus and Grafana.

## GitOps Security
- Use proper ArgoCD project configurations with RBAC.
- Implement secure ArgoCD installation using official Helm charts.
- Configure proper sync policies and automated reconciliation.
- Use finalizers and proper resource cleanup.

---

For more details, see the [Vault Setup Guide](VAULT_SETUP_GUIDE.md) and [Project Structure Guide](PROJECT_STRUCTURE.md).
