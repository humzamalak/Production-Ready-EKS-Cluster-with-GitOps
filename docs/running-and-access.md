# Running and Accessing the Production-Ready EKS Cluster

This guide explains how to run this application, what you need to get started, available configuration options, and how to access all major components of the platform.

---

## 1. Prerequisites

- **AWS Account** with permissions to create EKS, VPC, IAM, and related resources (see `terraform/README.md` for minimal IAM policy)
- **Installed Tools:**
  - [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
  - [kubectl](https://kubernetes.io/docs/tasks/tools/)
  - [Helm](https://helm.sh/docs/intro/install/)
  - [Terraform](https://developer.hashicorp.com/terraform/downloads) (>=1.4.0)
- **GitHub Repository** with secrets configured for CI/CD (see `.github/workflows/terraform-deploy.yml`)
- (Optional) **Infracost API key** for cost estimation

---

## 2. Running the Application

### Step 1: Clone the Repository
```bash
git clone https://github.com/YOUR_ORG/Production-Ready-EKS-Cluster-with-GitOps.git
cd Production-Ready-EKS-Cluster-with-GitOps
```

### Step 2: Configure AWS Credentials
```bash
aws configure
# Set region (e.g., eu-west-1)
```

### Step 3: (Optional) Configure CI/CD
- If using a CI/CD system, add required cloud credentials and (optionally) Infracost API key to your pipeline secrets.
- This repository does not include CI/CD files by default.

### Step 4: Provision Infrastructure with Terraform
```bash
cd terraform
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

### Step 5: Deploy ArgoCD and Bootstrap Applications
- Apply manifests in `argo-cd/bootstrap/`:
  ```bash
  kubectl apply -f argo-cd/bootstrap/argo-cd-install.yaml
  # Or use Helm:
  helm upgrade --install argocd argo/argo-cd -n argocd -f argo-cd/bootstrap/values.yaml
  ```
- Access ArgoCD UI (see below)
- Sync the root app (`argo-cd/apps/root-app.yaml`) to deploy all workloads

---

## 3. Configuration Options

Most configuration is managed via Helm values in `argo-cd/bootstrap/values.yaml`. Key options include:

- **High Availability:**
  - `server.replicas`, `controller.replicas`, `repoServer.replicas`, `applicationSet.replicas`
- **Resource Limits:**
  - `server.resources`, `controller.resources`, etc.
- **RBAC & Security:**
  - `rbac.policy`, `rbac.policy.csv`, `admin.enabled`, `securityContext`
- **Ingress & TLS:**
  - `ingress.enabled`, `ingress.hosts`, `ingress.tls`
- **SSO/OIDC:**
  - `sso.enabled`, `sso.provider`, `sso.oidc.*`
- **Admin User:**
  - `admin.enabled`, `admin.passwordSecret`

> **Tip:** For production, always use secure secrets and enable SSO/OIDC for authentication.

See [`values.yaml`](../argo-cd/bootstrap/values.yaml) and [`argocd-configuration.md`](./argocd-configuration.md) for full details.

---

## 4. Accessing Components

### ArgoCD UI
- **Default:** Port-forward the ArgoCD server:
  ```bash
  kubectl port-forward svc/argocd-server -n argocd 8080:443
  # Then visit https://localhost:8080
  ```
- **With Ingress:** If enabled, access via `https://argocd.example.com` (set in `values.yaml`)
- **Login:**
  - Username: `admin`
  - Password: See the `argocd-initial-admin-secret` in the `argocd` namespace:
    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
    ```

### Grafana & Prometheus
- **Grafana:**
  - Port-forward:
    ```bash
    kubectl port-forward svc/grafana -n monitoring 3000:80
    # Visit http://localhost:3000
    ```
  - Credentials: Use the `grafana-admin` secret in `monitoring` (managed by external-secrets referencing AWS Secrets Manager)
- **Prometheus:**
  - Port-forward:
    ```bash
    kubectl port-forward svc/prometheus-server -n monitoring 9090:9090
    # Visit http://localhost:9090
    ```

### AlertManager
- Port-forward:
  ```bash
  kubectl port-forward svc/alertmanager -n monitoring 9093:9093
  # Visit http://localhost:9093
  ```

### EKS Cluster
- Use `kubectl` with your configured AWS credentials:
  ```bash
  aws eks update-kubeconfig --region <region> --name <cluster_name>
  kubectl get nodes
  ```

---

## 5. Additional Resources

- [Onboarding Guide](./onboarding.md)
- [ArgoCD Configuration](./argocd-configuration.md)
- [Application Deployment](./application-deployment.md)
- [Monitoring & Alerting](./monitoring-alerting.md)
- [Security Best Practices](./security-best-practices.md)
- [TROUBLESHOOTING.md](../TROUBLESHOOTING.md)

---

For further help, see the full documentation in the `docs/` directory or open an issue in your repository.
