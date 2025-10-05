# Makefile for EKS GitOps Infrastructure
# - Provides convenience targets for Terraform and ArgoCD workflows.
# - Set TF_VAR_* environment variables or edit `terraform/terraform.tfvars` to customise.

.PHONY: init plan apply destroy lint fmt argo-sync validate-apps validate-gitops

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan -var-file=terraform.tfvars

apply:
	cd terraform && terraform apply -var-file=terraform.tfvars

destroy:
	cd terraform && terraform destroy -var-file=terraform.tfvars

lint:
	cd terraform && terraform fmt -check && terraform validate
	# Optional: add tflint/kubeval if available
	# tflint --recursive || true
	# kubeval argo-cd/apps/*.yaml || true

fmt:
	cd terraform && terraform fmt

argo-sync:
	# Refactor: sync Argo CD and prod root app from environments path
	kubectl apply -f bootstrap/04-argo-cd-install.yaml
	kubectl apply -f environments/prod/app-of-apps.yaml

# Convenience targets to bootstrap other environments
argo-sync-staging:
	kubectl apply -f bootstrap/04-argo-cd-install.yaml
	kubectl apply -f environments/staging/app-of-apps.yaml

argo-sync-dev:
	kubectl apply -f bootstrap/04-argo-cd-install.yaml
	kubectl apply -f environments/dev/app-of-apps.yaml

validate-apps:
	./scripts/validate.sh apps

validate-gitops:
	./scripts/validate.sh structure

validate-all:
	./scripts/validate.sh all

create-secrets:
	./scripts/secrets.sh create all

rotate-secrets:
	./scripts/secrets.sh rotate all

deploy-infra:
	./scripts/deploy.sh terraform $(ENV)

bootstrap-cluster:
	./scripts/deploy.sh bootstrap $(ENV)

sync-apps:
	./scripts/deploy.sh sync $(ENV)

generate-config:
	./scripts/config.sh generate --environment $(ENV) --component all

validate-config:
	./scripts/config.sh validate --environment $(ENV)

merge-config:
	./scripts/config.sh merge --environment $(ENV)

# Usage:
#   make init         # Initialize Terraform
#   make plan         # Show Terraform plan
#   make apply        # Apply Terraform changes
#   make destroy      # Destroy all Terraform-managed infrastructure
#   make lint         # Lint and validate Terraform code
#   make fmt          # Auto-format Terraform code
#   make argo-sync    # Bootstrap ArgoCD and root app
#   make validate-apps # Validate ArgoCD applications for best practices
#   make validate-gitops # Validate GitOps repository structure
#   make validate-all # Validate all components (apps, helm, security, etc.)
#   make create-secrets # Create all required secrets
#   make rotate-secrets # Rotate all secrets
#   make deploy-infra ENV=prod # Deploy infrastructure using Terraform
#   make bootstrap-cluster ENV=prod # Bootstrap ArgoCD and applications
#   make sync-apps ENV=prod # Sync ArgoCD applications
#   make generate-config ENV=prod # Generate environment-specific configurations
#   make validate-config ENV=prod # Validate configuration files
#   make merge-config ENV=prod # Merge common and environment configurations
