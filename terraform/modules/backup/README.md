# Backup Terraform Module

This module provisions automated EBS (Elastic Block Store) volume snapshots for backup and disaster recovery in your EKS environment.

## Purpose
- Enable regular, automated backups of EBS volumes
- Support disaster recovery and data retention policies
- Integrate with EKS workloads requiring persistent storage

## Features
- Snapshot any list of EBS volumes
- Tagging for environment and resource tracking
- Simple variable-driven configuration

## Usage
```hcl
module "backup" {
  source         = "./modules/backup"
  ebs_volume_ids = ["vol-12345678", "vol-87654321"]
  environment    = var.environment
}
```

## Inputs
| Name           | Description                        | Type         | Default |
|----------------|------------------------------------|--------------|---------|
| ebs_volume_ids | List of EBS volume IDs to snapshot | list(string) | n/a     |
| environment    | Environment name                   | string       | n/a     |

## Outputs
- None (snapshots are managed by AWS)

## Requirements
- AWS CLI configured
- Terraform >= 1.4.0
- AWS provider >= 5.0

## IAM Policy
See root README for minimal IAM policy required.
