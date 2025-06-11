# Cluster Autoscaler Deployment for EKS
# This file deploys the Kubernetes Cluster Autoscaler using Helm.
# The autoscaler automatically adjusts the number of nodes in your cluster based on resource demand.
# The variables cluster_name and region are provided by the module or parent configuration.

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler" # Name of the Helm release
  repository = "https://kubernetes.github.io/autoscaler" # Helm chart repository
  chart      = "cluster-autoscaler" # Chart name
  version    = "9.29.0" # Chart version
  namespace  = "kube-system" # Namespace to deploy the autoscaler
  values = [
    <<EOF
    autoDiscovery:
      clusterName: ${var.cluster_name} # Name of the EKS cluster (from variable)
    awsRegion: ${var.region} # AWS region (from variable)
    rbac:
      create: true
      serviceAccount:
        create: true
        name: cluster-autoscaler
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
    EOF
  ]
}
