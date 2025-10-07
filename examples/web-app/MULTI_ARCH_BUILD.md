# Multi-Architecture Docker Image Build Guide

## Overview

This guide explains how to build and push Docker images that support multiple CPU architectures (linux/amd64, linux/arm64) to ensure compatibility across different Kubernetes cluster node types.

## Problem Statement

**Error Encountered:**
```
Back-off pulling image "windrunner101/k8s-web-app:latest": 
ErrImagePull: no matching manifest for linux/amd64 in the manifest list entries
```

**Root Cause:**
- The Docker image was built on a single architecture (e.g., ARM64 Mac M1/M2)
- Production EKS nodes run on linux/amd64 architecture
- Docker Hub manifest list does not contain the required architecture variant
- Kubernetes kubelet cannot pull the image for its node architecture

## Solution: Multi-Architecture Builds

### Method 1: Docker Buildx (Recommended)

Docker Buildx is the official Docker CLI plugin for building multi-platform images.

#### Prerequisites

```bash
# Check if buildx is available
docker buildx version

# Create a new builder instance (one-time setup)
docker buildx create --name multi-arch-builder --use
docker buildx inspect --bootstrap
```

#### Build and Push Multi-Arch Image

```bash
# Navigate to the web-app directory
cd examples/web-app

# Build for multiple platforms and push to registry
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t windrunner101/k8s-web-app:latest \
  -t windrunner101/k8s-web-app:v1.0.0 \
  --push \
  .
```

**Flags Explained:**
- `--platform linux/amd64,linux/arm64`: Build for both x86_64 and ARM64 architectures
- `-t windrunner101/k8s-web-app:latest`: Tag as latest
- `-t windrunner101/k8s-web-app:v1.0.0`: Tag with semantic version
- `--push`: Automatically push to Docker Hub after build
- `.`: Build context (current directory)

#### Verify Multi-Arch Manifest

```bash
# Check the manifest list
docker buildx imagetools inspect windrunner101/k8s-web-app:latest
```

**Expected Output:**
```
Name:      docker.io/windrunner101/k8s-web-app:latest
MediaType: application/vnd.docker.distribution.manifest.list.v2+json
Digest:    sha256:abc123...

Manifests:
  Name:      docker.io/windrunner101/k8s-web-app:latest@sha256:def456...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/amd64

  Name:      docker.io/windrunner101/k8s-web-app:latest@sha256:ghi789...
  MediaType: application/vnd.docker.distribution.manifest.v2+json
  Platform:  linux/arm64
```

### Method 2: GitHub Actions (Automated CI/CD)

See `.github/workflows/docker-build-push.yaml` for the automated GitHub Actions workflow.

**Workflow Features:**
- Triggers on push to main branch and pull requests
- Builds for linux/amd64 and linux/arm64
- Uses Docker Buildx with cache optimization
- Pushes to Docker Hub with semantic versioning
- Automatically tags with git SHA and latest

**To use:**
1. Add Docker Hub credentials to GitHub Secrets:
   - `DOCKERHUB_USERNAME`
   - `DOCKERHUB_TOKEN`
2. Push changes to trigger workflow
3. Monitor build in GitHub Actions tab

### Method 3: Manual Build on Different Machines (Not Recommended)

If buildx is not available, you can manually build on different architecture machines:

```bash
# On amd64 Linux machine
docker build -t windrunner101/k8s-web-app:latest-amd64 .
docker push windrunner101/k8s-web-app:latest-amd64

# On arm64 machine (Mac M1/M2)
docker build -t windrunner101/k8s-web-app:latest-arm64 .
docker push windrunner101/k8s-web-app:latest-arm64

# Create and push manifest list (on any machine)
docker manifest create windrunner101/k8s-web-app:latest \
  windrunner101/k8s-web-app:latest-amd64 \
  windrunner101/k8s-web-app:latest-arm64

docker manifest push windrunner101/k8s-web-app:latest
```

**Drawbacks:**
- Requires access to multiple machines
- Manual process prone to errors
- Not suitable for CI/CD pipelines

## Updated Build Script

The `build-and-push.sh` script has been updated to support multi-arch builds:

```bash
# Usage
./build-and-push.sh

# Or specify custom version
./build-and-push.sh v1.2.3
```

## Best Practices

### 1. **Always Use Semantic Versioning**

Avoid using `:latest` tag in production. Instead, use specific versions:

```yaml
# Bad (non-deterministic)
image:
  repository: windrunner101/k8s-web-app
  tag: "latest"

# Good (deterministic)
image:
  repository: windrunner101/k8s-web-app
  tag: "v1.2.3"
```

