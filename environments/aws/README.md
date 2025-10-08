# AWS EKS Environment Configuration

This directory contains configuration overrides for AWS EKS production deployments.

## Usage

These configurations are used by the setup scripts to deploy the GitOps stack on AWS EKS with production-grade resources and high availability.

## Components

- **ArgoCD**: HA with 2+ replicas, LoadBalancer service
- **Prometheus**: 30-day retention, 100GB storage, HA with 2 replicas
- **Grafana**: HA with 2 replicas, ALB ingress
- **Vault**: HA with Raft storage, 3 replicas
- **Web App**: HA with 3+ replicas, pod anti-affinity

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform** for infrastructure provisioning
3. **kubectl** version 1.33+
4. **Helm** version 3.x
5. **AWS Account** with permissions for EKS, VPC, IAM

## Setup

### 1. Provision Infrastructure

```bash
cd infrastructure/terraform
terraform init
terraform plan
terraform apply
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name production-cluster --region us-east-1
```

### 3. Deploy GitOps Stack

```bash
./scripts/setup-aws.sh
```

## Access Applications

After deployment:

- ArgoCD: `https://argocd.example.com` (configure DNS and ACM certificate)
- Grafana: `https://grafana.example.com`
- Prometheus: `https://prometheus.example.com`
- Vault: `https://vault.example.com`
- Web App: `https://web-app.example.com`

## Cost Optimization

Production AWS costs (estimated monthly):
- EKS Cluster: $73/month (control plane)
- Worker Nodes (t3.medium x3): $90/month
- EBS Volumes (gp3): $30/month
- Load Balancers: $50/month
- **Total**: ~$250/month (varies by region and usage)

## High Availability

- **Multi-AZ deployment** for resilience
- **Pod anti-affinity** rules to spread replicas
- **HPA** for automatic scaling
- **Persistent volumes** with EBS gp3
- **Network policies** for security

## Monitoring & Alerting

- Prometheus collects metrics from all components
- Grafana provides visualization dashboards
- Alertmanager for alert routing
- ServiceMonitors for automatic discovery

