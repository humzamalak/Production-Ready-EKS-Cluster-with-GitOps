#!/bin/bash

# Multi-Architecture Build and Push Script for K8s Web App to DockerHub
# Builds for linux/amd64 and linux/arm64 architectures
# Usage: ./build-and-push.sh [tag]

set -e

# Configuration
DOCKERHUB_USERNAME="windrunner101"
IMAGE_NAME="k8s-web-app"
DEFAULT_TAG="latest"
TAG=${1:-$DEFAULT_TAG}
PLATFORMS="linux/amd64,linux/arm64"

# Get git commit SHA for additional tagging (if in git repo)
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Full image name
FULL_IMAGE_NAME="${DOCKERHUB_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "🚀 Building and pushing Multi-Arch K8s Web App to DockerHub"
echo "============================================================="
echo "Image: ${FULL_IMAGE_NAME}"
echo "Platforms: ${PLATFORMS}"
echo "Git SHA: ${GIT_SHA}"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if buildx is available
echo "🔍 Checking Docker Buildx..."
if ! docker buildx version > /dev/null 2>&1; then
    echo "❌ Docker Buildx is not available."
    echo "Please install Docker Buildx: https://docs.docker.com/buildx/working-with-buildx/"
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

# Create buildx builder if it doesn't exist
BUILDER_NAME="multi-arch-builder"
if ! docker buildx inspect "${BUILDER_NAME}" > /dev/null 2>&1; then
    echo "🏗️  Creating multi-arch builder..."
    docker buildx create --name "${BUILDER_NAME}" --use
    docker buildx inspect --bootstrap
else
    echo "✅ Using existing builder: ${BUILDER_NAME}"
    docker buildx use "${BUILDER_NAME}"
fi

# Prepare build tags
BUILD_TAGS="-t ${FULL_IMAGE_NAME}"
if [ "$TAG" != "latest" ]; then
    BUILD_TAGS="${BUILD_TAGS} -t ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
fi
if [ "$GIT_SHA" != "unknown" ]; then
    BUILD_TAGS="${BUILD_TAGS} -t ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:sha-${GIT_SHA}"
fi

# Build and push multi-architecture image
echo ""
echo "🔨 Building multi-architecture Docker image..."
echo "This may take several minutes due to cross-platform emulation..."
echo ""

docker buildx build \
    --platform "${PLATFORMS}" \
    ${BUILD_TAGS} \
    --push \
    .

echo ""
echo "✅ Successfully built and pushed multi-arch image:"
echo "   ${FULL_IMAGE_NAME}"
if [ "$TAG" != "latest" ]; then
    echo "   ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:latest"
fi
if [ "$GIT_SHA" != "unknown" ]; then
    echo "   ${DOCKERHUB_USERNAME}/${IMAGE_NAME}:sha-${GIT_SHA}"
fi
echo ""

# Inspect the manifest to verify multi-arch support
echo "🔍 Verifying multi-architecture manifest..."
docker buildx imagetools inspect "${FULL_IMAGE_NAME}"

echo ""
echo "🔗 DockerHub URL: https://hub.docker.com/r/${DOCKERHUB_USERNAME}/${IMAGE_NAME}"
echo ""
echo "📝 Next steps:"
echo "   1. Update your Kubernetes manifests to use: ${FULL_IMAGE_NAME}"
echo "   2. Deploy using ArgoCD or Helm"
echo "   3. Verify deployment with: kubectl get pods -n production"
echo ""
echo "💡 Tip: Use specific version tags (not 'latest') in production for better traceability"