### 2. **Tag Strategy**

Use multiple tags for flexibility:
- `:latest` - Latest stable release
- `:v1.2.3` - Full semantic version (immutable)
- `:v1.2` - Minor version (updated with patches)
- `:v1` - Major version (updated with minor releases)
- `:sha-abc123` - Git commit SHA (useful for rollback)

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t windrunner101/k8s-web-app:latest \
  -t windrunner101/k8s-web-app:v1.2.3 \
  -t windrunner101/k8s-web-app:v1.2 \
  -t windrunner101/k8s-web-app:v1 \
  -t windrunner101/k8s-web-app:sha-abc123 \
  --push \
  .
```

### 3. **Use Image Digests for Maximum Immutability**

After pushing, pin to digest in critical environments:

```bash
# Get image digest
docker buildx imagetools inspect windrunner101/k8s-web-app:v1.2.3 --format '{{json .Manifest.Digest}}'

# Use in Kubernetes (optional, for maximum security)
image: windrunner101/k8s-web-app@sha256:abc123...
```

### 4. **Test Before Production**

Always test multi-arch images in staging:

```bash
# Pull and test on amd64
docker pull --platform linux/amd64 windrunner101/k8s-web-app:v1.2.3
docker run --rm windrunner101/k8s-web-app:v1.2.3 node --version

# Pull and test on arm64
docker pull --platform linux/arm64 windrunner101/k8s-web-app:v1.2.3
docker run --rm windrunner101/k8s-web-app:v1.2.3 node --version
```

## Troubleshooting

### Issue: Buildx Not Found

```bash
# Install Docker Buildx plugin (Linux)
mkdir -p ~/.docker/cli-plugins
curl -L "https://github.com/docker/buildx/releases/latest/download/buildx-$(uname -s)-$(uname -m)" \
  -o ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx

# Verify installation
docker buildx version
```

### Issue: QEMU Emulation Errors

```bash
# Install QEMU for cross-platform emulation
docker run --privileged --rm tonistiigi/binfmt --install all

# Verify
docker buildx inspect --bootstrap
```

### Issue: Build Timeout or Slow Builds

Cross-platform builds can be slow due to QEMU emulation. Solutions:

1. **Use native builders** (GitHub Actions provides multi-arch runners)
2. **Enable build cache:**
   ```bash
   docker buildx build \
     --platform linux/amd64,linux/arm64 \
     --cache-from type=registry,ref=windrunner101/k8s-web-app:buildcache \
     --cache-to type=registry,ref=windrunner101/k8s-web-app:buildcache,mode=max \
     -t windrunner101/k8s-web-app:latest \
     --push \
     .
   ```

### Issue: Authentication Failed

```bash
# Login to Docker Hub
docker login

# Or use token-based authentication
echo $DOCKERHUB_TOKEN | docker login --username $DOCKERHUB_USERNAME --password-stdin
```

## Architecture Detection in Kubernetes

To verify which architecture Kubernetes nodes are using:

```bash
# Check node architecture
kubectl get nodes -o custom-columns=NAME:.metadata.name,ARCH:.status.nodeInfo.architecture

# Check if pods are running on correct architecture
kubectl get pod <pod-name> -o jsonpath='{.spec.nodeName}' | xargs -I {} kubectl get node {} -o jsonpath='{.status.nodeInfo.architecture}'
```

## Migration Plan for Existing Images

### Step 1: Audit Current Images

```bash
# List all images used in cluster
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u
```

### Step 2: Rebuild with Multi-Arch Support

For each image that lacks multi-arch support:
1. Update build process to use buildx
2. Build and push multi-arch manifest
3. Update image tags in Kubernetes manifests
4. Test in staging environment

### Step 3: Deploy Updates

```bash
# Update Helm values with new image tag
helm upgrade k8s-web-app ./helm \
  -f values.yaml \
  --set image.tag=v1.2.3 \
  --namespace production

# Or use ArgoCD sync
argocd app sync k8s-web-app-prod
```

## References

- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [Multi-platform Images Guide](https://docs.docker.com/build/building/multi-platform/)
- [GitHub Actions Docker Buildx Action](https://github.com/docker/build-push-action)
- [Kubernetes Multi-Architecture Support](https://kubernetes.io/docs/concepts/cluster-administration/node/)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Consult Docker Buildx documentation
3. Create an issue in the repository with build logs

---

**Last Updated:** 2025-10-07  
**Author:** Production-Ready EKS Cluster with GitOps Team  
**Version:** 1.0.0

