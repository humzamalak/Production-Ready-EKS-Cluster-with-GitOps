# Security Best Practices

This guide outlines essential security practices for operating a production-grade EKS cluster with GitOps.

## Authentication & Access
- Use OIDC for GitHub Actions authentication (never use static AWS keys in CI/CD).
- Apply Pod Security Standards and Kubernetes Network Policies.
- Use IRSA (IAM Roles for Service Accounts) for fine-grained permissions.

## Secrets Management
- Store secrets in HashiCorp Vault with KV v2 secret engine.
- Sync secrets to Kubernetes using the external-secrets operator (see `argo-cd/apps/grafana-admin-secret.yaml`).
- Never commit secrets to version control. Only commit references to secret keys and properties.
- Use Vault policies for fine-grained access control and audit logging.
- Implement Vault unsealing with multiple key shares for high availability.

## Image & Code Security
- Scan container images and Infrastructure as Code (IaC) for vulnerabilities (Trivy, Checkov).
- Enable branch protection and required status checks in GitHub.
- Use dependency scanning tools to detect vulnerable packages.

## Monitoring & Auditing
- Enable CloudTrail and VPC Flow Logs for auditing.
- Regularly review IAM roles and policies for least-privilege.

---

For more details, see the [Monitoring & Alerting Guide](monitoring-alerting.md).
