# Branch Protection & Required Status Checks

## Recommended Settings for `main` Branch

- Require pull request reviews before merging
- Require status checks to pass before merging
  - terraform-deploy (CI/CD)
  - secret-scan-dep-check (security)
  - terraform-pr-comment (plan output)
- Require branches to be up to date before merging
- Require signed commits (optional, for extra security)
- Restrict who can push to matching branches (e.g., admins only)
- Do not allow force pushes
- Do not allow deletions

## How to Configure
1. Go to your GitHub repository > Settings > Branches
2. Add a branch protection rule for `main`
3. Select the options above
4. Add required status checks by name (as listed above)

---

> **Tip:** Review and update these rules as your team and workflow evolve.
