# AGENTS.md — mps-container-docker

Self-contained container image for the my-perfect-system (mps) Ansible
stack. Builds a Debian image that installs the complete mps system inside
the image at **build time**, using only **public repo links**, applied via
the **local ansible provider**. Moved here (2026-11) from the
`my-perfect-system-ansible/docker/` wrapper directory (not a git repo).

## Self-contained build — public links only

The Dockerfile clones/installs everything from public GitHub URLs — no
local odem/* checkouts are involved:

| Step | Source |
|---|---|
| odem.* collections | `requirements.yml` git links → the 8 public `my-perfect-system-ansible/odem-*` repos (Galaxy publishing pending) |
| Galaxy dependencies | `ansible.posix community.general community.crypto` |
| common playbooks + inventories | `git clone` of the public `playbook-example` repo → `/opt/playbook-example` |
| mps-* config/tool repos | cloned by the roles themselves (public URLs) while the playbooks run |

The two playbooks (`playbooks/docker_*.yml`) then apply against
`[local] localhost` (`inventory_docker.ini`, `ansible_connection=local`) —
the local ansible provider. Result: a pre-baked system image.

## Image layout

```
/opt/playbook-example/               # git clone of the public playbook repo
  └─ inventories/home/               # WORKDIR
      ├─ ansible.cfg                 # from the clone (collections_path)
      ├─ inventory_docker.ini        # COPYed from this repo — [local] localhost
      ├─ group_vars/all/00-docker.yml # COPYed — admin seed
      └─ playbooks/docker_*.yml      # COPYed — build-time playbooks

/usr/share/ansible/collections/     # ANSIBLE_COLLECTIONS_PATH
  ├─ ansible/posix/ community/general/ community/crypto/
  └─ odem/{os,terminal,development,desktop,hardening,backup,services,alloy}/

/etc/ansible/ansible.cfg            # baked by Dockerfile (collections_path etc.)
/entrypoint.sh                       # re-run a playbook inside a container
```

## Conventions

- **Playbooks run at build time** — `RUN ansible-playbook -i
  inventory_docker.ini playbooks/docker_*.yml` inside the Dockerfile. Both
  steps tolerate non-zero exits (`|| true`) so the build completes even when
  systemd-managed steps or transient network downloads fail.
- **`docker_bootstrap.yml` runs `odem.os.user` FIRST** (identity resolve +
  user creation) — ahead of settings/packages/tools — so `/home/admin`
  exists when the terminal roles deploy per-user dotfiles; the upstream
  `bootstrap.yml` order hits a systemd lock without init PID 1 in a Docker
  build.
- **Local provider** — localhost only, `ansible_connection=local`,
  `ansible_python_interpreter=/usr/bin/python3`.
- **Identity seed** — `group_vars/all/00-docker.yml` ships one admin user
  (`admin`/`admin`) with full `user_roles_default` and sudo macros. Override
  by mounting your own file at the same path; lower numeric prefixes in
  `group_vars/all/` win (00- loads first, later files override scalars).
- **Base image `debian:latest`** (per project owner decision) — a moving
  target; roles assert Debian 13 (trixie). Pin `debian:trixie` if a stable
  target is required.
- Historical hacks from the pre-merge wrapper were **dropped**: the
  `ANSIBLE_FILTER_PLUGINS` env override (filters now route correctly via
  `odem-os/plugins/filter/`) and the `argument_specs.yml` deletion for
  `odem.base.identity` (the merged `odem.os.user` spec declares
  `user_catalog` as a free-form dict — the dict-of-dicts validation problem
  is solved upstream).

## Justfile

`build` (docker compose build), `run [playbook]` (bash or re-apply a
playbook via `/entrypoint.sh`), `shell`, `config`, `up`/`down`. The former
`docker-{build,run,shell}` targets of `manage/Justfile` moved here.

## CI

`.github/workflows/publish.yml` pushes to Docker Hub `thebasimg/mps`
(`latest` + `sha-<short>`) on every push to `main`; needs
`DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` repo secrets.

## Cross-references

- `manage/AGENTS.md` — collections, conventions, publishing path
- `playbook-example/` — the playbook/inventory repo the image clones