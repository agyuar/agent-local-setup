#!/bin/bash

# Agent Local Setup - Full Kubernetes & Service Mesh Environment
# This script automates the installation of k3s (without Traefik) and Istio.

set -e

echo "🚀 Starting full agent-local-setup..."

# --- 1. K3S INSTALLATION ---
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik

# Set permissions for kubeconfig so it can be used by the current user without sudo
echo "🔑 Configuring kubectl permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# --- 2. ISTIO INSTALLATION (via Helm) ---
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

# --- 3. INGRESS TRANSLATION SETUP ---
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
