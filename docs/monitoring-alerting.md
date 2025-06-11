# Monitoring & Alerting

This document describes how to set up and extend monitoring and alerting for your EKS GitOps cluster.

## Prometheus & Alertmanager
- Core monitoring is provided by Prometheus and Alertmanager, deployed via ArgoCD manifests in `argo-cd/apps/`.
- Default rules are in `alertmanager-rules.yaml`.

## Custom Alerting Example
See `monitoring-alerting-example.yaml` for an example of advanced PrometheusRule configuration:

```yaml
# docs/monitoring-alerting-example.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-app-alerts
  namespace: monitoring
spec:
  groups:
    - name: app-advanced-health
      rules:
        - alert: HighErrorRate
          expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (job) > 5
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "More than 5 HTTP 5xx errors per second for 10 minutes."
        - alert: SlowResponseTime
          expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, job)) > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Slow response time"
            description: "95th percentile response time > 1s for 5 minutes."
```

## Next Steps
- Edit or extend the example to match your app's SLOs.
- Apply with `kubectl apply -f docs/monitoring-alerting-example.yaml`.
