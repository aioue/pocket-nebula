[![base image](https://github.com/aioue/pocket-nebula/actions/workflows/base-image.yml/badge.svg)](https://github.com/aioue/pocket-nebula/actions/workflows/base-image.yml)
[![release](https://github.com/aioue/pocket-nebula/actions/workflows/release.yml/badge.svg)](https://github.com/aioue/pocket-nebula/actions/workflows/release.yml)
[![latest release](https://img.shields.io/github/v/release/aioue/pocket-nebula?sort=semver)](https://github.com/aioue/pocket-nebula/releases)
[![ghcr image](https://img.shields.io/badge/ghcr.io-pocket--nebula--base-2496ED?logo=docker&logoColor=white)](https://github.com/aioue/pocket-nebula/pkgs/container/pocket-nebula-base)
[![dev container](https://img.shields.io/badge/dev%20container-ready-1f425f?logo=visualstudiocode&logoColor=white)](https://containers.dev/)
[![license](https://img.shields.io/github/license/aioue/pocket-nebula)](LICENSE)

# Pocket Nebula ✨→👖

A dev container for working against [OpenNebula](https://opennebula.io/) with Ansible - and a
**shared devcontainer layer** that several projects can consume without copy-pasting between them.

Use it two ways:

1. **As a skeleton.** Clone it, point it at your OpenNebula, start working.
2. **As an upstream.** Have your own repos pull the shared layer from here, so an improvement made
   in one project reaches the others.

<div align="center">
  <img width="577" alt="Console build output" src="https://github.com/user-attachments/assets/06ce9b2d-4e4f-4787-91a0-0235908d906b" />
</div>

---

## What is Pocket Nebula?

`devcontainer.json` has no `extends`, and the requests for one
([spec#22](https://github.com/devcontainers/spec/issues/22),
[spec#716](https://github.com/devcontainers/spec/issues/716),
[vscode-remote-release#11421](https://github.com/microsoft/vscode-remote-release/issues/11421))
are all still open. So teams running several similar projects copy a `.devcontainer/` between
repos and it quietly diverges - each repo ends up ahead of the others in different places.

This repo solves that with the two mechanisms the spec *does* provide.

| Layer | What it holds | How a change reaches consumers |
|---|---|---|
| **A. Base image** | apt packages, `uv`, shell history wiring, and a `devcontainer.metadata` label carrying shared mounts, extensions, settings and lifecycle hooks | `FROM ghcr.io/aioue/pocket-nebula-base:v1` — one ordinary rebuild |
| **B. Shared scripts** | `setup.sh` and helpers, vendored into each repo at `.devcontainer/common/` | `initializeCommand` sync, which runs **before the build** — same rebuild, no second one |
| **C. Per-repo config** | `name`, `build`, `runArgs`, `features` — the things that genuinely differ | edited by hand; a drift checker warns about duplication |

The key detail is ordering. `initializeCommand` runs **on the host, before the image is built**, so
a shared-layer change is fetched and in place for the build and `postCreateCommand` of the *same*
create cycle. You never rebuild, notice drift, and have to rebuild again.

Layer A works because the dev containers spec merges an image's `devcontainer.metadata` label with
each repo's `devcontainer.json` — with the repo's file taking precedence. That is `extends` in
everything but name.

---

## Using it as a skeleton

### Prerequisites

- Docker (Desktop, Colima, or equivalent)
- VS Code or Cursor with the Dev Containers extension
- Credentials for an OpenNebula deployment

### 1. Provide credentials on the host

Credentials live in `~/.one/` on your machine and are bind-mounted **read-only** into the
container. They are never copied into the repo and never written to the workspace.

For each deployment, create a matching pair, where `<SUFFIX>` is a short label of your choosing:

```bash
mkdir -p ~/.one

# Credentials, in user:password form
printf 'myuser:mypassword' > ~/.one/one_auth_PROD
chmod 600 ~/.one/one_auth_PROD

# Endpoints, as shell variable assignments
cat > ~/.one/one_url_PROD <<'EOF'
ONE_URL=https://cloud.example.com/RPC2
ONE_XMLRPC=https://cloud.example.com/RPC2
ONEFLOW_URL=https://cloud.example.com:2474
EOF
```

Optionally, for encrypted Ansible content:

```bash
mkdir -p ~/.ansible-vault
printf 'my-vault-password' > ~/.ansible-vault/vault-password
chmod 600 ~/.ansible-vault/vault-password
```

### 2. Select the deployment

Set the suffix in `.devcontainer/site.env`:

```bash
OPENNEBULA_DEPLOYMENT_ENVIRONMENT=PROD
```

This is deliberately a committed, per-repo setting rather than an interactive prompt. If several
deployments share one OpenNebula instance, a mis-selection would silently operate as the *wrong
user* instead of failing — so the choice is pinned per repo. Set
`ONE_ALLOW_INTERACTIVE_SELECT=1` if you would rather be asked each time.

### 3. Open in the container

Open the folder in VS Code or Cursor and choose **Reopen in Container**. On first create it will:

- refresh `.devcontainer/common/` from this repo (falling back to the committed copy if offline)
- select credentials and export them through four channels, so login shells, interactive
  terminals, agent shells and bare subprocesses all see the same values
- detect the OpenNebula server version and install a matching CLI gem and PyONE
- install Ansible, ansible-lint, ruff and pilfer with `uv`

### 4. Check it works

```bash
onevm list                     # OpenNebula CLI
onehost list                   # exercises a different CLI code path
ansible --version
.devcontainer/common/show-opennebula-config.sh
```

---

## Using it as an upstream

To have your own repo consume this shared layer:

1. Copy `.devcontainer-shared/scripts/sync-common.sh` to `your-repo/.devcontainer/sync-common.sh`. This is the only file
   you ever copy — it changes almost never.
2. Add `.devcontainer/common.ref` containing the ref to track (a tag such as `v1.2.0`, or `main`).
3. Copy the templates from `.devcontainer-shared/templates/` to `.devcontainer/` and edit `site.env`.
4. Point `.devcontainer/Dockerfile` at `FROM ghcr.io/aioue/pocket-nebula-base:v1`.
5. In `devcontainer.json`, set `"initializeCommand": ".devcontainer/sync-common.sh"` and keep only
   `name`, `build`, `runArgs` and `features` — everything else comes from the image.

Run a rebuild and `.devcontainer/common/` is populated. Commit it: it is vendored deliberately, so
a fresh clone works with no extra steps and no network.

### Version pinning

Consumers pin the **major** image tag (`:v1`), so ordinary rebuilds pick up fixes with no file
edit. A breaking change gets a new major tag, which every consumer must adopt explicitly.

`common.ref` is separate, and controls the scripts. A tag or SHA is treated as immutable and
skipped when already in sync; a branch name is re-fetched on every container start.

### Controlling the sync

| `POCKET_NEBULA_SYNC` | Behaviour |
|---|---|
| unset / `prompt` | Ask before applying, when a terminal is attached; apply silently otherwise |
| `auto` | Always apply without asking |
| `never` | Never apply; keep the vendored copy |

---

## Layout

```
.devcontainer/                    This repo's own consumer config (a worked example)
.devcontainer-shared/             Everything that serves the shared layer to other repos
  common/                         Source of truth for the shared scripts (vendored into consumers)
  image/                          The base image and its devcontainer.metadata label
  scripts/sync-common.sh          The bootstrap file each consumer copies once
  templates/                      site.env / devcontainer.env / .dockerignore starting points
```

### Shared scripts

| Script | Purpose |
|---|---|
| `setup.sh` | Credential selection, environment wiring, toolchain install |
| `detect-opennebula-version.sh` | Asks the server its version, derives matching CLI and PyONE specs |
| `opennebula-cli-tools-patch.sh` | Compatibility stubs for older CLI gems; self-retiring |
| `show-opennebula-config.sh` | Prints resolved configuration and tests connectivity |
| `shell-completions.sh` | Installs completions to `/etc/bash_completion.d/` |
| `fix-cursor-python-extensions.sh` | Works around Cursor installing universal Python extension builds |
| `check-devcontainer-drift.sh` | Warns when a repo duplicates what the image already provides |

---

## Releases

Commits follow [Conventional Commits](https://www.conventionalcommits.org/). `release-please`
maintains a release PR with a generated `CHANGELOG.md`; merging it tags a release, which publishes
a new base image and moves the `:v1` tag. Dependabot keeps the base image and actions current and
auto-merges everything except major bumps.

So the full chain is hands-free:

```
conventional commit → release PR → merge → tag → image published → consumers pick it up on rebuild
```

---

## Notes

- **Credentials never enter the workspace.** The generated environment file lives at
  `~/.config/opennebula/env.sh` inside the container. It is deliberately *not* in `.devcontainer/`,
  which is a bind mount from the host — a plaintext password there would land on the host
  filesystem inside a git repo, and `chmod 600` is not reliably enforced across the mount.
- **`~/.one` is mounted read-only**, so the selected auth file is copied to `~/.one_auth` and
  `ONE_AUTH` points there.
- **Version detection is live.** The CLI gem and PyONE versions are derived from the running
  server. `site.env` fallbacks apply only when the server is unreachable.

## License

[Apache 2.0](LICENSE)
