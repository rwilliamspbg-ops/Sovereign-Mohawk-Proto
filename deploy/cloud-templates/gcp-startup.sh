#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg lsb-release git

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

mkdir -p /opt
cd /opt
if [[ ! -d Sovereign-Mohawk-Proto ]]; then
  git clone https://github.com/rwilliamspbg-ops/Sovereign-Mohawk-Proto.git
fi

cd Sovereign-Mohawk-Proto
docker compose up -d orchestrator node-agent-1 prometheus grafana

echo "Sovereign-Mohawk bootstrap complete"
docker compose ps
