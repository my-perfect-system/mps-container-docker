#!/usr/bin/env bash
# Build the mps container image (docker compose build — image name `mps`,
# see docker-compose.yml). Idempotent: layers are cached; a rebuild only
# picks up changed build args / Dockerfile / copied files.
#
# The image build is fully self-contained: it clones/installs the public
# odem.* collection repos + the playbook-example repo and applies the
# playbooks inside the build (local ansible provider). No local odem/*
# checkouts are involved — public repo links only.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SRC"

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is required (docker compose build)"
    exit 1
fi

docker compose build