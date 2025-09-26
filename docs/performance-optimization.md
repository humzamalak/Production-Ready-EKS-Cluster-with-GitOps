# Performance Optimisation Checklist

This guide provides tips and best practices for optimising the performance and cost-efficiency of your EKS cluster and GitOps workflows.

## Cluster & Workload Optimisation
- Use resource requests and limits for all workloads to ensure fair scheduling and prevent resource contention.
- Enable the cluster autoscaler for efficient scaling based on demand.
- Optimise Terraform modules by using data sources and avoiding duplication.
- Use ArgoCD sync options like `ApplyOutOfSyncOnly` and `selfHeal` for efficient reconciliation.
- Monitor costs with Infracost and AWS Cost Explorer.

## Best Practices
- Regularly review resource usage and adjust limits as needed.
- Use spot instances for non-critical workloads to save costs.
- Enable detailed monitoring in AWS for all resources.
- Document all optimisation changes and their impact.

## Troubleshooting
- Check cluster and application metrics in Grafana.
- Review autoscaler and ArgoCD logs for scaling or sync issues.
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help.
