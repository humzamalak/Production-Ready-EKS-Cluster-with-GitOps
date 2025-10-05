#!/bin/bash

# Build and Push Script for K8s Web App to DockerHub
# Usage: ./build-and-push.sh [tag]

set -e

# Configuration
DOCKERHUB_USERNAME="windrunner101"
IMAGE_NAME="k8s-web-app"
DEFAULT_TAG="latest"
TAG=${1:-$DEFAULT_TAG}

# Full image name
FULL_IMAGE_NAME="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "🚀 Building and pushing K8s Web App to DockerHub"
echo "================================================"
echo "Image: ${FULL_IMAGE_NAME}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if logged in to DockerHub
echo "🔐 Checking DockerHub login status..."
if ! docker info | grep -q "Username: ${DOCKERHUB_USERNAME}"; then
    echo "⚠️  Not logged in to DockerHub as ${DOCKERHUB_USERNAME}"
    echo "Please run: docker login"
    echo "Enter your DockerHub username: ${DOCKERHUB_USERNAME}"
    echo "Enter your DockerHub password/token"
    echo ""
    read -p "Press Enter to continue after logging in..."
fi

# Build the Docker image
echo "🔨 Building Docker image..."
docker build -t "${FULL_IMAGE_NAME}" .

# Also tag as latest if not already
if [ "$TAG" != "latest" ]; then
    docker tag "${FULL_IMAGE_NAME}" "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
fi

# Push the image
echo "📤 Pushing image to DockerHub..."
docker push "${FULL_IMAGE_NAME}"

if [ "$TAG" != "latest" ]; then
    docker push "${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
fi

echo ""
echo "✅ Successfully built and pushed:"
echo "   ${FULL_IMAGE_NAME}"
if [ "$TAG" != "latest" ]; then
    echo "   ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
fi
echo ""
echo "🔗 DockerHub URL: https://hub.docker.com/r/${DOCKERHUB_USERNAME}/${IMAGE_NAME}"
echo ""
echo "📝 Next steps:"
echo "   1. Update your Kubernetes manifests to use: ${FULL_IMAGE_NAME}"
echo "   2. Deploy using ArgoCD or Helm"
echo "   3. Verify deployment with: kubectl get pods -n production"
