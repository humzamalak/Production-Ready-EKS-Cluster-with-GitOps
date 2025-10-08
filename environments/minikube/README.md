# Minikube Environment Configuration

This directory contains configuration overrides for local Minikube deployments.

## Usage

These configurations are used by the setup scripts to deploy the GitOps stack on Minikube with minimal resources suitable for local development.

## Components

- **ArgoCD**: Single replica, minimal resources
- **Prometheus**: 7-day retention, 5GB storage
- **Grafana**: Local access via ingress
- **Vault**: Dev mode with in-memory storage
- **Web App**: Single replica, HPA disabled

## Setup

Run the setup script from the repository root:

```bash
./scripts/setup-minikube.sh
```

## Access Applications

After deployment, access applications via:

- ArgoCD: `kubectl port-forward -n argocd svc/argocd-server 8080:443`
- Grafana: `http://grafana.local` (add to /etc/hosts)
- Prometheus: `kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090`
- Vault: `kubectl port-forward -n vault svc/vault 8200:8200`
- Web App: `http://web-app.local` (add to /etc/hosts)

## Resource Requirements

Minimum Minikube configuration:
- CPU: 4 cores
- Memory: 8GB RAM
- Disk: 20GB

```bash
minikube start --cpus=4 --memory=8192 --disk-size=20g
```

