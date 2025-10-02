# Vault CSI Provider Troubleshooting Guide

This guide helps diagnose and fix rollout issues for the `vault-csi-provider` DaemonSet and safely redeploy Argo CD applications.

## When to use this
- `kubectl -n vault rollout status ds/vault-csi-provider` hangs
- Events show Pod Security Admission violations (restricted PSA) or pods are stuck Pending/Terminating

## 1) Quick diagnosis commands
Run these to get high-signal status and events:

```bash
kubectl -n vault get ds vault-csi-provider -o wide
kubectl -n vault describe ds vault-csi-provider
kubectl -n vault get pods -l app.kubernetes.io/name=vault-csi-provider -o wide
kubectl -n vault get events --sort-by=.lastTimestamp | tail -n 100
kubectl -n vault rollout status ds/vault-csi-provider --timeout=120s || true
```

Common symptoms and causes:
- PodSecurity "restricted:latest" violations: hostPath mount, missing securityContext, missing seccompProfile
- FailedScheduling: nodeSelector/tolerations mismatch vs node taints
- CSI registration errors: wrong kubelet hostPath mounts

## 2) Permanent fixes encoded in Git (do once)
We codify fixes so they persist across upgrades.

- Namespace PSA for `vault` (privileged): `bootstrap/00-namespaces.yaml`
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vault
  labels:
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

- Helm values hardening for CSI provider: `applications/security/vault/values.yaml`
```yaml
csi:
  enabled: true
  podSecurityContext:
    seccompProfile:
      type: RuntimeDefault
  provider:
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop:
          - ALL
  agent:
    securityContext:
      allowPrivilegeEscalation: false
      runAsNonRoot: true
      capabilities:
        drop:
          - ALL
```

Apply namespace changes first:
```bash
kubectl apply -f bootstrap/00-namespaces.yaml
kubectl get ns vault -o jsonpath='{.metadata.labels}{"\n"}'
```

## 3) Force-clean stuck resources (if rollout is wedged)
Use these only when pods/DS are stuck Terminating/Pending.

- Force delete only provider pods:
```bash
kubectl -n vault delete pod -l app.kubernetes.io/name=vault-csi-provider --force --grace-period=0
```

- If the DaemonSet controller is wedged, delete DS and orphan pods (Argo/Helm will recreate):
```bash
kubectl -n vault delete ds vault-csi-provider --grace-period=0 --force --cascade=orphan || true
kubectl -n vault get ds,pod -l app.kubernetes.io/name=vault-csi-provider
```

- Nuke all pods in `vault` namespace if many are stuck:
```bash
kubectl -n vault delete pod --all --force --grace-period=0
```

## 4) Remove Argo CD Applications (optional reset)
- Export list (optional):
```bash
kubectl -n argocd get applications.argoproj.io -o name > /tmp/argo-apps.txt || true
```

- Delete ApplicationSets (if any):
```bash
kubectl -n argocd delete applicationsets.argoproj.io --all --ignore-not-found
```

- Delete Applications and wait:
```bash
kubectl -n argocd delete applications.argoproj.io --all --wait=true --grace-period=0 --timeout=5m --ignore-not-found
```

- If any Application is stuck because of finalizers, remove and force delete:
```bash
for app in $(kubectl -n argocd get applications.argoproj.io -o name); do
  kubectl -n argocd patch $app --type=json -p='[{"op":"remove","path":"/metadata/finalizers"}]' || true
  kubectl -n argocd delete $app --grace-period=0 --force --timeout=30s || true
done
```

## 5) Recreate Argo CD and re-apply apps
- Ensure Argo CD is installed (if managed here):
```bash
kubectl apply -f bootstrap/04-argo-cd-install.yaml
kubectl -n argocd rollout status deploy/argocd-server --timeout=3m
```

- Re-apply projects and app-of-apps:
```bash
kubectl apply -f clusters/production/production-apps-project.yaml
kubectl apply -f clusters/production/app-of-apps.yaml
kubectl apply -f clusters/production/namespaces.yaml
```

## 6) Verify Secrets Store CSI Driver and Vault CSI provider
```bash
kubectl -n kube-system get ds secrets-store-csi-driver -o wide
kubectl -n vault rollout status ds/vault-csi-provider --timeout=3m
kubectl -n vault get ds,pod -l app.kubernetes.io/name=vault-csi-provider -o wide
kubectl -n vault get events --sort-by=.lastTimestamp | tail -n 50
```

## 7) If still failing
- Re-check events for PSA blocks
- Confirm node taints/tolerations and nodeSelector
- Inspect logs:
```bash
P=$(kubectl -n vault get pod -l app.kubernetes.io/name=vault-csi-provider -o name | head -n1)
kubectl -n vault logs $P -c csi-driver-registrar || true
kubectl -n vault logs $P -c vault-csi-provider || true
kubectl -n vault logs $P -c vault-agent || true
```

## Notes
- CSI components require hostPath for socket registration; running them in a privileged PSA namespace (or `kube-system`) is standard.
- The hardening in Helm values protects against future PSA changes.
