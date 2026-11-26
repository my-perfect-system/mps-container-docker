#!/usr/bin/env bash
# Re-run a playbook inside a running container (or a fresh one):
#   docker run --rm -it mps /entrypoint.sh terminal_minimal.yml
set -euo pipefail
cd /opt/playbook-example/inventories/home
exec ansible-playbook -i inventory_docker.ini playbooks/"$1"