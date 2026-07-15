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

# --- 2. ISTIO INSTALLATION ---
echo "🌐 Installing Istio Service Mesh..."
ISTIO_DIR="$HOME/.openclaw/workspace/istio-setup"
mkdir -p "$ISTIO_DIR"
cd "$ISTIO_DIR"

# Download and extract Istio
curl -L https://istio.io/downloadIstio | sh -

# Find the extracted version directory
VERSION_DIR=$(ls -d istio-* | head -n 1)
BIN_PATH="$ISTIO_DIR/$VERSION_DIR/bin"

if [ -z "$BIN_PATH" ]; then
    echo "❌ Istio binary not found!"
    exit 1
fi

# Add istioctl to PATH for the duration of this script
export PATH="$PATH:$BIN_PATH"

# Install Istio using the demo profile (all features enabled)
echo "🧠 Applying Istio Demo Profile..."
sudo KUBECONFIG=/etc/rancher/k3s/k3s.yaml "$BIN_PATH/istioctl" install --set profile=demo -y

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
