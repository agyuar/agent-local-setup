#!/bin/bash

# Agent Local Setup - Static Network Interface for k3s
# Creates a dummy interface (k3s-static) with a fixed IP (192.168.64.99)
# so the cluster keeps a stable node identity even if the WiFi/WAN IP changes.
#
# Idempotent: safe to run multiple times; creates the interface immediately AND
# persists it across reboots via a systemd service ordered before k3s.service.
#
# Usage:
#   ./setup-static-ip.sh          # create + enable
#   ./setup-static-ip.sh check    # only verify state, exit 0 if OK
#   ./setup-static-ip.sh remove   # tear down interface, service, and config

set -e

STATIC_IF="k3s-static"
STATIC_IP="192.168.64.99/24"
SVC_FILE="/etc/systemd/system/k3s-static-ip.service"
K3S_CONFIG="/etc/rancher/k3s/config.yaml"

ensure_iface() {
    sudo /sbin/modprobe dummy

    if ! ip link show "$STATIC_IF" &>/dev/null; then
        echo "🌐 Creating dummy interface $STATIC_IF..."
        sudo ip link add "$STATIC_IF" type dummy
    fi

    if ip -4 addr show dev "$STATIC_IF" | grep -qw "192.168.64.99"; then
        echo "🌐 Already holds 192.168.64.99 — OK."
    else
        sudo ip addr add "$STATIC_IP" dev "$STATIC_IF"
    fi

    sudo ip link set "$STATIC_IF" up
    echo "🌐 $STATIC_IF is UP with 192.168.64.99/24"
}

check_state() {
    local ok=1
    if ip link show "$STATIC_IF" &>/dev/null && ip -4 addr show dev "$STATIC_IF" | grep -qw "192.168.64.99"; then
        echo "✅ $STATIC_IF UP with 192.168.64.99"
    else
        echo "❌ $STATIC_IF missing or without 192.168.64.99"
        ok=0
    fi
    if [ -f "$K3S_CONFIG" ] && grep -q 'node-ip' "$K3S_CONFIG" 2>/dev/null; then
        echo "✅ k3s config.yaml has node-ip: $(grep node-ip "$K3S_CONFIG")"
    else
        echo "❌ k3s config.yaml missing node-ip (k3s will answer on the dynamic IP)"
        ok=0
    fi
    return $((1 - ok))
}

remove_setup() {
    echo "🧹 Removing $STATIC_IF and its service..."
    sudo systemctl disable --now k3s-static-ip.service 2>/dev/null || true
    sudo rm -f "$SVC_FILE"
    sudo ip link del "$STATIC_IF" 2>/dev/null || true
    if [ -f "$K3S_CONFIG" ]; then
        sed -i '/node-ip/d' "$K3S_CONFIG"
        rmdir "$(dirname "$K3S_CONFIG")" 2>/dev/null || true
    fi
    echo "✅ Removed."
}

case "${1:-}" in
    check)
        check_state
        ;;
    remove)
        remove_setup
        ;;
    "")
        ensure_iface
        echo "💾 Persisting via systemd (k3s-static-ip.service)..."
        sudo tee "$SVC_FILE" > /dev/null <<EOF
[Unit]
Description=Create static IP interface for k3s
Before=k3s.service
After=network.target

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe dummy
ExecStart=/sbin/ip link add $STATIC_IF type dummy
ExecStartPost=/sbin/ip addr add $STATIC_IP dev $STATIC_IF
ExecStartPost=/sbin/ip link set $STATIC_IF up
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable k3s-static-ip.service

        echo "⚙️  Pointing k3s at the static IP (config.yaml node-ip)..."
        sudo mkdir -p /etc/rancher/k3s
        # Merge-safe: replace existing node-ip line instead of clobbering the file
        if [ -f "$K3S_CONFIG" ] && grep -qE '^\s*node-ip:' "$K3S_CONFIG"; then
            sudo sed -i 's|^\s*node-ip:.*|node-ip: "192.168.64.99"|' "$K3S_CONFIG"
        else
            echo 'node-ip: "192.168.64.99"' | sudo tee -a "$K3S_CONFIG" > /dev/null
        fi

        if [ -d /etc/rancher/k3s ] && systemctl is-active k3s &>/dev/null; then
            echo "🔁 k3s is running — restart it so it binds the static IP..."
            sudo systemctl restart k3s
        else
            echo "⚠️  If k3s is already running, run: sudo systemctl restart k3s"
        fi

        check_state || true
        echo "✅ Static IP setup complete."
        ;;
    *)
        echo "Usage: $0 [check|remove]"
        exit 1
        ;;
esac
