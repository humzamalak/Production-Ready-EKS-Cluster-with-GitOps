# Documentation Index

> **Primary target**: AWS EKS. Minikube is the local option.  
> **Compatibility**: Kubernetes v1.33.0

This directory contains comprehensive documentation for deploying and managing a GitOps stack with ArgoCD, Vault, and observability.

## Documentation Structure

### **Getting Started** (Start Here)
- **[Main README](../README.md)** - Project overview and quick start
- **[Local Deployment Guide](local-deployment.md)** - ⭐ **START HERE** - Complete Minikube setup (~30 min)
- **[Vault Local Setup](vault-local-setup.md)** - Single-replica Vault with manual unseal

### **Architecture & Troubleshooting**
- **[Architecture Guide](architecture.md)** - Repository structure and GitOps patterns
- **[Troubleshooting Guide](troubleshooting.md)** - Common issues: Vault PVC, permissions, unsealing, Argo CD sync

### **Advanced: Production Deployment** (Optional)
- **[AWS Deployment Guide](aws-deployment.md)** - Production EKS deployment (~60 min)
- **[Vault AWS Setup](vault-setup.md)** - HA Vault with Raft and KMS auto-unseal

### **Additional Resources**
- **[ArgoCD CLI Setup](argocd-cli-setup.md)** - Cross-platform CLI access
- **[K8s Version Policy](K8S_VERSION_POLICY.md)** - Kubernetes compatibility
- **[CI/CD Pipeline](ci_cd_pipeline.md)** - GitHub Actions workflows
- **[Scripts Documentation](scripts.md)** - Deployment script usage
- **[Changelog](../CHANGELOG.md)** - Version history

## **Quick Navigation**

### **For New Users:**
1. Start with [Main README](../README.md) - understand what's included
2. Follow [Local Deployment Guide](local-deployment.md) - get Minikube running (~30 min)
3. Learn [Vault Local Setup](vault-local-setup.md) - understand manual unsealing
4. Use [Troubleshooting Guide](troubleshooting.md) when issues arise

### **For Developers:**
1. Review [Architecture Guide](architecture.md) - understand GitOps structure
2. Deploy locally with [Local Deployment Guide](local-deployment.md)
3. Reference [Vault Local Setup](vault-local-setup.md) for daily unseal workflow
4. Keep [Troubleshooting Guide](troubleshooting.md) handy

### **For Production Deployment:**
1. Complete local deployment first (gain familiarity)
2. Review [AWS Deployment Guide](aws-deployment.md) - production setup
3. Configure [Vault AWS Setup](vault-setup.md) - HA with KMS
4. Set up CI/CD with [CI/CD Pipeline Guide](ci_cd_pipeline.md)

## **Recommended Reading Order**

**Complete Beginner:**
```
1. Main README → Overview
2. Local Deployment Guide → Hands-on setup
3. Vault Local Setup → Understand unsealing
4. Troubleshooting Guide → Fix common issues
```

**Ready for Production:**
```
1. Architecture Guide → Understand structure
2. AWS Deployment Guide → Production setup
3. Vault AWS Setup → HA configuration
4. CI/CD Pipeline → Automation
```

## **Directory-Specific Documentation**

- **[Terraform modules](../terraform/modules/README.md)** - VPC, EKS and IAM modules
- **[VPC module](../terraform/modules/vpc/README.md)**, **[EKS module](../terraform/modules/eks/README.md)**, **[IAM module](../terraform/modules/iam/README.md)**
- Argo CD Applications live in `argo-apps/apps/*.yaml`; Helm values live in `helm-charts/<app>/`. See the [Architecture Guide](architecture.md).
- **[History](history/)** - Earlier audit and upgrade reports

## **Documentation Updates**

This documentation is maintained as part of the GitOps workflow. When making changes:

1. Update relevant documentation files
2. Test documentation accuracy with actual deployments
3. Keep this index updated
4. Follow consistent formatting and structure

## **Contributing to Documentation**

When adding new documentation:

1. Place files in the appropriate directory
2. Update this index
3. Follow the existing documentation style
4. Include practical examples and commands
5. Test all commands and procedures

---

**Last Updated**: 2024-01-15  
**Maintainer**: GitOps Team  
**Version**: 1.1.0 - Production-ready with comprehensive documentation
