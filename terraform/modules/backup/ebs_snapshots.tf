# EBS Volume Snapshots for Backup
# This file automates the creation of EBS snapshots for disaster recovery and backup.
# Snapshots are created for each volume ID provided in the variable list.

resource "aws_ebs_snapshot" "eks_data" {
  for_each  = toset(var.ebs_volume_ids) # Loop over each EBS volume ID
  volume_id = each.value                # The ID of the EBS volume to snapshot
  tags = {
    Name        = "eks-backup-${each.value}"
    Environment = var.environment # Tag with environment for tracking
  }
}

variable "ebs_volume_ids" {
  type        = list(string)
  description = "List of EBS volume IDs to snapshot. Add the IDs of all volumes you want to back up."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., production, staging). Used for tagging and organization."
}
