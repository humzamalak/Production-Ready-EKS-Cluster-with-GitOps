# Kubernetes v1.33.0 Upgrade Summary

Date: 2025-10-05

## Files Updated

- `applications/web-app/k8s-web-app/helm/templates/ingress.yaml` – Added v1.33 compatibility note; confirmed networking.k8s.io/v1 usage and service backend fields
- `applications/web-app/k8s-web-app/helm/templates/hpa.yaml` – Added v1.33 note; using autoscaling/v2 with resource metrics
- `applications/web-app/k8s-web-app/helm/templates/deployment.yaml` – Added v1.33 note; verified probes/resources hooks
- `bootstrap/06-etcd-backup.yaml` – Added v1.33 note; confirmed batch/v1 CronJob schema
- `scripts/validate.sh` – Added kubectl >=1.33 check; improved status output
- `README.md` – Declared v1.33.0 compatibility; added Compatibility Notes section
- `docs/README.md` – Declared v1.33.0 compatibility
- `docs/local-deployment.md` – Declared v1.33.0 compatibility; kubectl v1.33+
- `docs/aws-deployment.md` – Declared v1.33.0 compatibility; cluster_version 1.33; kubectl v1.33+

## Deprecated APIs Replaced / Avoided

- Avoided all beta APIs (`extensions/*`, `networking.k8s.io/v1beta1`, `batch/v1beta1`, `rbac.authorization.k8s.io/v1beta1`, `policy/v1beta1` PSP). Repo already used stable APIs.
- Confirmed stable APIs in use:
  - `apps/v1` Deployments
  - `networking.k8s.io/v1` Ingress/NetworkPolicy
  - `autoscaling/v2` HPA
  - `batch/v1` CronJob/Job
  - `rbac.authorization.k8s.io/v1` RBAC

## Key Changes for Maintainers

- Docs and scripts now assume Kubernetes v1.33.0
- Validation script warns if kubectl client < 1.33
- Ingress templates already use `service.name` and `port.number` backend fields (v1 schema)
- Pod Security uses Pod Security Standards via namespace labels; PSP is not used

## How to Validate Compatibility

1. Ensure `kubectl` client is v1.33+:
   ```bash
   kubectl version --client --short
   ```
2. Run repository validation:
   ```bash
   ./scripts/validate.sh all
   ```
3. Helm lint and template checks:
   ```bash
   (cd applications/web-app/k8s-web-app/helm && helm lint . && helm template test . --dry-run)
   ```
4. Apply dry-run validation against a v1.33 cluster:
   ```bash
   kubectl apply --dry-run=server -f bootstrap/00-namespaces.yaml
   ```

## Notes

- No deprecated apiVersions were found in the repository at the time of upgrade.
- If adding new resources, prefer stable APIs and validate with server-side dry-run.

