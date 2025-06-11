# Disaster Recovery Runbook

## EBS Volume Restore
1. Identify the latest EBS snapshot in AWS Console or via CLI.
2. Create a new EBS volume from the snapshot.
3. Attach the volume to the appropriate EC2 instance/node.
4. Mount the volume and verify data integrity.

## ETCD Restore
1. Stop the kube-apiserver and etcd pods/services.
2. Copy the desired etcd snapshot to the etcd data directory.
3. Run `etcdctl snapshot restore` with the correct flags.
4. Restart etcd and kube-apiserver.
5. Verify cluster health with `kubectl get nodes` and `kubectl get pods -A`.

## Application Restore
1. Re-deploy applications via ArgoCD (app-of-apps pattern).
2. Monitor application health and logs.

## Testing Recovery
- Schedule regular recovery drills (at least quarterly).
- Document and review each test for improvements.
