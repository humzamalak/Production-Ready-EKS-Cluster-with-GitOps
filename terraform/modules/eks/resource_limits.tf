# Resource Requests and Limits for System Components
# This resource quota ensures that system components in the kube-system namespace do not exceed specified resource limits.
# Helps prevent resource exhaustion and ensures fair scheduling.

resource "kubernetes_resource_quota" "system" {
  metadata {
    name      = "system-resources" # Name of the resource quota
    namespace = "kube-system"      # Namespace to apply the quota
  }
  spec {
    hard = {
      cpu    = "8"    # Maximum total CPU cores for the namespace
      memory = "32Gi" # Maximum total memory for the namespace
      pods   = "100"  # Maximum number of pods in the namespace
    }
  }
}
