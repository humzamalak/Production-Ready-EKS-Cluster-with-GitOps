# Environment Promotion Guide

This guide explains how to promote changes from staging to production in your EKS GitOps workflow.

## Promoting Changes
- Use Pull Requests (PRs) to promote changes from staging to production.
- Update environment-specific app-of-apps manifests to reflect the new state.
- Monitor ArgoCD and CI/CD pipelines for successful promotion and deployment.

## Best Practices
- Require code review and approval before promotion.
- Use separate branches for each environment.
- Document all promotion steps and outcomes.

## Troubleshooting
- Check ArgoCD UI and logs for sync issues.
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help.
