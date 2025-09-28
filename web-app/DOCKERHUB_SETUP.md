# DockerHub Setup and Deployment Guide

This guide walks you through building and pushing your K8s Web App to DockerHub.

## Prerequisites

1. ✅ Docker installed and running
2. ✅ DockerHub account (username: `windwalker101`)
3. ✅ DockerHub access token or password

## Step 1: Login to DockerHub

### Option A: Using Docker Login Command

```bash
# Login to DockerHub
docker login

# Enter your credentials:
# Username: windwalker101
# Password: [your DockerHub password or access token]
```

### Option B: Using Access Token (Recommended)

1. Go to [DockerHub Account Settings](https://hub.docker.com/settings/security)
2. Click "New Access Token"
3. Give it a name like "k8s-web-app-deployment"
4. Copy the token and use it as your password:

```bash
docker login
# Username: windwalker101
# Password: [paste your access token]
```

## Step 2: Build and Push to DockerHub

### Quick Build and Push

```bash
# Navigate to the web-app directory
cd web-app

# Run the build and push script
./build-and-push.sh
```

This script will:
- Build the Docker image with tag `windwalker101/k8s-web-app:latest`
- Push it to DockerHub
- Show you the DockerHub URL

### Manual Build and Push

```bash
# Build the image
docker build -t windwalker101/k8s-web-app:latest .

# Push to DockerHub
docker push windwalker101/k8s-web-app:latest
```

### Build with Custom Tag

```bash
# Build with version tag
./build-and-push.sh v1.0.0

# This creates: windwalker101/k8s-web-app:v1.0.0
# And also: windwalker101/k8s-web-app:latest
```

## Step 3: Verify Upload

1. **Check DockerHub**: Visit https://hub.docker.com/r/windwalker101/k8s-web-app
2. **Test locally**:
   ```bash
   # Pull and test the image
   docker pull windwalker101/k8s-web-app:latest
   docker run -p 3000:3000 windwalker101/k8s-web-app:latest
   
   # Test the application
   curl http://localhost:3000/health
   ```

## Step 4: Deploy to Kubernetes

Now that your image is on DockerHub, you can deploy it to your Kubernetes cluster.

### Option A: Using ArgoCD (GitOps)

The ArgoCD configuration is already updated to use your DockerHub image:

```bash
# Apply the ArgoCD application
kubectl apply -f argo-cd/apps/k8s-web-app.yaml

# Check deployment status
kubectl get applications -n argocd
```

### Option B: Using Helm

```bash
# Install using Helm
helm install k8s-web-app ./web-app/helm \
  -n production \
  --create-namespace \
  -f web-app/values/k8s-web-app-values.yaml
```

### Option C: Direct Kubernetes

```bash
# Apply Kubernetes manifests
kubectl apply -f web-app/k8s/
```

## Step 5: Verify Deployment

```bash
# Check pods are running
kubectl get pods -n production -l app=k8s-web-app

# Check services
kubectl get svc -n production

# Check ingress
kubectl get ingress -n production

# Test the application
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production
curl http://localhost:8080/health
```

## DockerHub Repository Details

- **Repository**: https://hub.docker.com/r/windwalker101/k8s-web-app
- **Image Name**: `windwalker101/k8s-web-app`
- **Latest Tag**: `windwalker101/k8s-web-app:latest`

## Updating the Application

When you make changes to your application:

1. **Build and push new version**:
   ```bash
   ./build-and-push.sh v1.1.0
   ```

2. **Update Helm values** (if using version tags):
   ```yaml
   image:
     repository: windwalker101/k8s-web-app
     tag: "v1.1.0"
   ```

3. **Deploy via ArgoCD**:
   ```bash
   git add .
   git commit -m "Update to v1.1.0"
   git push
   # ArgoCD will automatically sync
   ```

## Troubleshooting

### Docker Login Issues

```bash
# Check if logged in
docker system info | grep Username

# Logout and login again
docker logout
docker login
```

### Build Issues

```bash
# Check Docker is running
docker info

# Check Dockerfile syntax
docker build --no-cache -t windwalker101/k8s-web-app:latest .
```

### Push Issues

```bash
# Check image exists locally
docker images | grep windwalker101/k8s-web-app

# Test push with verbose output
docker push windwalker101/k8s-web-app:latest
```

### Kubernetes Deployment Issues

```bash
# Check image pull errors
kubectl describe pod <pod-name> -n production

# Check events
kubectl get events -n production --sort-by=.metadata.creationTimestamp
```

## Security Best Practices

1. **Use Access Tokens**: Instead of passwords, use DockerHub access tokens
2. **Scan Images**: Consider using tools like Trivy to scan for vulnerabilities
3. **Private Repositories**: For production, consider using private repositories
4. **Image Signing**: Implement image signing for enhanced security

## Next Steps

1. **Set up CI/CD**: Automate the build and push process with GitHub Actions
2. **Image Scanning**: Add vulnerability scanning to your pipeline
3. **Multi-arch Builds**: Build for multiple architectures (amd64, arm64)
4. **Registry Mirrors**: Consider using registry mirrors for faster pulls

## Support

If you encounter any issues:

1. Check the troubleshooting section above
2. Verify your DockerHub credentials
3. Ensure Docker is running properly
4. Check the DockerHub repository for upload confirmation
