#!/bin/bash

# Agent Local Setup - Full Kubernetes & Service Mesh Environment
# This script automates the installation of k3s (without Traefik) and Istio.

set -e

echo "🚀 Starting full agent-local-setup..."

# --- 1. STATIC NETWORK INTERFACE (k3s must answer on a stable IP) ---
echo "🌐 Configuring static dummy interface for k3s..."
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup-static-ip.sh"

# --- 2. K3S INSTALLATION ---
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik

# Set permissions for kubeconfig so it can be used by the current user without sudo
echo "🔑 Configuring kubectl permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# If k3s was already running before the static interface existed, restart it
# so it (re)binds to 192.168.64.99.
if systemctl is-active --quiet k3s; then
  K3S_NODE_IP=$(sudo -n k3s kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)
  if [ "$K3S_NODE_IP" != "192.168.64.99" ]; then
    echo "🔄 k3s node IP is $K3S_NODE_IP — restarting k3s to bind the static IP..."
    sudo systemctl restart k3s
  fi
fi

# --- 3. ISTIO INSTALLATION (via Helm) ---
echo "🌐 Installing Istio Service Mesh via Helm..."

# Ensure KUBECONFIG is available for helm
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Add Istio Helm repository
sudo KUBECONFIG=$KUBECONFIG helm repo add istio https://istio-release.storage.googleapis.com/charts
sudo KUBECONFIG=$KUBECONFIG helm repo update

# Install Istio Base (CRDs)
echo "📦 Installing Istio Base..."
sudo KUBECONFIG=$KUBECONFIG helm install istio-base istio/base -n istio-system --create-namespace

# Install Istiod (Control Plane)
echo "🧠 Installing Istiod..."
sudo KUBECONFIG=$KUBECONFIG helm install istiod istio/istiod -n istio-system --wait

# Install Istio Ingress Gateway
echo "🚪 Installing Istio Ingress Gateway..."
sudo KUBECONFIG=$KUBECONFIG helm install istio-ingressgateway istio/gateway -n istio-system

# --- 4. INGRESS TRANSLATION SETUP ---
echo "🪄 Configuring Istio Ingress translation (IngressClass)..."
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: istio
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: istio.io/ingress-controller
EOF

echo "✅ Installation complete!"
echo "------------------------------------------------------------"
echo "👉 VERIFICATION:"
echo "   - Run 'sudo kubectl get nodes' to check cluster status."
echo "   - Run 'sudo kubectl get pods -n istio-system' to check Istio."
echo ""
echo "💡 ENVIRONMENT CONFIGURATION:"
echo "   To use the tools without sudo, add these to your ~/.bashrc or ~/.zshrc:"
echo "   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "   export PATH=\"\$PATH:$BIN_PATH\""
echo "------------------------------------------------------------"
