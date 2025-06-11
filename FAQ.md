# FAQ

**Q: How do I add a new application to ArgoCD?**
A: Add a new Application manifest in `argo-cd/apps/` and reference it in the root app or environment app-of-apps.

**Q: How do I rotate AWS credentials?**
A: Use OIDC for GitHub Actions. Rotate IAM roles and policies as needed.

**Q: How do I restore from backup?**
A: See the disaster recovery runbook in `argo-cd/bootstrap/disaster-recovery-runbook.md`.
