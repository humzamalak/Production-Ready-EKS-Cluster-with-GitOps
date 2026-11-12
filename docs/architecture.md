# Architecture Guide

This guide describes how the repository is organised and how its parts fit together. For deployment steps, see [aws-deployment.md](aws-deployment.md) and [local-deployment.md](local-deployment.md).

## Layers

| Layer | Tool | Path |
|-------|------|------|
| AWS infrastructure | Terraform | `terraform/` |
| GitOps control plane | Argo CD | `argo-apps/` |
| Platform and application configuration | Helm values and a custom chart | `helm-charts/` |
| Operations | Bash scripts and Makefile | `scripts/`, `Makefile` |
| Checks | GitHub Actions | `.github/workflows/` |

## Repository layout

```text
.
├── argo-apps/
│   ├── install/
│   │   ├── 01-namespaces.yaml      # argocd, monitoring, production, vault namespaces with Pod Security labels
│   │   ├── 02-argocd-install.yaml  # comments only: Argo CD is installed from the upstream manifest
│   │   └── 03-bootstrap.yaml       # argocd-projects and root-app Applications
│   ├── projects/
│   │   └── prod-apps.yaml          # AppProject: allowed source repos, destinations and resource kinds
│   └── apps/
│       ├── vault.yaml              # sync wave 2
│       ├── prometheus.yaml         # sync wave 3 (kube-prometheus-stack)
│       ├── grafana.yaml            # sync wave 4
│       └── web-app.yaml            # sync wave 5
├── helm-charts/
│   ├── vault/                      # values for hashicorp/vault
│   ├── prometheus/                 # values for prometheus-community/kube-prometheus-stack
│   ├── grafana/                    # values for grafana/grafana
│   └── web-app/                    # custom chart: Deployment, Service, Ingress, HPA,
│                                   # NetworkPolicy, ServiceMonitor, Vault Agent annotations
├── terraform/
│   ├── environments/aws/           # root module: providers, S3 backend, module wiring, outputs
│   └── modules/
│       ├── vpc/                    # VPC, subnets, NAT gateways, security groups, flow logs
│       ├── eks/                    # EKS cluster, node group, add-ons, Cluster Autoscaler, KMS
│       └── iam/                    # IRSA roles, GitHub Actions OIDC role, Vault KMS key and role
├── scripts/                        # setup-aws.sh, setup-minikube.sh, deploy.sh, validate.sh, vault-init.sh, ...
└── docs/                           # guides; docs/history holds earlier audit reports
```

Each directory under `helm-charts/` has three value files:

- `values.yaml`: shared defaults
- `values-aws.yaml`: EKS overrides (`gp3` storage, ALB ingress, HA Vault)
- `values-minikube.yaml`: local overrides (`standard` storage, single replicas)

## AWS infrastructure

Terraform runs from `terraform/environments/aws` and calls three modules.

- **vpc**: one VPC across three Availability Zones, with three public and three private subnets, one NAT gateway per zone, and security groups for the cluster, nodes, load balancer and data tiers. VPC flow logs go to CloudWatch Logs, encrypted with a KMS key.
- **eks**: the cluster has a private API endpoint only, envelope encryption of Kubernetes secrets with KMS, and all control plane log types enabled. A managed node group runs 2 to 10 nodes. Add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI driver and Pod Identity Agent. Cluster Autoscaler is installed with the Helm provider.
- **iam**: IRSA roles for the EBS CSI driver, AWS Load Balancer Controller, Fluent Bit and Vault, an OIDC role for GitHub Actions, and the KMS key that Vault uses to auto-unseal.

State is stored in S3 with DynamoDB locking. The backend block is empty, so you supply the values at `terraform init`.

The EKS API endpoint is private. Run `kubectl`, `helm` and `terraform apply` from a host that can reach the VPC.

## GitOps flow

1. `kubectl apply -f argo-apps/install/01-namespaces.yaml` creates the namespaces.
2. Argo CD is installed from the upstream v3.1.0 manifest into `argocd`.
3. `kubectl apply -f argo-apps/install/03-bootstrap.yaml` creates two Applications:
   - `argocd-projects` (wave 1) syncs `argo-apps/projects/`.
   - `root-app` (wave 2) syncs `argo-apps/apps/`. This is the app-of-apps.
4. `root-app` creates the child Applications. Argo CD syncs them in sync-wave order: Vault, Prometheus, Grafana, then the web app.

All Applications use automated sync with `prune` and `selfHeal`, so Argo CD corrects drift from Git.

The Vault, Prometheus and Grafana Applications use multiple sources: the chart comes from the upstream Helm repository and the value files come from this repository through a `$values` reference.

### Selecting an environment

Each Application in `argo-apps/apps/` lists its value files. The environment file is chosen by editing that list:

- Vault uses `values-minikube.yaml` by default.
- Prometheus, Grafana and the web app use only `values.yaml` by default.

For EKS, change the lists to use `values-aws.yaml`, and set the Vault service account annotation to the `vault_server_role_arn` Terraform output.

## Security controls in the code

| Control | Where |
|---------|-------|
| Private EKS API endpoint | `terraform/modules/eks/main.tf` |
| KMS encryption of Kubernetes secrets | `terraform/modules/eks/main.tf` |
| Encrypted VPC flow logs | `terraform/modules/vpc/main.tf` |
| IRSA roles scoped to one service account each | `terraform/modules/iam/` |
| Vault auto-unseal with a dedicated KMS key | `terraform/modules/iam/vault_kms.tf`, `helm-charts/vault/values-aws.yaml` |
| Pod Security Standards (`restricted` for `production`, `baseline` elsewhere) | `argo-apps/install/01-namespaces.yaml` |
| AppProject limits on sources, destinations and resource kinds | `argo-apps/projects/prod-apps.yaml` |
| NetworkPolicy for the web app | `helm-charts/web-app/templates/networkpolicy.yaml` |

## Monitoring

kube-prometheus-stack runs Prometheus, Alertmanager and the Prometheus Operator in the `monitoring` namespace. The web-app chart can create a ServiceMonitor (`serviceMonitor.enabled`). Grafana runs as a separate Application and uses Prometheus as its data source.

## Adding an application

1. Add values under `helm-charts/<name>/`, or a chart if there is no upstream chart.
2. Add `argo-apps/apps/<name>.yaml` with `project: prod-apps` and a sync wave.
3. If the application needs a new namespace or source repository, add it to `argo-apps/install/01-namespaces.yaml` and `argo-apps/projects/prod-apps.yaml`.
4. Commit and push. `root-app` picks up the new file.
