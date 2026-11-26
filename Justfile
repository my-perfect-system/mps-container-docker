# Justfile — mps-container-docker
#
# Build/run the mps container image. The image is fully self-contained:
# build-time clones from public repo links (see Dockerfile) install the
# odem.* collections + the playbook-example playbooks inside the image and
# apply them via the local ansible provider.

# Build the image (docker compose build; extra args pass through)
build *args:
    docker compose build {{args}}

# Run a fresh container from the image.
#   just run                       # bash shell on the pre-baked system
#   just run terminal_minimal.yml # re-apply a playbook via /entrypoint.sh
run playbook='bash' *extra_args:
    #!/usr/bin/env bash
    set -uo pipefail
    if [ "{{playbook}}" = bash ]; then
        exec docker run --rm -it --privileged \
            -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
            --tmpfs /run --tmpfs /tmp --tmpfs /var/log \
            {{extra_args}} mps
    fi
    exec docker run --rm -it --privileged \
        -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
        --tmpfs /run --tmpfs /tmp --tmpfs /var/log \
        {{extra_args}} mps /entrypoint.sh "{{playbook}}"

# Bash inside the running container (or a fresh one when stopped)
shell *extra_args:
    #!/usr/bin/env bash
    set -uo pipefail
    docker compose exec mps bash {{extra_args}} \
        || docker run --rm -it --privileged \
            -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
            --tmpfs /run --tmpfs /tmp --tmpfs /var/log \
            {{extra_args}} mps bash

# Validate the compose file + Dockerfile build args (no build)
config:
    docker compose config

# Start / stop the compose service (CMD: tail -f /dev/null)
up *args:
    docker compose up -d {{args}}

down *args:
    docker compose down {{args}}