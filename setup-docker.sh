#!/bin/bash

# Agent Local Setup - Docker Engine + Local Registry Client
# Instala Docker Engine, da permisos al usuario y configura el daemon para
# hablar con los registries locales (Pluma: 192.168.64.99:32000, Deck: localhost:32000).
# Idempotente: seguro re-lanzarlo tras un upgrade.

set -e

# IP/ports de nuestros registries NodePort (ajusta si cambian)
REGISTRIES='{"192.168.64.99:32000","192.168.21.146:32000","192.168.64.1:32000","localhost:32000","127.0.0.1:32000"}'

echo "🐳 Installing Docker Engine..."

if ! command -v docker >/dev/null 2>&1; then
  # Prereqs (lsb-release se usa abajo para resolver el codename)
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg lsb-release

  # 2. GPG key de Docker
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

  # 3. Repositorio oficial (codename real de la distro, ej. noble/resolute)
  #    Una sola línea: los list files de dos líneas rompen con dpkg >= 1.22.6 (Ubuntu 24.10+).
  CODENAME=$(lsb_release -cs 2>/dev/null || . /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # 4. Instalación
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 5. Permisos de usuario (evitar sudo en cada docker)
if ! id -nG "$(id -un)" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$USER"
  echo "ℹ️  '$USER' añadido al grupo docker. En esta sesión: newgrp docker (o re-conecta SSH)."
fi

# 6. Daemon: registries locales sin TLS (merge, no sobreescribe config existente)
mkdir -p /etc/docker
REG_JSON="/etc/docker/daemon.json"
if [ ! -f "$REG_JSON" ]; then echo '{}' | sudo tee "$REG_JSON" >/dev/null; fi
if command -v python3 >/dev/null 2>&1; then
  sudo python3 - "$REG_JSON" "$REGISTRIES" <<'PYEOF'
import json, sys
path, regs = sys.argv[1], sys.argv[2].strip('{}').replace('"','').split(',')
with open(path) as f: cfg = json.load(f)
cur = cfg.get('insecure-registries', [])
for r in regs:
    r = r.strip()
    if r and r not in cur: cur.append(r)
cfg['insecure-registries'] = cur
import tempfile, os
fd, tmp = tempfile.mkstemp(dir='/etc/docker'); os.write(fd, json.dumps(cfg, indent=2).encode()); os.close(fd)
os.chmod(tmp, 0o644); os.replace(tmp, path)
print('daemon.json ->', cfg)
PYEOF
else
  echo "⚠️  python3 no disponible: añade manualmente insecure-registries a /etc/docker/daemon.json"
fi

# 7. (Re)arrancar servicios
sudo systemctl enable --now docker
sudo systemctl restart docker

echo "✅ Docker listo: $(docker version --format '{{.Server.Version}}' 2>/dev/null || docker version --format 'CLI ok')"
echo "👉 Insecure registries configurados:"
docker info --format '{{.InsecureRegistries}}' 2>/dev/null || true
echo "💡 Uso rápido:
   FROM scratch + un COPY en una Dockerfile basta para 'crear' una imagen;
   docker build -t 192.168.64.99:32000/miproj/hello .
   docker push 192.168.64.99:32000/miproj/hello"
