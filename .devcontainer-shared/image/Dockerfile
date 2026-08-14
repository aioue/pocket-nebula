# syntax=docker/dockerfile:1.4
#
# Shared OpenNebula devcontainer base image.
#
# Published to ghcr.io/aioue/pocket-nebula-base and consumed by each project's
# thin .devcontainer/Dockerfile via `FROM ghcr.io/aioue/pocket-nebula-base:v1`.
# Consumers pin the MAJOR tag so an ordinary rebuild picks up shared fixes with
# no file edit; breaking changes get a new major tag.
#
# The devcontainer.metadata LABEL at the bottom is what makes this behave like
# the `extends` that devcontainer.json still does not have (devcontainers/spec#22).
# Properties declared there are merged with each repo's devcontainer.json, and
# the repo's own file wins on conflict.

# uv is pulled from its own published image rather than curl|sh, so the version
# is pinned and auditable. Declared as a named FROM stage (not an inline
# COPY --from=<url>) specifically so Dependabot's docker ecosystem sees it and
# opens a PR when a new uv is released.
FROM ghcr.io/astral-sh/uv:0.12.4 AS uv

FROM mcr.microsoft.com/devcontainers/base:noble

ARG USERNAME=vscode
ARG USER_HOME_PATH="/home/${USERNAME}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install shared system packages in a single layer.
# DEBIAN_FRONTEND=noninteractive prevents prompts during package installation.
#
# apt package versions are intentionally unpinned: devcontainer rebuilds should
# pick up current packages, and pinning would need ongoing maintenance for no
# meaningful stability benefit in a development container.
#
#   dnsutils        dig/host for DNS troubleshooting (pairs with the explicit
#                   --dns runArgs each consumer sets)
#   netcat-openbsd  nc, for quick TCP/UDP port checks
#   file, xxd       identifying and inspecting unknown/binary files
#   ripgrep         fast search
#   ruby-dev,
#   rubygems        needed to `gem install opennebula-cli` in setup.sh
#   shellcheck      backs the timonwong.shellcheck extension
#   just            task runner; each project's justfile wraps the long
#                   ansible-playbook invocations so flags cannot be mistyped
#
# BuildKit cache mounts keep the downloaded .debs across rebuilds, so editing
# anything below this layer refetches nothing. sharing=locked because apt takes
# its own lock and concurrent builds must not interleave. Note the deliberate
# absence of `apt-get clean` and the /var/lib/apt/lists removal: with a cache
# mount those paths are not part of the image layer, so cleaning them would only
# discard the cache that makes the next build fast.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache \
    && apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        apt-utils \
        curl \
        dialog \
        dnsutils \
        file \
        just \
        netcat-openbsd \
        plocate \
        ripgrep \
        ruby-dev \
        rubygems \
        shellcheck \
        xxd \
    && rm -rf /tmp/* /var/tmp/*

# uv - a drop-in pip/pipx replacement that resolves and installs an order of
# magnitude faster. common/setup.sh uses it for the whole Python toolchain, which
# is the bulk of container-create time.
#
# UV_TOOL_BIN_DIR is pointed at the same directory the devcontainer python
# feature uses for pipx binaries, so tools land where PATH already looks and the
# shared "ruff.path": ["/usr/local/py-utils/bin/ruff"] setting stays correct.
ENV UV_TOOL_BIN_DIR=/usr/local/py-utils/bin \
    UV_LINK_MODE=copy
COPY --from=uv /uv /usr/local/bin/uv
RUN mkdir -p /usr/local/py-utils/bin && chown -R ${USERNAME} /usr/local/py-utils && uv --version

# Shell environment and persistent bash history.
# Follows the devcontainer guidance at
# https://code.visualstudio.com/remote/advancedcontainers/persist-bash-history
#
# Interactive terminals and agent (non-interactive) shells get SEPARATE history
# files, so an agent's command stream does not pollute the history you page
# through by hand, and vice versa.
#
# Note: pipx tab-completion is deliberately NOT wired into .bashrc here. It is
# installed to /etc/bash_completion.d/ by common/shell-completions.sh instead,
# because devcontainer features regenerate ~/.bashrc and would drop it.
RUN <<SHELL
set -euo pipefail
mkdir -p ${USER_HOME_PATH}/.one
cat <<'HIST_EOF' | tee -a /root/.bashrc ${USER_HOME_PATH}/.bashrc > /dev/null

# Persistent history for interactive shells (not exported - agent shells use their own file)
HISTFILE=/commandhistory/.bash_history_user
HISTSIZE=5000
HISTFILESIZE=5000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND='history -a'
HIST_EOF
mkdir -p /usr/local/etc
cat > /usr/local/etc/devcontainer-bash-env.sh <<'BASH_ENV_EOF'
# Sourced via BASH_ENV for every non-interactive bash process (agent shells).
# Interactive shells skip this entirely and use .bashrc instead.
case $- in *i*) return 0 ;; esac

# Agent shell history (separate from interactive terminals)
HISTFILE=/commandhistory/.bash_history_agent
HISTSIZE=1000
HISTFILESIZE=1000
HISTCONTROL=ignoredups:erasedups

# Load OpenNebula credentials/endpoints if available (written by common/setup.sh).
# This is one of four channels that carry the same env file; the others are
# /etc/profile.d (login shells), ~/.bashrc (interactive non-login) and
# /etc/environment (processes started with a clean environment).
ONE_ENV=/home/vscode/.config/opennebula/env.sh
# shellcheck source=/dev/null
[ -f "$ONE_ENV" ] && . "$ONE_ENV"
BASH_ENV_EOF
mkdir -p /commandhistory
touch /commandhistory/.bash_history_user /commandhistory/.bash_history_agent
chown -R ${USERNAME} /commandhistory
SHELL

# ---------------------------------------------------------------------------
# Dev container metadata
# ---------------------------------------------------------------------------
# Merged with each consumer's devcontainer.json by the dev containers spec:
#   mounts       collected as a list (last source wins on conflict)
#   containerEnv last value wins
#   lifecycle    all collected, image entries run before the repo's own
#   customizations  merging is left to the tool
# The consumer's devcontainer.json is considered last, so it always overrides.
#
# Deliberately NOT here: build, runArgs, features and name, which the spec does
# not support in image metadata. Those are also precisely the site-specific
# settings (DNS resolvers, --env-file, feature selection), so they stay per repo.
#
# Do NOT escape the ${localEnv:HOME} references below as \${...}. Inside a
# single-quoted LABEL value Docker passes ${localEnv:HOME} through verbatim -
# it neither expands it nor objects to the ':' - whereas a backslash is kept
# literally and produces "Invalid \escape", silently breaking the whole label.
# Verified by building both forms and inspecting the result.
LABEL devcontainer.metadata='[{ \
  "containerEnv": { \
    "BASH_ENV": "/usr/local/etc/devcontainer-bash-env.sh", \
    "ANSIBLE_FORCE_COLOR": "1", \
    "PY_COLORS": "1", \
    "FORCE_COLOR": "1", \
    "CLICOLOR_FORCE": "1" \
  }, \
  "mounts": [ \
    "type=bind,source=${localEnv:HOME}/.ssh,target=/home/vscode/.ssh", \
    "type=bind,source=${localEnv:HOME}/.one,target=/home/vscode/.one,readonly", \
    "type=bind,source=${localEnv:HOME}/.ansible-vault,target=/home/vscode/.ansible-vault,readonly" \
  ], \
  "onCreateCommand": "echo Container created, preparing for setup...", \
  "postCreateCommand": ".devcontainer/common/setup.sh", \
  "postStartCommand": ".devcontainer/common/show-opennebula-config.sh", \
  "postAttachCommand": ".devcontainer/common/fix-cursor-python-extensions.sh", \
  "customizations": { \
    "vscode": { \
      "extensions": [ \
        "redhat.ansible", \
        "charliermarsh.ruff", \
        "timonwong.shellcheck", \
        "docker.docker", \
        "DavidAnson.vscode-markdownlint" \
      ], \
      "settings": { \
        "terminal.integrated.defaultProfile.linux": "bash", \
        "files.watcherExclude": { \
          "**/.git/**": true, \
          "**/.ansible/**": true, \
          "**/roles/**/.git/**": true \
        }, \
        "ansible.python.interpreterPath": "/usr/bin/python3", \
        "ansible.validation.lint.enabled": true, \
        "ansible.validation.lint.path": "ansible-lint", \
        "python.languageServer": "None", \
        "python.useEnvironmentsExtension": true, \
        "python.defaultInterpreterPath": "/usr/bin/python3", \
        "[python]": { \
          "editor.formatOnSave": true, \
          "editor.codeActionsOnSave": { \
            "source.fixAll.ruff": "explicit", \
            "source.organizeImports.ruff": "explicit" \
          }, \
          "editor.defaultFormatter": "charliermarsh.ruff" \
        }, \
        "ruff.enable": true, \
        "ruff.lint.enable": true, \
        "ruff.format.enable": true, \
        "ruff.fixAll": true, \
        "ruff.organizeImports": true, \
        "ruff.showSyntaxErrors": true, \
        "ruff.path": ["/usr/local/py-utils/bin/ruff"], \
        "markdownlint.run": "onType", \
        "files.associations": { \
          "*.py": "python", \
          "*.pyi": "python", \
          "*.mdc": "markdown" \
        } \
      } \
    } \
  } \
}]'
