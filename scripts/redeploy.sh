#!/bin/bash
# Redeployment Master Script
# This script orchestrates the complete redeployment process
# Author: Production-Ready EKS Cluster with GitOps Team
# Date: 2025-10-07

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   GitOps Redeployment Master Script                          ║${NC}"
echo -e "${BLUE}║   Production-Ready EKS Cluster with GitOps                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Phase 1: Check prerequisites
echo -e "${BLUE}Phase 1: Checking Prerequisites...${NC}"

# Check if on correct branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "fix/gitops-deployment-failures" ]; then
    echo -e "${RED}❌ Not on correct branch. Current: $CURRENT_BRANCH${NC}"
    echo -e "${YELLOW}Run: git checkout fix/gitops-deployment-failures${NC}"
    exit 1
fi
echo -e "${GREEN}✅ On correct branch: $CURRENT_BRANCH${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running${NC}"
    echo -e "${YELLOW}Please start Docker Desktop and try again${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is running${NC}"

# Check if buildx is available
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker Buildx is not available${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker Buildx available${NC}"

# Check Docker Hub login
echo -e "${YELLOW}⚠️  Checking Docker Hub login...${NC}"
if ! docker info 2>/dev/null | grep -q "Username"; then
    echo -e "${RED}❌ Not logged into Docker Hub${NC}"
    echo -e "${YELLOW}Please run: docker login${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Logged into Docker Hub${NC}"

echo ""
echo -e "${BLUE}Phase 2: Building Multi-Arch Docker Image...${NC}"
echo -e "${YELLOW}⚠️  This will take 10-15 minutes${NC}"
echo ""

# Navigate to web-app directory
cd examples/web-app

# Run the build script
if bash build-and-push.sh v1.0.0; then
    echo -e "${GREEN}✅ Docker build completed successfully${NC}"
else
    echo -e "${RED}❌ Docker build failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Phase 3: Verifying Multi-Arch Manifest...${NC}"

# Verify multi-arch manifest
MANIFEST_OUTPUT=$(docker buildx imagetools inspect windrunner101/k8s-web-app:latest 2>&1)

if echo "$MANIFEST_OUTPUT" | grep -q "linux/amd64" && echo "$MANIFEST_OUTPUT" | grep -q "linux/arm64"; then
    echo -e "${GREEN}✅ Multi-arch manifest verified:${NC}"
    echo "$MANIFEST_OUTPUT" | grep "Platform:"
else
    echo -e "${RED}❌ Multi-arch manifest incomplete${NC}"
    echo "$MANIFEST_OUTPUT"
    exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ BUILD PHASE COMPLETE                                     ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo -e "1. ${YELLOW}Create Pull Request:${NC}"
echo -e "   Visit: https://github.com/humzamalak/Production-Ready-EKS-Cluster-with-GitOps/pull/new/fix/gitops-deployment-failures"
echo -e "   Copy content from: PR_DESCRIPTION.md"
echo ""
echo -e "2. ${YELLOW}After PR approval, merge it${NC}"
echo ""
echo -e "3. ${YELLOW}Trigger ArgoCD sync:${NC}"
echo -e "   argocd app sync -l environment=prod"
echo ""
echo -e "4. ${YELLOW}Monitor deployment:${NC}"
echo -e "   argocd app list | grep prod"
echo -e "   kubectl get pods -n monitoring"
echo -e "   kubectl get pods -n production"
echo ""
echo -e "${GREEN}🎉 Ready for deployment!${NC}"
