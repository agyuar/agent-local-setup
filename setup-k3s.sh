#!/bin/bash

# Agent Local Setup - Lightweight Kubernetes Environment
# This script installs k3s without the default Traefik ingress controller and sets up a static node IP
# to avoid cluster issues during network changes (e.g., WiFi crashes).

set -e

echo "🚀 Starting agent-local-setup..."

# 1. Setup Static Network Interface for k3s Stability
echo "🌐 Configuring static dummy interface for k3s stability..."
sudo tee /etc/systemd/system/k3s-static-ip.service <<EOF
[Unit]
Description=Create static IP interface for k3s
Before=k3s.service
After=network.target

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe dummy
ExecStart=/sbin/ip link add k3s-static type dummy
ExecStartPost=/sbin/ip addr add 192.168.64.99/24 dev k3s-static
ExecStartPost=/sbin/ip link set k3s-static up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable k3s-static-ip.service

# 2. Configure k3s to use the static IP
echo "⚙️  Configuring k3s node identity..."
sudo mkdir -p /etc/rancher/k3s
echo 'node-ip: "192.168.64.99"' | sudo tee /etc/rancher/k3s/config.yaml

# 3. Install k3s without traefik
echo "📦 Installing k3s (without Traefik)..."
curl -sfL https://get.k3s.io | sudo sh -s - server --disable traefik

# 4. Set permissions for kubeconfig so it can be used by the current user
echo "🔑 Configuring kubectl permissions..."
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

# 5. Export KUBECONFIG for the current session
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "✅ Installation complete!"
echo "👉 Run 'sudo kubectl get nodes' to verify."
echo "💡 Tip: Add 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' to your shell profile."
echo "⚠️  A reboot is recommended to ensure the static network interface is fully active before k3s starts."
