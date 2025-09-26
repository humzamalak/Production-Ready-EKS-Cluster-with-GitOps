# Makefile for EKS GitOps Infrastructure
# - Provides convenience targets for Terraform and ArgoCD workflows.
# - Set TF_VAR_* environment variables or edit `terraform/terraform.tfvars` to customise.

.PHONY: init plan apply destroy lint fmt argo-sync

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
	kubectl apply -f argo-cd/bootstrap/argo-cd-install.yaml
	kubectl apply -f argo-cd/apps/root-app.yaml

# Usage:
#   make init      # Initialize Terraform
#   make plan      # Show Terraform plan
#   make apply     # Apply Terraform changes
#   make destroy   # Destroy all Terraform-managed infrastructure
#   make lint      # Lint and validate Terraform code
#   make fmt       # Auto-format Terraform code
#   make argo-sync # Bootstrap ArgoCD and root app
