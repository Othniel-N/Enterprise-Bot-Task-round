#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="demo"
NAMESPACE="demo"
RELEASE_NAME="demo"
IMAGE_NAME="enterprisebot-demo"
IMAGE_TAG="1.0.0"

echo " Enterprise Bot demo setup"

# 1. Check required tools

echo "[1/7] Checking prerequisites..."

for cmd in docker kind kubectl helm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: '$cmd' is not installed or not available in PATH."
    exit 1
  fi
done

echo "All required tools are available."



# 2. Create kind cluster if it does not exist

echo "[2/7] Checking kind cluster..."

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster '$CLUSTER_NAME' already exists."
else
  echo "Creating kind cluster '$CLUSTER_NAME'..."
  kind create cluster --name "$CLUSTER_NAME"
fi



# 3. Install ingress-nginx

echo "[3/7] Installing ingress-nginx..."

if kubectl get namespace ingress-nginx >/dev/null 2>&1; then
  echo "ingress-nginx namespace already exists."
else
  kubectl apply -f \
    https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
fi

echo "Waiting for ingress-nginx controller..."

kubectl wait \
  --namespace ingress-nginx \
  --for=condition=Ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s



# 4. Build application image

echo "[4/7] Building Docker image..."

docker build \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  ./service



# 5. Load image into kind

echo "[5/7] Loading image into kind..."

kind load docker-image \
  "${IMAGE_NAME}:${IMAGE_TAG}" \
  --name "$CLUSTER_NAME"



# 6. Create namespace and deploy Helm chart

echo "[6/7] Deploying Helm chart..."

kubectl create namespace "$NAMESPACE" \
  --dry-run=client \
  -o yaml | kubectl apply -f -

helm upgrade --install "$RELEASE_NAME" ./chart \
  --namespace "$NAMESPACE" \
  --set image.repository="$IMAGE_NAME" \
  --set image.tag="$IMAGE_TAG"



# 7. Wait for deployment

echo "[7/7] Waiting for application..."

kubectl rollout status \
  deployment/"$RELEASE_NAME" \
  --namespace "$NAMESPACE" \
  --timeout=120s


echo ""
echo "======================================"
echo " Setup completed successfully"
echo "======================================"

kubectl get pods -n "$NAMESPACE"
kubectl get service -n "$NAMESPACE"
kubectl get ingress -n "$NAMESPACE"