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

# 0. Base tooling (idempotent): make is needed by several downstream builds
#    (kustomize, local images, the blog toolchain, etc.)
echo "🔧 Ensuring base tooling (make)..."
sudo apt-get update -q 2>/dev/null || true
sudo apt-get install -y make

# 2. Install k3s without traefik
#    The admin kubeconfig is written 640 root:adm (--write-kubeconfig-mode/-group),
#    so members of the `adm` group can use kubectl WITHOUT sudo.
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik \
  --write-kubeconfig-mode 640 --write-kubeconfig-group adm

# 3. Make sure the current user can read the kubeconfig (group adm)
echo "🔑 Checking adm group membership for $(whoami)..."
if id -nG "$(whoami)" | tr ' ' '\n' | grep -qx adm; then
  echo "✅ $(whoami) is in adm — kubectl works without sudo."
else
  echo "⚠️  $(whoami) is NOT in adm — adding..."
  sudo usermod -aG adm "$(whoami)"
  echo "   (group membership applies from the next login)"
fi

# 4. Export KUBECONFIG for the current session
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "✅ Installation complete!"
echo "👉 Run 'kubectl get nodes' to verify (no sudo needed, node IP should be 192.168.64.99)."
echo "💡 Tip: Add 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' to your shell profile."
echo "🔄 If k3s was already running before the interface existed: sudo systemctl restart k3s"
echo "✅ The interface is idempotent and persists across reboots (k3s-static-ip.service)."
