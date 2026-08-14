#!/bin/bash
# Install bash tab-completion for Ansible and other CLIs used in this devcontainer.
# Writes scripts to /etc/bash_completion.d/ so completions survive devcontainer
# feature regeneration of ~/.bashrc (same pattern as /etc/profile.d/opennebula.sh).
set -e

COMPLETION_DIR="/etc/bash_completion.d"

_install_argcomplete() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "  ⏭️  Skipping ${cmd} (not installed)"
        return 0
    fi
    if ! command -v register-python-argcomplete >/dev/null 2>&1; then
        echo "  ⚠️  register-python-argcomplete not found, skipping ${cmd}"
        return 0
    fi
    register-python-argcomplete -s bash "$cmd" | sudo tee "${COMPLETION_DIR}/${cmd}" >/dev/null
    echo "  ✓ ${cmd}"
}

_install_generated() {
    local name="$1"
    shift
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "  ⏭️  Skipping ${name} ($1 not installed)"
        return 0
    fi
    "$@" | sudo tee "${COMPLETION_DIR}/${name}" >/dev/null
    echo "  ✓ ${name}"
}

echo "🐚 Installing shell completions to ${COMPLETION_DIR}..."

# Ansible CLI tools (python-argcomplete; installed into the shared uv venv by
# setup.sh and symlinked onto PATH)
ANSIBLE_COMMANDS=(
    ansible
    ansible-playbook
    ansible-galaxy
    ansible-inventory
    ansible-vault
    ansible-config
    ansible-doc
    ansible-pull
    ansible-console
    ansible-lint
)
for cmd in "${ANSIBLE_COMMANDS[@]}"; do
    _install_argcomplete "$cmd"
done

# pipx still ships with the devcontainer python feature even though setup.sh now
# uses uv, so its completion is still worth installing.
# (argcomplete; was previously wired only in the Dockerfile .bashrc)
_install_argcomplete pipx

# Ruff ships its own completion generator (uv tool install, not in apt bash-completion)
_install_generated ruff ruff generate-shell-completion bash

# gh, ripgrep, and git completions ship with their apt packages under
# /usr/share/bash-completion/completions/ and load via the system bash-completion hook.

echo "✅ Shell completions installed"
