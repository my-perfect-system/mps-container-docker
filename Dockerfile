# syntax=docker/dockerfile:1.7
# mps-container-docker — self-contained image build for the my-perfect-system
# (mps) Ansible stack. Everything needed inside the image comes from PUBLIC
# repo links cloned/installed at build time:
#   - the odem.* collections from the public my-perfect-system-ansible repos
#     (requirements.yml git links; Galaxy publishing pending)
#   - the common playbooks + inventories from the public playbook-example repo
#   - the mps-* config/tool repos, cloned by the roles themselves from their
#     public URLs while the playbooks run
# The playbooks are applied at BUILD time via the local ansible provider
# ([local] localhost in inventory_docker.ini).
FROM debian:latest

ARG ANSIBLE_VERSION=2.21.3
ARG JUST_VERSION=1.36.0
ARG PLAYBOOK_REPO=https://github.com/my-perfect-system-ansible/playbook-example.git
ARG PLAYBOOK_REF=main

ENV DEBIAN_FRONTEND=noninteractive
# Collections install target — the odem.* collections install here from
# requirements.yml (git links into the public repos).
ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        git \
        make \
        curl \
        ca-certificates \
        gnupg \
        python3 \
        python3-pip \
        python3-venv \
        sudo \
        vim \
        locales \
        systemd \
        systemd-sysv \
        dbus \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install --break-system-packages --no-cache-dir \
        "ansible-core==${ANSIBLE_VERSION}" \
        ansible

RUN set -eux; \
    curl -fsSL -o /tmp/just.tar.gz \
        "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-x86_64-unknown-linux-musl.tar.gz"; \
    tar -C /usr/local/bin -xzf /tmp/just.tar.gz just; \
    chmod +x /usr/local/bin/just; \
    rm -f /tmp/just.tar.gz; \
    just --version

# odem.* collections from the public GitHub repos + Galaxy dependencies.
COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml \
        -p "${ANSIBLE_COLLECTIONS_PATH}" \
 && ansible-galaxy collection install \
        ansible.posix community.general community.crypto \
        -p "${ANSIBLE_COLLECTIONS_PATH}" \
 && rm -f /tmp/requirements.yml

# Common playbooks + inventories from the public playbook-example repo.
RUN git clone --depth=1 --branch "${PLAYBOOK_REF}" "${PLAYBOOK_REPO}" /opt/playbook-example

RUN mkdir -p /etc/ansible \
 && printf "[defaults]\nstdout_callback = default\ncallback_result_format = yaml\ncallback_format_pretty = False\nnocows = True\ncollections_path = %s\nhost_key_checking = False\nretry_files_enabled = False\ninterpreter_python = auto_silent\ndeprecation_warnings = False\n" \
        "${ANSIBLE_COLLECTIONS_PATH}" \
    > /etc/ansible/ansible.cfg

# Container-specific inventory + admin seed, layered onto the cloned
# home inventory (alphanumeric group_vars/all/ load order puts 00-docker.yml first).
COPY inventory_docker.ini /opt/playbook-example/inventories/home/
COPY group_vars/ /opt/playbook-example/inventories/home/group_vars/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

COPY playbooks/docker_bootstrap.yml /opt/playbook-example/inventories/home/playbooks/
COPY playbooks/docker_terminal.yml /opt/playbook-example/inventories/home/playbooks/

WORKDIR /opt/playbook-example/inventories/home

# Apply at build time via the local provider. Bootstrap first — user creation
# before the systemd-locked steps so /home/admin exists when the terminal
# roles deploy per-user dotfiles. Both steps tolerate non-zero exits so the
# build completes even when systemd-managed or network-dependent tasks fail.
RUN ansible-playbook -i inventory_docker.ini playbooks/docker_bootstrap.yml || true \
 && ansible-playbook -i inventory_docker.ini playbooks/docker_terminal.yml || true

# Generate en_US.UTF-8 locale (must uncomment in locale.gen first)
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
 && locale-gen en_US.UTF-8 \
 && update-locale LANG=en_US.UTF-8

# Set environment variables for the runtime
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

USER admin
WORKDIR /home/admin

CMD ["/bin/bash", "-c", "tail -f /dev/null"]