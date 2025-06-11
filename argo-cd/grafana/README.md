# Grafana Dashboards Directory

This directory contains custom Grafana dashboard definitions and configuration files for monitoring your EKS cluster and applications.

## Purpose
- Provide pre-built dashboards for cluster and application observability
- Enable rapid import of dashboards into Grafana via ArgoCD or manually
- Support monitoring best practices (SLIs, SLOs, resource usage, etc.)

## Structure
- `*.json`: Grafana dashboard JSON files
- `README.md`: This documentation file

## Usage
1. **Import dashboards into Grafana:**
   - Use the Grafana UI to import JSON files
   - Or configure ArgoCD to provision dashboards automatically
2. **Customize dashboards:**
   - Edit JSON files or use the Grafana UI, then export and update the files in this directory

## Best Practices
- Version control all dashboard files
- Use descriptive names and folder structures
- Document custom metrics and panels

## Troubleshooting
- Check Grafana logs for import errors
- Ensure data sources are configured correctly
- See the main [MONITORING & ALERTING GUIDE](../../docs/monitoring-alerting.md) for more help
