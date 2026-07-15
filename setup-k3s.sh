#!/bin/bash

# Agent Local Setup - Lightweight Kubernetes Environment
# This script installs k3s without the default Traefik ingress controller.

set -e

echo "🚀 Starting agent-local-setup..."

# 1. Install k3s without traefik
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik

# 2. Set permissions for kubeconfig so it can be used by the current user
echo "🔑 Configuring kubectl permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# 3. Export KUBECONFIG for the current session (though usually added to .bashrc/.zshrc)
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "✅ Installation complete!"
echo "👉 Run 'sudo kubectl get nodes' to verify."
echo "💡 Tip: Add 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' to your shell profile."
