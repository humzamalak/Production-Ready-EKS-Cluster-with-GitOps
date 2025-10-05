<!-- Docs Update: 2025-10-05 — Verified links, clarified navigation and environment locations. -->
# Documentation Index

This directory contains comprehensive, consolidated documentation for the Production-Ready EKS Cluster with GitOps.

## 📚 Documentation Structure

### 🚀 **Getting Started**
- **[Main README](../README.md)** - Project overview and quick start
- **[AWS Deployment Guide](aws-deployment.md)** - Complete production deployment on AWS EKS
- **[Local Deployment Guide](local-deployment.md)** - Complete local development setup with Minikube

### 🏗️ **Architecture & Structure**
- **[Architecture Guide](architecture.md)** - Complete repository structure, GitOps patterns, and implementation flow

### 🛠️ **Operations & Maintenance**
- **[Troubleshooting Guide](troubleshooting.md)** - Comprehensive troubleshooting including ArgoCD, Kubernetes, Vault, and validation issues

## 🎯 **Quick Navigation**

### **For New Users:**
1. Start with [Main README](../README.md)
2. Choose your platform: [AWS](aws-deployment.md) or [Local](local-deployment.md)
3. Follow the phase-based deployment guide step-by-step

### **For Developers:**
1. Review [Architecture Guide](architecture.md)
2. Set up local environment with [Local Deployment Guide](local-deployment.md)
3. Use [Troubleshooting Guide](troubleshooting.md) for common issues

### **For Operators:**
1. Follow [AWS Deployment Guide](aws-deployment.md) for production
2. Use [Troubleshooting Guide](troubleshooting.md) for operational issues
3. Review [Architecture Guide](architecture.md) for system understanding

## 📁 **Directory-Specific Documentation**

### **Bootstrap Components**
- **[Bootstrap README](../bootstrap/README.md)** - Bootstrap configuration details (Argo CD install, security, repos)

### **Environment & Applications**
- **[Production Environment README](../clusters/production/README.md)** - Production environment overview
- Environment apps live under `environments/<env>/apps/*.yaml` and reference sources in `applications/`

### **Example Applications**
- **[Example Web App README](../examples/web-app/README.md)** - Sample application reference

### **Infrastructure**
- **[Terraform README](../infrastructure/terraform/README.md)** - Infrastructure as Code documentation

## 🔄 **Documentation Updates**

This documentation is maintained as part of the GitOps workflow. When making changes:

1. Update relevant documentation files
2. Test documentation accuracy with actual deployments
3. Keep this index updated
4. Follow consistent formatting and structure

## 📝 **Contributing to Documentation**

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