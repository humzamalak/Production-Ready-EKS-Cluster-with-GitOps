# Image Build Instructions

## Before Deploying the Web App

The k8s-web-app requires a multi-architecture Docker image to support both AMD64 and ARM64 platforms.

### Prerequisites

1. Docker installed and running
2. Docker Buildx installed
3. DockerHub account logged in (`docker login`)

### Build and Push Multi-Arch Image

```bash
# Navigate to the web-app directory
cd examples/web-app

# Build and push with a specific version tag
./build-and-push.sh v1.0.0

# The script will create:
# - windrunner101/k8s-web-app:v1.0.0
# - windrunner101/k8s-web-app:latest
# - windrunner101/k8s-web-app:sha-<git-sha>
```

### Verify Multi-Arch Support

After building, verify the image supports multiple architectures:

```bash
docker buildx imagetools inspect windrunner101/k8s-web-app:v1.0.0
```

You should see both `linux/amd64` and `linux/arm64` in the manifest.

### Update Helm Values

After building and pushing the image, ensure the Helm values reference the correct tag:

```yaml
# applications/web-app/k8s-web-app/helm/values.yaml
image:
  repository: windrunner101/k8s-web-app
  tag: "v1.0.0"  # Match the tag you built
```

### Common Issues

#### Issue: "no matching manifest for linux/amd64"

**Cause**: The image tag doesn't exist or wasn't built with multi-arch support.

**Solution**: Build and push the image using the provided script:
```bash
cd examples/web-app
./build-and-push.sh v1.0.0
```

#### Issue: "unauthorized: authentication required"

**Cause**: Not logged in to DockerHub.

**Solution**: Log in to DockerHub:
```bash
docker login
# Enter username: windrunner101
# Enter password/token
```

### Production Best Practices

1. **Never use `latest` tag in production** - Always use specific version tags for traceability
2. **Tag versioning** - Use semantic versioning (v1.0.0, v1.1.0, etc.)
3. **Git SHA tagging** - The script automatically creates `sha-<commit>` tags for traceability
4. **Multi-arch builds** - Always build for both amd64 and arm64 to ensure compatibility

### Next Steps

After building the image, you can deploy the application:

1. Ensure Argo CD is installed and configured
2. Apply the web-app Argo CD application:
   ```bash
   kubectl apply -f environments/prod/apps/web-app.yaml
   ```
3. Monitor the deployment:
   ```bash
   kubectl get pods -n production
   argocd app get k8s-web-app-prod
   ```

