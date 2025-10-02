# Documentation Index

This directory contains comprehensive documentation for the Production-Ready EKS Cluster with GitOps.

## 📚 Documentation Structure

### 🚀 **Getting Started**
- **[Main README](../README.md)** - Project overview and quick start
- **[AWS Deployment Guide](../AWS_DEPLOYMENT_GUIDE.md)** - Production deployment on AWS (6-phase approach, ~60 min)
- **[Minikube Deployment Guide](../MINIKUBE_DEPLOYMENT_GUIDE.md)** - Local development setup (6-phase approach, ~40 min)

### 🏗️ **Architecture & Structure**
- **[Project Structure Guide](PROJECT_STRUCTURE.md)** - Complete repository structure and GitOps patterns

### 🔐 **Security & Secrets**
- **[Security Best Practices](security-best-practices.md)** - Security guidelines and best practices
- **[Vault Setup Guide](VAULT_SETUP_GUIDE.md)** - Comprehensive Vault configuration
- **[Vault Integration Guide](../applications/web-app/VAULT_INTEGRATION.md)** - Web app Vault integration with progressive deployment

### 🛠️ **Operations & Maintenance**
- **[Troubleshooting Guide](../TROUBLESHOOTING.md)** - Common issues and solutions
- **[Disaster Recovery Runbook](disaster-recovery-runbook.md)** - Recovery procedures

### 📊 **Project Management**
- **[Changelog](CHANGELOG.md)** - Version history and changes

## 🎯 **Quick Navigation**

### **For New Users:**
1. Start with [Main README](../README.md)
2. Choose your platform: [AWS](../AWS_DEPLOYMENT_GUIDE.md) or [Minikube](../MINIKUBE_DEPLOYMENT_GUIDE.md)
3. Follow the phase-based deployment guide step-by-step

### **For Developers:**
1. Review [Project Structure Guide](PROJECT_STRUCTURE.md)
2. Set up local environment with [Minikube Deployment Guide](../MINIKUBE_DEPLOYMENT_GUIDE.md)
3. See optimization tips in Minikube guide's "Local Development Tips & Optimization" section

### **For Operators:**
1. Familiarize with [Security Best Practices](security-best-practices.md)
2. Review [Troubleshooting Guide](../TROUBLESHOOTING.md)
3. Understand [Disaster Recovery Runbook](disaster-recovery-runbook.md)

### **For Vault Integration:**
1. Start with [Vault Setup Guide](VAULT_SETUP_GUIDE.md)
2. Review [Vault Integration Guide](../applications/web-app/VAULT_INTEGRATION.md) (includes progressive deployment)
3. Enhanced with environment variable support and improved security practices

## 📁 **Directory-Specific Documentation**

### **Bootstrap Components**
- **[Bootstrap README](../bootstrap/README.md)** - Bootstrap configuration details

### **Application Documentation**
- **[Web App README](../applications/web-app/README.md)** - Web application stack
- **[Production Cluster README](../clusters/production/README.md)** - Production configuration

### **Example Applications**
- **[Example Web App README](../examples/web-app/README.md)** - Sample application reference

### **Infrastructure**
- **[Terraform README](../infrastructure/terraform/README.md)** - Infrastructure as Code documentation

## 🔄 **Documentation Updates**

This documentation is maintained as part of the GitOps workflow. When making changes:

1. Update relevant documentation files
2. Update the [Changelog](../CHANGELOG.md)
3. Test documentation accuracy with actual deployments
4. Keep this index updated
5. Follow YAML linting standards with `.yamllint` configuration

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
**Version**: 1.1.0 - Production-ready with enhanced security and reliability
