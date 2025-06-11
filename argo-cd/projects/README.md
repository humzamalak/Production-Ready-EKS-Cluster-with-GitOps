# ArgoCD Projects Directory

This directory contains ArgoCD Project manifests, which are used to logically group and manage related applications within your EKS cluster.

## Purpose
- Define boundaries and policies for groups of applications
- Control access, sync windows, and resource quotas at the project level
- Enable multi-tenancy and environment separation

## Structure
- `*.yaml`: ArgoCD Project manifests (one per project or environment)
- `README.md`: This documentation file

## Usage
1. **Create a new project manifest:**
   - Define project name, description, and allowed namespaces
   - Set up sync windows, quotas, and RBAC as needed
2. **Apply the project manifest:**
   ```bash
   kubectl apply -f my-project.yaml
   ```
3. **Reference the project** in your ArgoCD Application manifests

## Best Practices
- Use projects to enforce security and operational boundaries
- Document project policies and intended usage
- Regularly review and update project configurations

## Troubleshooting
- Check ArgoCD UI for project errors or policy violations
- Review project manifest syntax and required fields
- See the main [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md) for more help
