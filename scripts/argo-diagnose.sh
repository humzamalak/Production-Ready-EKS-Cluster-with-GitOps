#!/bin/bash

# -------------------------------
# Argo CD Auto-Connect Script
# -------------------------------

# 1️⃣ Kill any process using local port 8080
echo "[1/5] Checking for processes using port 8080..."
PID=$(netstat -aon | grep 8080 | awk '{print $5}' | tail -n 1)
if [ -n "$PID" ]; then
    echo "Killing process $PID using port 8080..."
    cmd.exe /c "taskkill /PID $PID /F"
else
    echo "No process using port 8080."
fi

# 2️⃣ Find first argocd-server pod
echo "[2/5] Finding Argo CD server pod..."
ARGOCD_POD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath="{.items[0].metadata.name}")
if [ -z "$ARGOCD_POD" ]; then
    echo "❌ No argocd-server pod found!"
    exit 1
fi
echo "Found pod: $ARGOCD_POD"

# 3️⃣ Start port-forward directly to pod in background
echo "[3/5] Starting port-forward to pod 443 -> local 8080..."
kubectl port-forward pod/$ARGOCD_POD -n argocd 8080:443 > /dev/null 2>&1 &
PF_PID=$!
echo "Port-forward PID: $PF_PID"
sleep 5 # wait a few seconds to ensure port-forward is active

# 4️⃣ Login to Argo CD CLI
echo "[4/5] Waiting for port-forward to be ready..."
while ! nc -z 127.0.0.1 8080; do
  sleep 1
done

echo "Port 8080 ready, logging in..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login 127.0.0.1:8080 --username admin --password "$ARGOCD_PASSWORD" --insecure

# 5️⃣ List all applications
echo "[5/5] Listing all Argo CD applications..."
argocd app list

echo "✅ Done. Keep the port-forward terminal open while using the CLI."
