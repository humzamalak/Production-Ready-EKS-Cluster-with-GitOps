# Troubleshooting Guide

This guide covers common issues and their solutions when deploying and managing the Production-Ready EKS Cluster with GitOps.

## 🚨 Deployment Issues

### 1. Deploy Script Fails

#### Prerequisites Not Met
```bash
# Check if all required tools are installed
./deploy.sh --validate-only

# Install missing tools
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Terraform
sudo apt update && sudo apt install terraform
```

#### AWS Credentials Issues
```bash
# Check AWS credentials
aws sts get-caller-identity

# Configure credentials if needed
aws configure

# Check IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name <username>
```

#### Terraform Backend Issues
```bash
# Create backend resources only
./deploy.sh --create-backend-only

# Check if backend resources exist
aws s3api head-bucket --bucket <bucket-name> --region <region>
aws dynamodb describe-table --table-name <table-name> --region <region>

# Initialize Terraform manually if needed
cd terraform
terraform init -reconfigure
```

#### Terraform Vim/Editor Issues
```bash
# If Vim opens during terraform apply/destroy, use auto-approve
./scripts/deploy.sh -y

# Or for manual Terraform commands
terraform apply -auto-approve
terraform destroy -auto-approve

# If already in Vim:
# To approve: type :wq and press Enter
# To cancel: type :q! and press Enter
```

### 2. EKS Cluster Issues

#### Cluster Creation Fails
```bash
# Check CloudFormation stacks for errors
aws cloudformation list-stacks --region <region>
aws cloudformation describe-stack-events --stack-name <stack-name> --region <region>

# Check EKS cluster status
aws eks describe-cluster --name <cluster-name> --region <region>

# Check node group status
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name> --region <region>
```

#### kubectl Access Issues
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Check cluster endpoint
kubectl cluster-info

# Check node status
kubectl get nodes

# Check if nodes are ready
kubectl describe nodes
```

### 3. ArgoCD Issues

#### ArgoCD Installation Fails
```bash
# Check Helm repositories
helm repo list
helm repo update

# Check ArgoCD namespace
kubectl get namespace argocd

# Check ArgoCD pods
kubectl get pods -n argocd

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Reinstall ArgoCD if needed
helm uninstall argocd -n argocd
kubectl delete namespace argocd
./deploy.sh --skip-infra
```

#### ArgoCD Applications Not Syncing
```bash
# Check application status
kubectl get applications -n argocd

# Describe specific application
kubectl describe application <app-name> -n argocd

# Check ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync application
kubectl patch application <app-name> -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

### 4. Monitoring Stack Issues

#### Prometheus Not Starting
```bash
# Check Prometheus pods
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus

# Check PVC status
kubectl get pvc -n monitoring

# Check storage class
kubectl get storageclass

# Restart Prometheus if needed
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
```

#### Grafana Access Issues
```bash
# Check Grafana pod status
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Check Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Grafana admin secret
kubectl get secret grafana-admin -n monitoring -o yaml

# Get Grafana password
kubectl get secret grafana-admin -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Port-forward to access Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
```

## 🧹 Teardown Issues

### 1. Infrastructure Teardown Issues

#### Kubernetes Resources Won't Delete
```bash
# Manual cleanup of stuck namespaces
kubectl get namespace
kubectl delete namespace <namespace> --force --grace-period=0

# Remove finalizers from stuck resources
kubectl patch namespace <namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

#### Terraform Destroy Fails
```bash
# Force destroy without confirmation
cd terraform
terraform destroy -var-file="terraform.tfvars" -auto-approve

# Check Terraform state
terraform show

# Destroy specific resources
terraform destroy -target=<resource> -var-file="terraform.tfvars"

# Import resources if state is out of sync
terraform import <resource_type>.<resource_name> <resource_id>
```

#### EKS Cluster Won't Delete
```bash
# Check cluster dependencies
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'

# Delete load balancers manually
aws elbv2 delete-load-balancer --load-balancer-arn <lb-arn>

# Check security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>"

# Force delete cluster
aws eks delete-cluster --name <cluster-name>
```

### 2. Stuck Resources

#### Load Balancers
```bash
# List load balancers in VPC
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'

# Delete load balancers
aws elbv2 delete-load-balancer --load-balancer-arn <lb-arn>

# Delete target groups
aws elbv2 describe-target-groups --query 'TargetGroups[?VpcId==`<vpc-id>`]'
aws elbv2 delete-target-group --target-group-arn <tg-arn>
```

#### Security Groups
```bash
# List security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>"

# Delete security group rules first
aws ec2 revoke-security-group-ingress --group-id <sg-id> --protocol all
aws ec2 revoke-security-group-egress --group-id <sg-id> --protocol all

# Delete security group
aws ec2 delete-security-group --group-id <sg-id>
```

#### Persistent Volumes
```bash
# List PVs and PVCs
kubectl get pv
kubectl get pvc -A

# Delete PVCs
kubectl delete pvc --all -n <namespace>

# Delete PVs
kubectl delete pv <pv-name>

# Check EBS volumes
aws ec2 describe-volumes --filters "Name=tag:kubernetes.io/cluster/<cluster-name>,Values=owned"
```

## 🔧 Diagnostic Commands

### Cluster Health
```bash
# Check cluster status
kubectl cluster-info
kubectl get nodes
kubectl get pods -A

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### ArgoCD Diagnostics
```bash
# Check ArgoCD status
kubectl get applications -n argocd
kubectl get pods -n argocd

# ArgoCD CLI commands
argocd app list
argocd app sync <app-name>
argocd app get <app-name>

# Check ArgoCD configuration
kubectl get configmap argocd-cm -n argocd -o yaml
```

### Monitoring Diagnostics
```bash
# Check monitoring stack
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Check Prometheus targets
kubectl port-forward svc/prometheus-server -n monitoring 9090:9090
# Visit http://localhost:9090/targets

# Check Grafana datasources
kubectl port-forward svc/grafana -n monitoring 3000:80
# Visit http://localhost:3000
```

### AWS Resources
```bash
# Check EKS cluster
aws eks describe-cluster --name <cluster-name> --region <region>

# Check VPC resources
aws ec2 describe-vpcs --vpc-ids <vpc-id>
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"

# Check IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `<project-prefix>`)]'

# Check load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[?VpcId==`<vpc-id>`]'
```

## 📞 Getting Help

### Log Files
- Deployment logs: `deployment.log`
- Teardown logs: `teardown.log`
- Terraform logs: Set `TF_LOG=DEBUG` for detailed logs

### Useful Resources
- [AWS EKS Troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)

### Emergency Cleanup
If all else fails, manually clean up resources through the AWS Console:
1. Delete EKS cluster
2. Delete VPC and associated resources
3. Delete IAM roles and policies
4. Delete S3 buckets and DynamoDB tables
5. Delete CloudWatch log groups
6. Delete KMS keys
