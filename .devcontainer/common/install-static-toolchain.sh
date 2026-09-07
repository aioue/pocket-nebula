#!/usr/bin/env bash
# Install the static Python/Ansible toolchain (image bake or setup.sh fallback).
#
# Bakes ansible, ansible-lint, passlib, pytest and pilfer into a shared venv,
# and ruff as a uv tool. pyone stays in setup.sh because its version tracks the
# live OpenNebula server.
set -euo pipefail

SYSTEM_PYTHON="/usr/bin/python3"
ANSIBLE_VENV="/usr/local/ansible-venv"
UV_BIN_DIR="${UV_TOOL_BIN_DIR:-/usr/local/py-utils/bin}"
UV_TOOL_DIR="${UV_TOOL_DIR:-/usr/local/uv-tools}"

export UV_TOOL_BIN_DIR="$UV_BIN_DIR"
export UV_TOOL_DIR
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"
export UV_NO_PROGRESS="${UV_NO_PROGRESS:-1}"

_run() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

if [[ ! -x "$SYSTEM_PYTHON" ]]; then
    echo "ERROR: ${SYSTEM_PYTHON} not found" >&2
    exit 1
fi

echo "Installing static toolchain (${SYSTEM_PYTHON})..."
_run mkdir -p "$ANSIBLE_VENV" "$UV_BIN_DIR" "$UV_TOOL_DIR"
if [[ "$(id -u)" -ne 0 ]]; then
    # setup.sh fallback: sudo mkdir leaves root-owned parents; uv needs write access.
    _run chown -R "$(id -u):$(id -g)" "$ANSIBLE_VENV" "$UV_BIN_DIR" "$UV_TOOL_DIR"
fi

if [[ ! -x "${ANSIBLE_VENV}/bin/python" ]]; then
    uv venv --python "$SYSTEM_PYTHON" --python-preference only-system "$ANSIBLE_VENV"
fi

echo "Installing ansible, ansible-lint, passlib, pytest, pilfer..."
uv pip install --python "${ANSIBLE_VENV}/bin/python" --python-preference only-system \
    ansible \
    ansible-lint \
    passlib \
    pytest \
    pilfer

echo "Linking Ansible entry points into ${UV_BIN_DIR}..."
linked=0
for script in "${ANSIBLE_VENV}"/bin/*; do
    name="$(basename "$script")"
    case "$name" in
        python|python3|python3.*|activate*|pydoc*|pip|pip3|pip3.*) continue ;;
    esac
    [[ -x "$script" ]] || continue
    _run ln -sf "$script" "${UV_BIN_DIR}/${name}"
    linked=$((linked + 1))
done
echo "Linked ${linked} entry points"

echo "Installing ruff..."
uv tool install --force ruff

echo "Static toolchain install complete"
"${ANSIBLE_VENV}/bin/ansible" --version | head -1
"${UV_BIN_DIR}/ruff" --version
"${ANSIBLE_VENV}/bin/pilfer" --version
