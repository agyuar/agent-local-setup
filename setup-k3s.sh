#!/bin/bash

# Agent Local Setup - Lightweight Kubernetes Environment
# This script installs k3s without the default Traefik ingress controller and sets up a static node IP
# to avoid cluster issues during network changes (e.g., WiFi crashes).

set -e

echo "🚀 Starting agent-local-setup..."

# 1. Setup Static Network Interface for k3s Stability
# (handled by the idempotent shared script: creates the dummy interface NOW,
# persists it via systemd, and sets k3s node-ip in config.yaml)
echo "🌐 Configuring static dummy interface for k3s stability..."
bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/setup-static-ip.sh"

# 2. Install k3s without traefik
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik

# 4. Set permissions for kubeconfig so it can be used by the current user
echo "🔑 Configuring kubectl permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# 5. Export KUBECONFIG for the current session
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "✅ Installation complete!"
echo "👉 Run 'sudo kubectl get nodes' to verify (node IP should be 192.168.64.99)."
echo "💡 Tip: Add 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' to your shell profile."
echo "🔄 If k3s was already running before the interface existed: sudo systemctl restart k3s"
echo "✅ The interface is idempotent and persists across reboots (k3s-static-ip.service)."
