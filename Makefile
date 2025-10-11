# Makefile for Production-Ready EKS Cluster with GitOps
# ============================================================================
# Provides convenience targets for Terraform, ArgoCD, and validation workflows
# Updated for new directory structure (multi-cloud ready)
# ============================================================================

.PHONY: help init plan apply destroy lint fmt validate-all

# Default target shows help
.DEFAULT_GOAL := help

## help: Show this help message
help: ## Show this help message
	@echo 'Usage:'
	@echo '  make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ============================================================================
# Terraform Targets
# ============================================================================

## init: Initialize Terraform
init:
	cd terraform/environments/aws && terraform init

## plan: Show Terraform plan
plan:
	cd terraform/environments/aws && terraform plan

## apply: Apply Terraform changes
apply:
	cd terraform/environments/aws && terraform apply

## destroy: Destroy Terraform-managed infrastructure
destroy:
	cd terraform/environments/aws && terraform destroy

## fmt: Auto-format Terraform code
fmt:
	cd terraform && terraform fmt -recursive

## lint: Lint and validate Terraform code
lint:
	cd terraform && terraform fmt -check -recursive
	cd terraform/environments/aws && terraform validate

## fmt-check: Check Terraform formatting
fmt-check:
	cd terraform && terraform fmt -check -recursive

# ============================================================================
# ArgoCD Targets
# ============================================================================

## argo-install: Install ArgoCD on cluster
argo-install:
	kubectl apply -f argo-apps/install/01-namespaces.yaml
	kubectl apply -f argo-apps/install/02-argocd-install.yaml
	kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

## argo-bootstrap: Bootstrap ArgoCD applications
argo-bootstrap:
	kubectl apply -f argo-apps/install/03-bootstrap.yaml

## argo-sync: Sync all ArgoCD applications
argo-sync:
	./scripts/argocd-login.sh

## argo-login: Login to ArgoCD CLI
argo-login:
	./scripts/argocd-login.sh

# ============================================================================
# Validation Targets
# ============================================================================

## validate-all: Validate all components
validate-all:
	./scripts/validate.sh all

## validate-apps: Validate ArgoCD applications
validate-apps:
	./scripts/validate.sh apps

## validate-helm: Validate Helm charts
validate-helm:
	./scripts/validate.sh helm

## validate-security: Validate security configurations
validate-security:
	./scripts/validate.sh security

## validate-terraform: Validate Terraform modules
validate-terraform:
	cd terraform/environments/aws && terraform validate

# ============================================================================
# Secrets Management Targets
# ============================================================================

## secrets-create: Create all secrets
secrets-create:
	@echo "Creating secrets..."
	@echo "Note: Simplified - use deploy.sh for comprehensive secret management"
	./scripts/deploy.sh secrets monitoring

## secrets-rotate: Rotate secrets
secrets-rotate:
	@echo "Rotating secrets requires manual intervention for security"
	@echo "Run: ./scripts/deploy.sh secrets <component>"

# ============================================================================
# Deployment Targets
# ============================================================================

## deploy-minikube: Deploy complete stack to Minikube
deploy-minikube:
	./scripts/setup-minikube.sh

## deploy-aws: Deploy complete stack to AWS EKS
deploy-aws:
	./scripts/setup-aws.sh

## deploy-infra: Deploy infrastructure (requires ENV variable)
deploy-infra:
	@if [ -z "$(ENV)" ]; then echo "ERROR: ENV variable required. Usage: make deploy-infra ENV=prod"; exit 1; fi
	./scripts/deploy.sh terraform $(ENV)

## deploy-bootstrap: Bootstrap cluster (requires ENV variable)
deploy-bootstrap:
	@if [ -z "$(ENV)" ]; then echo "ERROR: ENV variable required. Usage: make deploy-bootstrap ENV=prod"; exit 1; fi
	./scripts/deploy.sh bootstrap $(ENV)

## deploy-sync: Sync applications (requires ENV variable)
deploy-sync:
	@if [ -z "$(ENV)" ]; then echo "ERROR: ENV variable required. Usage: make deploy-sync ENV=prod"; exit 1; fi
	./scripts/deploy.sh sync $(ENV)

# ============================================================================
# Documentation Targets
# ============================================================================

## docs-lint: Lint Markdown documentation
docs-lint:
	@command -v markdownlint >/dev/null 2>&1 || { echo "markdownlint not found. Install: npm install -g markdownlint-cli"; exit 1; }
	markdownlint '**/*.md' --ignore node_modules --ignore .git || true

