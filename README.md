# agent-local-setup

A professional local Kubernetes environment designed for AI Agent development and network testing.

## 🎯 Objective
This setup provides a lightweight, high-performance cluster that avoids the "magic" of default ingress controllers (like Traefik), replacing them with a production-grade Service Mesh (**Istio**). This allows agents to be developed in an environment where networking, traffic routing, and security can be explicitly defined.

## 🛠️ Components
- **k3s**: Lightweight Kubernetes distribution (Traefik disabled).
- **Istio**: Service Mesh for advanced traffic management, observability, and security.
- **k3s-static interface**: A dummy interface (`192.168.64.99/24`) so the cluster keeps a stable node identity even if the WiFi/WAN IP changes.

## 🌐 Static IP (k3s node identity)
The setup creates a dummy interface `k3s-static` with `192.168.64.99` and points k3s at it via `node-ip` in `/etc/rancher/k3s/config.yaml`. This is what `setup-env.sh` and `setup-k3s.sh` do internally, but you can manage it standalone:

```bash
./setup-static-ip.sh          # create interface + persist via systemd + set node-ip
./setup-static-ip.sh check    # verify state (read-only), exit 0 if healthy
./setup-static-ip.sh remove   # tear down interface, service, and config
```
The script is **idempotent**, persists across reboots via `k3s-static-ip.service` (ordered before `k3s.service`), and restarts k3s if needed so it actually (re)binds the static IP.

## 🚀 Quick Start

1. **Run the automated setup**:
   ```bash
   chmod +x setup-env.sh
   ./setup-env.sh
   ```

2. **Configure your shell profile**:
   To avoid using `sudo` for every command, add these lines to your `.bashrc` or `.zshrc`:
   ```bash
   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
   # Replace [ISTIO_PATH] with the actual path printed by the script
   export PATH="$PATH:[ISTIO_PATH]/bin" 
   ```

3. **Verification**:
   ```bash
   kubectl get nodes
   kubectl get pods -n istio-system
   ```

## 📡 Networking & Ingress Support
This environment is optimized for testing multi-interface connectivity and high-grade traffic management.

### Classic Ingress Compatibility
Unlike a standard Istio installation, this setup includes an **IngressClass** named `istio`. This allows you to install traditional Helm charts that use the standard Kubernetes `Ingress` resource without modification. 

Just ensure your chart's values are set to:
`ingressClassName: istio`

Istio will automatically translate these classic resources into its own routing logic in real-time.

## 📝 Notes
- **No Traefik**: We explicitly disable Traefik during k3s installation to prevent conflicts with Istio and to force a "clean slate" networking architecture.
- **Demo Profile**: The script installs the `demo` profile of Istio, which is intended for testing and development (includes most features enabled).
