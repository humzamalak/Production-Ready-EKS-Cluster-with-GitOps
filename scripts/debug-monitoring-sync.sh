#!/bin/bash
# Debug script for Grafana and Prometheus sync issues
# Usage: ./scripts/debug-monitoring-sync.sh [environment]

set -e

ENVIRONMENT="${1:-dev}"
NAMESPACE="argocd"

echo "========================================"
echo "Debugging Monitoring Stack Sync Issues"
echo "Environment: $ENVIRONMENT"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${NC}"
    exit 1
fi

# Check if ArgoCD is running
echo "1. Checking ArgoCD installation..."
if kubectl get namespace argocd &> /dev/null; then
    echo -e "${GREEN}✓ ArgoCD namespace exists${NC}"
else
    echo -e "${RED}✗ ArgoCD namespace not found${NC}"
    exit 1
fi

ARGOCD_PODS=$(kubectl get pods -n argocd 2>/dev/null | grep -c "Running" || echo "0")
echo "   ArgoCD pods running: $ARGOCD_PODS"
echo ""

# Check applications
echo "2. Checking Grafana and Prometheus applications..."
echo ""

for APP in grafana-${ENVIRONMENT} prometheus-${ENVIRONMENT}; do
    echo "   Checking: $APP"
    echo "   -----------------------------------"
    
    if kubectl get application $APP -n argocd &> /dev/null; then
        echo -e "   ${GREEN}✓ Application exists${NC}"
        
        # Get sync status
        SYNC_STATUS=$(kubectl get application $APP -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        HEALTH_STATUS=$(kubectl get application $APP -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        if [ "$SYNC_STATUS" == "Synced" ]; then
            echo -e "   ${GREEN}✓ Sync Status: $SYNC_STATUS${NC}"
        else
            echo -e "   ${RED}✗ Sync Status: $SYNC_STATUS${NC}"
        fi
        
        if [ "$HEALTH_STATUS" == "Healthy" ]; then
            echo -e "   ${GREEN}✓ Health Status: $HEALTH_STATUS${NC}"
        else
            echo -e "   ${YELLOW}⚠ Health Status: $HEALTH_STATUS${NC}"
        fi
        
        # Get detailed status
        echo ""
        echo "   Detailed Status:"
        kubectl get application $APP -n argocd -o jsonpath='{.status.conditions}' 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "   No conditions found"
        
        # Get sync error if exists
        echo ""
        echo "   Sync Error (if any):"
        kubectl get application $APP -n argocd -o jsonpath='{.status.operationState.message}' 2>/dev/null || echo "   No sync errors"
        
        # Get source information
        echo ""
        echo "   Sources:"
        kubectl get application $APP -n argocd -o jsonpath='{.spec.sources[*].repoURL}' 2>/dev/null || echo "   Unable to get sources"
        
    else
        echo -e "   ${RED}✗ Application not found${NC}"
    fi
    
    echo ""
    echo ""
done

# Check if monitoring namespace exists
echo "3. Checking monitoring namespace..."
MONITORING_NS="${ENVIRONMENT}-monitoring"
if kubectl get namespace $MONITORING_NS &> /dev/null; then
    echo -e "${GREEN}✓ Namespace $MONITORING_NS exists${NC}"
    
    # Check pods in monitoring namespace
    echo ""
    echo "   Pods in $MONITORING_NS:"
    kubectl get pods -n $MONITORING_NS -o wide 2>/dev/null || echo "   No pods found"
else
    echo -e "${YELLOW}⚠ Namespace $MONITORING_NS does not exist${NC}"
    echo "   This is expected if applications haven't synced yet"
fi
echo ""

# Check AppProject
echo "4. Checking AppProject..."
APP_PROJECT="${ENVIRONMENT}-apps"
if kubectl get appproject $APP_PROJECT -n argocd &> /dev/null; then
    echo -e "${GREEN}✓ AppProject $APP_PROJECT exists${NC}"
    
    # Check source repos
    echo ""
    echo "   Allowed source repositories:"
    kubectl get appproject $APP_PROJECT -n argocd -o jsonpath='{.spec.sourceRepos[*]}' 2>/dev/null | tr ' ' '\n' | sed 's/^/   - /'
else
    echo -e "${RED}✗ AppProject $APP_PROJECT not found${NC}"
fi
echo ""

# Refresh applications
echo "5. Refreshing applications (forcing sync)..."
echo ""
read -p "Do you want to refresh Grafana and Prometheus applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    for APP in grafana-${ENVIRONMENT} prometheus-${ENVIRONMENT}; do
        if kubectl get application $APP -n argocd &> /dev/null; then
            echo "   Refreshing $APP..."
            kubectl patch application $APP -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' 2>/dev/null && \
                echo -e "   ${GREEN}✓ Refresh triggered for $APP${NC}" || \
                echo -e "   ${RED}✗ Failed to refresh $APP${NC}"
        fi
    done
    echo ""
    echo "   Waiting 5 seconds for refresh to process..."
    sleep 5
    
    # Check status again
    echo ""
    echo "   Updated status:"
    for APP in grafana-${ENVIRONMENT} prometheus-${ENVIRONMENT}; do
        if kubectl get application $APP -n argocd &> /dev/null; then
            SYNC_STATUS=$(kubectl get application $APP -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
            echo "   $APP: $SYNC_STATUS"
        fi
    done
fi
echo ""

# Show recent ArgoCD logs
echo "6. Recent ArgoCD application controller logs:"
echo "   (showing last 20 lines related to grafana/prometheus)"
echo ""
kubectl logs -n argocd deployment/argocd-application-controller --tail=100 2>/dev/null | \
    grep -i -E "(grafana|prometheus)" | tail -20 || \
    echo "   Unable to fetch logs or no relevant entries found"
echo ""

echo "========================================"
echo "Debug Complete"
echo "========================================"
echo ""
echo "Next Steps:"
echo "1. If sync status is 'OutOfSync', try manual sync from ArgoCD UI"
echo "2. Check application logs: kubectl logs -n $MONITORING_NS <pod-name>"
echo "3. View ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "4. Force hard refresh: argocd app get <app-name> --hard-refresh"
echo ""