## docs-links: Check documentation links
docs-links:
	@command -v markdown-link-check >/dev/null 2>&1 || { echo "markdown-link-check not found. Install: npm install -g markdown-link-check"; exit 1; }
	find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" | \
		xargs -I {} markdown-link-check {} --config .github/markdown-link-check-config.json || true

# ============================================================================
# Testing & CI/CD Targets
# ============================================================================

## test-actions: Test GitHub Actions locally with act
test-actions:
	@command -v act >/dev/null 2>&1 || { echo "act not found. Install: https://github.com/nektos/act"; exit 1; }
	act -l

## test-actions-validate: Run validate workflow locally
test-actions-validate:
	@command -v act >/dev/null 2>&1 || { echo "act not found. Install: https://github.com/nektos/act"; exit 1; }
	act push -W .github/workflows/validate.yaml

## test-scripts: Test shell scripts syntax
test-scripts:
	@for script in scripts/*.sh; do \
		echo "Checking $$script..."; \
		bash -n "$$script" || exit 1; \
	done
	@echo "All scripts passed syntax check!"

# ============================================================================
# Cleanup Targets
# ============================================================================

## cleanup-dry-run: Preview files to be cleaned up
cleanup-dry-run:
	./scripts/cleanup.sh

## cleanup-execute: Execute cleanup (with backup)
cleanup-execute:
	./scripts/cleanup.sh --execute

## cleanup-backup: Create backup without deletion
cleanup-backup:
	./scripts/cleanup.sh --backup-only

# ============================================================================
# Development Targets
# ============================================================================

## dev-setup: Setup development environment
dev-setup:
	@echo "Setting up development environment..."
	@command -v kubectl >/dev/null 2>&1 || echo "⚠️  kubectl not found"
	@command -v helm >/dev/null 2>&1 || echo "⚠️  helm not found"
	@command -v terraform >/dev/null 2>&1 || echo "⚠️  terraform not found"
	@command -v argocd >/dev/null 2>&1 || echo "⚠️  argocd CLI not found"
	@echo "✓ Development environment check complete"

## dev-status: Show status of all components
dev-status:
	@echo "=== Cluster Status ==="
	@kubectl cluster-info || echo "Not connected to cluster"
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "=== Pods Status ==="
	@kubectl get pods -A 2>/dev/null || echo "Cannot get pods"

# ============================================================================
# Quick Access Targets
# ============================================================================

## status: Show deployment status
status:
	./scripts/deploy.sh status prod

## logs-argocd: View ArgoCD server logs
logs-argocd:
	kubectl logs -n argocd deployment/argocd-server --tail=50 -f

## logs-apps: View application logs (requires APP variable)
logs-apps:
	@if [ -z "$(APP)" ]; then echo "ERROR: APP variable required. Usage: make logs-apps APP=web-app"; exit 1; fi
	kubectl logs -n production deployment/$(APP) --tail=50 -f

## port-forward-argocd: Port-forward to ArgoCD UI
port-forward-argocd:
	@echo "Forwarding ArgoCD to https://localhost:8080"
	@echo "Username: admin"
	@echo "Password: run 'kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d'"
	kubectl port-forward -n argocd svc/argocd-server 8080:443

## port-forward-grafana: Port-forward to Grafana
port-forward-grafana:
	@echo "Forwarding Grafana to http://localhost:3000"
	kubectl port-forward -n monitoring svc/grafana 3000:80

# ============================================================================
# Version Information
# ============================================================================

## version: Show version information
version:
	@echo "=== Infrastructure Versions ==="
	@cat VERSION 2>/dev/null || echo "VERSION file not found"
	@echo ""
	@echo "=== Tool Versions ==="
	@echo "Terraform: $$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo 'not installed')"
	@echo "kubectl: $$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo 'not installed')"
	@echo "Helm: $$(helm version --short 2>/dev/null || echo 'not installed')"
	@echo "ArgoCD: $$(argocd version --client --short 2>/dev/null || echo 'not installed')"

# ============================================================================
# Notes
# ============================================================================
# Environment Variables:
#   ENV=prod|staging|dev     - Target environment for deployment
#   APP=<app-name>          - Application name for logs
#
# Examples:
#   make help                           # Show this help
#   make deploy-minikube                # Full Minikube deployment
#   make deploy-aws                     # Full AWS deployment
#   make deploy-infra ENV=prod          # Deploy prod infrastructure
#   make validate-all                   # Validate everything
#   make argo-sync                      # Sync ArgoCD apps
#   make port-forward-argocd           # Access ArgoCD UI
#   make logs-apps APP=web-app         # View app logs
# ============================================================================
