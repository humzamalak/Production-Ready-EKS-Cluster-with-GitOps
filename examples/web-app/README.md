# K8s Web Application

A production-ready Node.js web application designed for deployment on Kubernetes clusters using GitOps principles with ArgoCD.

## Features

- **Modern Web Framework**: Built with Express.js and Node.js 18
- **Production Ready**: Includes health checks, security headers, and graceful shutdown
- **Containerized**: Optimized Docker image with multi-stage builds
- **Kubernetes Native**: Complete K8s manifests with Deployment, Service, and Ingress
- **GitOps Ready**: Helm chart and ArgoCD application configurations
- **Auto-scaling**: Horizontal Pod Autoscaler (HPA) configuration
- **Security**: Non-root user, read-only filesystem, and security contexts
- **Monitoring**: Health and readiness probes for proper lifecycle management
- **Vault Integration**: Automatic secret injection using Vault agent sidecar

## Application Structure

```
web-app/
├── server.js              # Main Express application
├── package.json           # Node.js dependencies
├── Dockerfile            # Container image definition
├── .dockerignore         # Docker ignore file
├── k8s/                  # Kubernetes manifests (basic examples)
│   ├── service.yaml      # Service configuration
│   ├── ingress.yaml      # Ingress configuration
│   └── hpa.yaml         # Horizontal Pod Autoscaler
├── values/              # Environment-specific values (examples)
└── README.md           # This file
```

**Note**: The production-ready Helm chart and deployment manifests have been moved to `applications/web-app/k8s-web-app/` as part of the GitOps structure. This directory contains example configurations for reference and development.

## Quick Start

### 1. Build and Test Locally

```bash
# Install dependencies
cd web-app
npm install

# Start development server
npm run dev

# Test the application
curl http://localhost:3000/health
```

### 2. Build Docker Image

```bash
# Build the image
docker build -t k8s-web-app:latest .

# Test the container
docker run -p 3000:3000 k8s-web-app:latest

# Access the application
curl http://localhost:3000
```

### 3. Deploy to Kubernetes

#### Option A: Direct Kubernetes Deployment

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n production
kubectl get services -n production
kubectl get ingress -n production
```

#### Option B: Using Helm

```bash
# Install using Helm
helm install k8s-web-app ./helm -n production --create-namespace

# Check deployment
helm list -n production
kubectl get pods -n production
```

#### Option C: Using ArgoCD (GitOps)

1. Update the repository URL in `argo-cd/apps/k8s-web-app.yaml`
2. Apply the ArgoCD application:
   ```bash
   kubectl apply -f argo-cd/apps/k8s-web-app.yaml
   ```
3. Monitor deployment in ArgoCD UI

## Configuration

### Environment Variables

- `NODE_ENV`: Application environment (default: development)
- `APP_VERSION`: Application version (default: 1.0.0)
- `PORT`: Server port (default: 3000)
- `HOST`: Server host (default: 0.0.0.0)

### Helm Values

Key configuration options in `helm/values.yaml`:

```yaml
replicaCount: 3                    # Number of replicas
resources:                         # Resource limits and requests
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
autoscaling:                       # HPA configuration
  enabled: true
  minReplicas: 2
  maxReplicas: 10
ingress:                          # Ingress configuration
  enabled: true
  hosts:
    - host: k8s-web-app.example.com
```

## API Endpoints

- `GET /` - Main application page
- `GET /health` - Health check endpoint
- `GET /ready` - Readiness probe endpoint
- `GET /api/info` - Application information API

## Security Features

- **Non-root user**: Container runs as user 1001
- **Read-only filesystem**: Prevents write access to container filesystem
- **Security headers**: Helmet.js provides security headers
- **Resource limits**: CPU and memory limits prevent resource exhaustion
- **Network policies**: Ready for network policy implementation

## Monitoring and Observability

### Health Checks

- **Liveness Probe**: `/health` endpoint (30s initial delay, 10s interval)
- **Readiness Probe**: `/ready` endpoint (5s initial delay, 5s interval)

### Metrics

The application exposes basic metrics through the `/health` endpoint:
- Application status
- Uptime
- Environment information
- Pod information

### Logging

- Structured logging with Morgan middleware
- Request/response logging
- Error logging with stack traces

## Scaling

### Horizontal Pod Autoscaler (HPA)

The application includes HPA configuration that automatically scales based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)
- Scale range: 2-10 replicas

### Manual Scaling

```bash
# Scale deployment manually
kubectl scale deployment k8s-web-app --replicas=5 -n production

# Or update Helm values
helm upgrade k8s-web-app ./helm --set replicaCount=5 -n production
```

## Troubleshooting

### Common Issues

1. **Pod not starting**:
   ```bash
   kubectl describe pod <pod-name> -n production
   kubectl logs <pod-name> -n production
   ```

2. **Health check failures**:
   ```bash
   kubectl get pods -n production
   kubectl logs <pod-name> -n production --previous
   ```

3. **Ingress not working**:
   ```bash
   kubectl get ingress -n production
   kubectl describe ingress k8s-web-app-ingress -n production
   ```

### Debug Commands

```bash
# Check application logs
kubectl logs -l app=k8s-web-app -n production

# Port forward for local testing
kubectl port-forward svc/k8s-web-app-service 8080:80 -n production

# Check resource usage
kubectl top pods -n production
kubectl top nodes
```

## Development

### Adding New Features

1. Update `server.js` with new routes/functionality
2. Add tests in `__tests__/` directory
3. Update Dockerfile if new dependencies are added
4. Update Kubernetes manifests if new environment variables or ports are needed
5. Update Helm values if configuration changes are required

### Testing

```bash
# Run tests
npm test

# Test health endpoints
curl http://localhost:3000/health
curl http://localhost:3000/ready
curl http://localhost:3000/api/info
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
