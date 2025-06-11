# Monitoring and Alerting Guide

This guide explains how to monitor your EKS cluster and set up alerting for critical events.

## Monitoring
- **Prometheus** and **Grafana** are deployed for metrics collection and visualization.
- Use ServiceMonitors to scrape custom application metrics.
- Import custom dashboards from `argo-cd/grafana/` for cluster and app observability.

## Alerting
- **AlertManager** is configured for Slack/email notifications.
- Review and update alert rules in `argo-cd/apps/alertmanager-rules.yaml`.
- Set up notification channels for critical alerts (Slack, email, PagerDuty).

## Best Practices
- Regularly review dashboards and alert rules.
- Test alerting by simulating failures.
- Document all custom metrics and alerting policies.

## Troubleshooting
- Check Prometheus and AlertManager logs for errors.
- Ensure all ServiceMonitors and Alert rules are applied.
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help.
