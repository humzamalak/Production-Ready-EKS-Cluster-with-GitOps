#!/bin/bash

# Create Monitoring Secrets Script
# This script creates the required secrets for the monitoring stack

set -e

echo "Creating monitoring secrets..."

# Create Grafana admin secret
echo "Creating Grafana admin secret..."
kubectl create secret generic grafana-admin \
  --namespace=monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=$(openssl rand -base64 16) \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ArgoCD Redis secret if it doesn't exist
echo "Checking for ArgoCD Redis secret..."
if ! kubectl get secret argocd-redis -n argocd >/dev/null 2>&1; then
  echo "Creating ArgoCD Redis secret..."
  kubectl create secret generic argocd-redis \
    --namespace=argocd \
    --from-literal=auth=$(openssl rand -base64 32) \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "ArgoCD Redis secret already exists"
fi

echo "Monitoring secrets created successfully!"
echo ""
echo "Grafana credentials:"
echo "Username: admin"
echo "Password: $(kubectl get secret grafana-admin -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d)"
echo ""
echo "ArgoCD admin password:"
echo "$(kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.admin\.password}' | base64 -d)"
