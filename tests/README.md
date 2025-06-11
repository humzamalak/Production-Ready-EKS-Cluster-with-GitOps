# Infrastructure Testing

This directory contains the automated test suite and static analysis tools for validating your EKS GitOps infrastructure.

## Purpose
- Ensure infrastructure changes are safe, secure, and functional
- Automate regression and compliance testing
- Provide examples for writing new tests

## Tools
- [Terratest](https://terratest.gruntwork.io/): Infrastructure testing in Go
- [Checkov](https://www.checkov.io/): Static analysis for Terraform and Kubernetes

## Example Test (Terratest)
```go
package test

import (
  "testing"
  "github.com/gruntwork-io/terratest/modules/terraform"
)

// This test deploys the Terraform code and ensures it applies and destroys cleanly.
func TestTerraformBasic(t *testing.T) {
  opts := &terraform.Options{
    TerraformDir: "../terraform",
  }
  defer terraform.Destroy(t, opts)
  terraform.InitAndApply(t, opts)
}
```

## Best Practices
- Run tests before every PR merge
- Add new tests for each new module or feature
- Use static analysis to catch security and compliance issues early

## Troubleshooting
- Check test logs for errors
- Ensure AWS credentials and permissions are set up for test runs
- See the main [TROUBLESHOOTING.md](../TROUBLESHOOTING.md) for more help
