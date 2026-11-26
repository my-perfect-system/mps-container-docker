# mps-container-docker

Self-contained container image for the my-perfect-system (mps) Ansible
stack: a Debian image that installs the complete mps system **inside the
image at build time**, using only public repo links, and applies it with
the local ansible provider.

Everything the image needs is cloned/installed during the build — nothing
is baked in from local checkouts:

| Source (public link) | What it provides |
|---|---|
| `my-perfect-system-ansible/odem-*` (8 repos, via `requirements.yml` git links) | the `odem.*` Ansible collections |
| `my-perfect-system-ansible/playbook-example` | common playbooks + inventories |
| `my-perfect-system/mps-*` (cloned by the roles themselves) | per-user config/tool payloads |

The docker playbooks (`playbooks/docker_*.yml`) run at **build time**
against `[local] localhost` (`inventory_docker.ini`) — the resulting image
is a pre-baked system: every package installed, every config deployed, a
default `admin`/`admin` user created. `docker run -it mps` drops you into a
bash shell on that system.

## Install / Build

| Method | Description |
|---|---|
| Default | `bootstrap.sh` clones to the system-wide mps repo dir and runs `install.sh` (docker compose build) |
| Standalone | clone the repo, then run `./install.sh` inside it |

### Install (Default)

```bash
curl -fsSL https://raw.githubusercontent.com/my-perfect-system/mps-container-docker/main/bootstrap.sh | bash
```

Or directly via just:

```bash
just build        # docker compose build (image: mps)
```

Build args (with defaults, see `Dockerfile`):

| ARG | Default |
|---|---|
| `ANSIBLE_VERSION` | `2.21.3` |
| `JUST_VERSION` | `1.36.0` |
| `PLAYBOOK_REPO` | `https://github.com/my-perfect-system-ansible/playbook-example.git` |
| `PLAYBOOK_REF` | `main` |

## Usage

```bash
just run                       # bash shell on the pre-baked system
just run terminal_minimal.yml # re-apply a playbook via /entrypoint.sh
just shell                     # bash inside the running container
just up / just down            # compose lifecycle
docker compose run --rm mps bash
```

## Customization

Override the admin seed by mounting your own group_vars file on top of the
bundled one (see the commented volume in `docker-compose.yml`), or by adding
a `COPY` in the Dockerfile before the playbook runs. Lower numeric prefixes
in `group_vars/all/` win — `00-docker.yml` ships the default `admin` seed.

## Layout

| Path | Content |
|---|---|
| `Dockerfile` | the self-contained image build (public clones + build-time apply) |
| `docker-compose.yml` | compose service (`mps`), build args, tmpfs/cgroup mounts |
| `requirements.yml` | the 8 odem.* collections as git+https links |
| `inventory_docker.ini` | `[local] localhost` — the local ansible provider |
| `group_vars/all/00-docker.yml` | admin seed + `user_roles_default` profile |
| `playbooks/docker_bootstrap.yml` | `odem.os.{user,settings,packages,tools}` — user first |
| `playbooks/docker_terminal.yml` | the 10 terminal roles |
| `entrypoint.sh` | re-run a playbook inside a container |
| `bootstrap.sh` / `install.sh` | clone + `docker compose build` |
| `.github/workflows/publish.yml` | CI: build + push to Docker Hub `thebasimg/mps` |

## CI / Docker Hub

`.github/workflows/publish.yml` builds and pushes the image to
[`thebasimg/mps`](https://hub.docker.com/r/thebasimg/mps) on every push to
`main` (linux/amd64 only). Tags produced per build:

| Tag | When |
|---|---|
| `latest` | when `main` is the default branch |
| `sha-<short>` | every push |

Required repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub account (e.g. `thebasimg`) |
| `DOCKERHUB_TOKEN` | Docker Hub **access token** (not password) |

## Documentation

- [`AGENTS.md`](AGENTS.md) — design notes + conventions
- `../my-perfect-system-ansible/playbook-example/AGENTS.md` — cross-collection conventions

## License

GPL-3.0-or-later