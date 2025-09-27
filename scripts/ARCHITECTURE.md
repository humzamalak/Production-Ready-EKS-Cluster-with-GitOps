# Script Architecture Diagram

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Main Deployment Script                       │
│                    scripts/deploy.sh                           │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                 Shared Library                                  │
│                 scripts/lib/common.sh                          │
│  • Logging functions                                           │
│  • Prerequisites validation                                    │
│  • Common utilities                                            │
└─────────────────────────────────────────────────────────────────┘
                      ▲
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
    ▼                 ▼                 ▼
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Backend │    │Infrastructure│    │   ArgoCD   │    │Applications│
│Management│    │  Deploy     │    │   Deploy   │    │   Deploy   │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘
    │                 │                 │                 │
    ▼                 ▼                 ▼                 ▼
┌─────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│• S3 Bucket│   │• EKS Cluster│   │• ArgoCD     │    │• Monitoring │
│• DynamoDB│    │• VPC        │    │• Helm       │    │• Prometheus │
│• State   │    │• IAM        │    │• Config     │    │• Grafana    │
└─────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

## Execution Order

1. **Backend Management** → Creates Terraform backend resources
2. **Infrastructure Deploy** → Deploys EKS cluster and infrastructure
3. **ArgoCD Deploy** → Installs and configures ArgoCD
4. **Applications Deploy** → Deploys applications via ArgoCD

## Script Responsibilities

### Main Script (`deploy.sh`)
- Orchestrates all component scripts
- Handles skip options for selective deployment
- Provides comprehensive help and usage information
- Manages overall deployment flow

### Backend Management (`backend-management.sh`)
- Creates S3 bucket for Terraform state storage
- Creates DynamoDB table for state locking
- Handles backend configuration and state issues
- Validates backend resources

### Infrastructure Deploy (`infrastructure-deploy.sh`)
- Terraform initialization and deployment
- kubectl configuration for EKS cluster
- Cluster access verification
- Infrastructure status reporting

### ArgoCD Deploy (`argocd-deploy.sh`)
- ArgoCD Helm installation
- Cluster access validation
- Admin password retrieval
- ArgoCD status monitoring

### Applications Deploy (`applications-deploy.sh`)
- App-of-apps pattern deployment
- Monitoring namespace creation
- Application sync monitoring
- Monitoring stack verification

### Shared Library (`lib/common.sh`)
- Logging functions (log, error, success, warning)
- Prerequisites validation
- Common argument parsing
- Helper functions for cluster access
- Access information display

## Benefits of Modular Design

### Separation of Concerns
- Each script handles a specific component
- Changes to one component don't affect others
- Easier to understand and maintain

### Independent Execution
- Scripts can be run individually for targeted deployments
- Supports skip options for selective deployment
- Better for troubleshooting and testing

### Enhanced Error Handling
- Component-specific error messages
- Better error isolation and debugging
- Graceful handling of partial deployments

### Improved Logging
- Consistent logging format across all scripts
- Colored output for better readability
- Timestamps for all log entries
- Detailed logging to deployment.log

## Usage Patterns

### Full Deployment
```bash
./scripts/deploy.sh
```

### Selective Deployment
```bash
./scripts/deploy.sh --skip-infra
./scripts/deploy.sh --skip-argocd
./scripts/deploy.sh --skip-apps
```

### Individual Components
```bash
./scripts/backend-management.sh
./scripts/infrastructure-deploy.sh
./scripts/argocd-deploy.sh
./scripts/applications-deploy.sh
```

### Validation and Testing
```bash
./scripts/deploy.sh --validate-only
./scripts/deploy.sh --dry-run
```
