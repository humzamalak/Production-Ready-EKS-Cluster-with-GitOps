# Developer Onboarding Guide

Welcome to the Production-Ready EKS Cluster with GitOps project! This guide will help you get started, understand the workflow, and contribute effectively.

## Getting Started
1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_ORG/Production-Ready-EKS-Cluster-with-GitOps.git
   cd Production-Ready-EKS-Cluster-with-GitOps
   ```
2. **Set up AWS credentials:**
   - Run `aws configure` and enter your access keys and default region.
3. **Configure GitHub secrets:**
   - Add AWS credentials and (optionally) Infracost API key to your repo secrets.
   - See `.github/workflows/terraform-deploy.yml` for required secret names.
4. **Review the README and docs:**
   - Start with the main [README.md](../README.md) and explore the `/docs` directory.

## Local Development Workflow
- Use feature branches for all changes.
- Run `terraform plan` before opening a PR.
- Use PR templates and follow commit message guidelines.
- Ensure all code is reviewed before merging.

## Deployment Process
- All changes are deployed via GitOps and CI/CD pipelines.
- Monitor ArgoCD and GitHub Actions for deployment status.
- Use the ArgoCD UI to observe application state and troubleshoot issues.

## Support & Troubleshooting
- See [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for common issues.
- Ask questions in the team chat or open a GitHub issue.

---

For more details, see the [Knowledge Transfer Guide](knowledge-transfer.md).
