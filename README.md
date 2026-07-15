# agent-local-setup

A professional local Kubernetes environment designed for AI Agent development and network testing.

## 🎯 Objective
This setup provides a lightweight, high-performance cluster that avoids the "magic" of default ingress controllers (like Traefik), replacing them with a production-grade Service Mesh (**Istio**). This allows agents to be developed in an environment where networking, traffic routing, and security can be explicitly defined.

## 🛠️ Components
- **k3s**: Lightweight Kubernetes distribution (Traefik disabled).
- **Istio**: Service Mesh for advanced traffic management, observability, and security.

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

## 📡 Networking Capabilities
This environment is optimized for testing multi-interface connectivity (e.g., Local LAN vs. VPN). By using the Istio Ingress Gateway, you can route traffic based on specific hosts or IPs, making it ideal for agents that need to be reachable across different network boundaries.

## 📝 Notes
- **No Traefik**: We explicitly disable Traefik during k3s installation to prevent conflicts with Istio and to force a "clean slate" networking architecture.
- **Demo Profile**: The script installs the `demo` profile of Istio, which is intended for testing and development (includes most features enabled).
