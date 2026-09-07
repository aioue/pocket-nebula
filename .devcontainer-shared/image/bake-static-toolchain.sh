#!/usr/bin/env bash
# Bake the static Python toolchain into pocket-nebula-base at image build time.
#
# Replaces the devcontainer python and github-cli features plus the slow part of
# common/setup.sh. pyone and opennebula-cli stay in setup.sh because their
# versions track the live OpenNebula server.
set -euo pipefail

SYSTEM_PYTHON="/usr/bin/python3"
ANSIBLE_VENV="/usr/local/ansible-venv"
UV_BIN_DIR="/usr/local/py-utils/bin"

if [[ ! -x "$SYSTEM_PYTHON" ]]; then
    echo "ERROR: ${SYSTEM_PYTHON} not found" >&2
    exit 1
fi

echo "Creating shared Ansible venv (${SYSTEM_PYTHON})..."
mkdir -p "$ANSIBLE_VENV"
uv venv --python "$SYSTEM_PYTHON" --python-preference only-system "$ANSIBLE_VENV"

echo "Installing ansible, ansible-lint, passlib, pytest..."
uv pip install --python "${ANSIBLE_VENV}/bin/python" --python-preference only-system \
    ansible \
    ansible-lint \
    passlib \
    pytest

echo "Linking Ansible entry points into ${UV_BIN_DIR}..."
mkdir -p "$UV_BIN_DIR"
linked=0
for script in "${ANSIBLE_VENV}"/bin/*; do
    name="$(basename "$script")"
    case "$name" in
        python|python3|python3.*|activate*|pydoc*|pip|pip3|pip3.*) continue ;;
    esac
    [[ -x "$script" ]] || continue
    ln -sf "$script" "${UV_BIN_DIR}/${name}"
    linked=$((linked + 1))
done
echo "Linked ${linked} entry points"

echo "Installing ruff and pilfer..."
uv tool install ruff
uv tool install pilfer

echo "Static toolchain bake complete"
ansible --version | head -1
ruff --version
pilfer --version 2>/dev/null || true
