# Security Best Practices

This guide outlines essential security practices for operating a production-grade EKS cluster with GitOps.

## Authentication & Access
- Use OIDC for GitHub Actions authentication (never use static AWS keys in CI/CD).
- Apply Pod Security Standards and Kubernetes Network Policies.
- Use IRSA (IAM Roles for Service Accounts) for fine-grained permissions.

## Secrets Management
- Store secrets in AWS Secrets Manager.
- Sync secrets to Kubernetes using the external-secrets operator.
- Never commit secrets to version control.

## Image & Code Security
- Scan container images and Infrastructure as Code (IaC) for vulnerabilities (Trivy, Checkov).
- Enable branch protection and required status checks in GitHub.
- Use dependency scanning tools to detect vulnerable packages.

## Monitoring & Auditing
- Enable CloudTrail and VPC Flow Logs for auditing.
- Regularly review IAM roles and policies for least-privilege.

---

For more details, see the [Monitoring & Alerting Guide](monitoring-alerting.md).
