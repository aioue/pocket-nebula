#!/bin/bash
# Shared OpenNebula devcontainer setup.
#
# This file is the single source of truth, vendored into consumer repos at
# .devcontainer/common/setup.sh by sync-common.sh. Do NOT edit it in a consumer
# repo - changes there are overwritten on the next container create. Edit it in
# pocket-nebula and let the sync carry it across.
#
# Everything site-specific is read from .devcontainer/site.env, or injected via
# the optional .devcontainer/site/pre-setup.sh and post-setup.sh hooks.
set -e  # Exit on any error

echo "🚀 Setting up development environment..."

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$COMMON_DIR")"
SITE_ENV="${DEVCONTAINER_DIR}/site.env"
SITE_DIR="${DEVCONTAINER_DIR}/site"

# ---------------------------------------------------------------------------
# Site configuration
# ---------------------------------------------------------------------------
# site.env carries everything that legitimately differs between institutes:
# the deployment suffix, version fallbacks, SSH aliases, and opt-in toggles.
# It is sourced with `set -a` so every assignment is exported for child tools.
if [[ -f "$SITE_ENV" ]]; then
    echo "🏷️  Loading site configuration from $SITE_ENV"
    set -a
    # shellcheck source=/dev/null
    source "$SITE_ENV"
    set +a
else
    echo "⚠️  No site.env found at $SITE_ENV - using defaults."
fi

# Upsert KEY=VALUE in /etc/environment (read by PAM for all processes, including
# non-login VS Code terminals and bare subprocess invocations).
_pin_etc_environment() {
    local key="$1"
    local value="$2"
    [[ -n "$value" ]] || return 0
    if grep -q "^${key}=" /etc/environment 2>/dev/null; then
        sudo sed -i "s|^${key}=.*|${key}=${value}|" /etc/environment
    else
        echo "${key}=${value}" | sudo tee -a /etc/environment >/dev/null
    fi
}

# Run an optional site hook if the consumer repo provides one.
_run_site_hook() {
    local hook="${SITE_DIR}/$1"
    if [[ -x "$hook" ]]; then
        echo "🪝 Running site hook: $1"
        "$hook"
    elif [[ -f "$hook" ]]; then
        echo "⚠️  Site hook $1 exists but is not executable - skipping."
    fi
}

_run_site_hook pre-setup.sh

# ---------------------------------------------------------------------------
# Credential selection
# ---------------------------------------------------------------------------
# Deployment is chosen deterministically from OPENNEBULA_DEPLOYMENT_ENVIRONMENT
# (set per repo in .devcontainer/site.env). We deliberately do NOT offer an
# interactive picker by default: institutes on this campus authenticate against
# the SAME shared OpenNebula instance, so a mis-selection would silently operate
# as the wrong user rather than failing loudly.
#
# Set ONE_ALLOW_INTERACTIVE_SELECT=1 in site.env to opt back into the picker.
#
# For the chosen SUFFIX there should be a matching pair in ~/.one/:
#   one_auth_<SUFFIX>  - credentials in user:password format
#   one_url_<SUFFIX>   - shell variable assignments (ONE_URL, ONE_XMLRPC, ONEFLOW_URL)
# The ~/.one bind-mount is read-only, so the selected auth file is written to
# ~/.one_auth (home directory) and ONE_AUTH is set to point there.
# ---------------------------------------------------------------------------

ONE_DIR="/home/vscode/.one"
BASHRC_PATH="$HOME/.bashrc"

# The env file deliberately lives in the container's home directory, NOT in
# .devcontainer/. That directory is a bind mount from the host, so a plaintext
# ONE_PASSWORD there would land on the host filesystem inside a git repo, would
# survive rebuilds, and chmod 600 is not reliably enforced across the mount.
ONE_ENV_DIR="$HOME/.config/opennebula"
ONE_ENV_FILE="${ONE_ENV_DIR}/env.sh"
mkdir -p "$ONE_ENV_DIR"
touch "$ONE_ENV_FILE"
chmod 600 "$ONE_ENV_FILE"

SUFFIX="${OPENNEBULA_DEPLOYMENT_ENVIRONMENT:-}"
AUTH_FILE=""

if [[ "${ONE_ALLOW_INTERACTIVE_SELECT:-0}" == "1" ]]; then
    # Opt-in picker. Scans ~/.one for one_auth_* and prompts. Only enable this
    # where operating as the wrong user is an inconvenience rather than a hazard.
    AUTH_FILES=("${ONE_DIR}"/one_auth_*)
    if [[ ${#AUTH_FILES[@]} -eq 0 || ! -f "${AUTH_FILES[0]}" ]]; then
        echo "⚠️  No one_auth_* files found in ${ONE_DIR}."
        echo "   Create ${ONE_DIR}/one_auth_<SUFFIX> and ${ONE_DIR}/one_url_<SUFFIX>."
    else
        echo ""
        echo "🔑 Available OpenNebula credential sets:"
        for i in "${!AUTH_FILES[@]}"; do
            # Show the suffix only (e.g. QIB, EI) rather than the full path
            echo "  $((i+1))) ${AUTH_FILES[$i]##*one_auth_}"
        done

        # postCreateCommand runs without a TTY, so we can't use bash's `select` builtin
        # (it reads from stdin which may be /dev/null in the devcontainer lifecycle).
        # Read directly from /dev/tty, which is always the user's terminal regardless of
        # how stdin is wired up by VS Code during postCreate.
        echo ""
        printf "Enter number [1-%d]: " "${#AUTH_FILES[@]}"
        read -r CHOICE </dev/tty

        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && (( CHOICE >= 1 && CHOICE <= ${#AUTH_FILES[@]} )); then
            AUTH_FILE="${AUTH_FILES[$((CHOICE-1))]}"
        else
            echo "⚠️  Invalid selection. Defaulting to first available: ${AUTH_FILES[0]##*one_auth_}"
            AUTH_FILE="${AUTH_FILES[0]}"
        fi
        SUFFIX="${AUTH_FILE##*one_auth_}"
    fi
elif [[ -z "$SUFFIX" ]]; then
    echo "⚠️  OPENNEBULA_DEPLOYMENT_ENVIRONMENT is not set."
    echo "   Set it in .devcontainer/site.env (e.g. OPENNEBULA_DEPLOYMENT_ENVIRONMENT=QIB)."
    echo "   Continuing without selecting credentials."
else
    AUTH_FILE="${ONE_DIR}/one_auth_${SUFFIX}"
fi

if [[ -z "$AUTH_FILE" || ! -f "$AUTH_FILE" ]]; then
    if [[ -n "$SUFFIX" && -n "$AUTH_FILE" ]]; then
        echo "⚠️  Credential file not found: ${AUTH_FILE}"
        echo "   Expected ${ONE_DIR}/one_auth_${SUFFIX} (and one_url_${SUFFIX})."
    fi
    echo "   Continuing without selecting credentials."
else
    URL_FILE="${ONE_DIR}/one_url_${SUFFIX}"

    echo "✅ Selected deployment: $SUFFIX"

    # The ~/.one bind-mount is read-only, so we cannot write one_auth inside it.
    # Instead, write to ~/.one_auth (the home directory, which is writable) and set
    # ONE_AUTH to point there. The OpenNebula CLI reads ONE_AUTH if set, falling
    # back to ~/.one/one_auth only when ONE_AUTH is unset.
    AUTH_TARGET="$HOME/.one_auth"
    cp "$AUTH_FILE" "$AUTH_TARGET"
    chmod 600 "$AUTH_TARGET"
    export ONE_AUTH="$AUTH_TARGET"
    echo "📋 Copied auth credentials to ${AUTH_TARGET} (ONE_AUTH set)"

    # Pin ONE_AUTH system-wide via /etc/environment so EVERY process inherits the
    # correct credential path - not just bash descendants that source the env file.
    # Without this, a process spawned with a clean env (e.g. some VS Code tasks, a
    # bare `python3` invocation) would fall back to ~/.one/one_auth, which may hold a
    # different deployment's credentials against the same shared instance.
    _pin_etc_environment ONE_AUTH "$AUTH_TARGET"
    echo "📌 Pinned ONE_AUTH in /etc/environment (system-wide)"

    # Parse ONE_USERNAME and ONE_PASSWORD from the auth file (format: user:password)
    ONE_CREDS=$(cat "$AUTH_FILE")
    export ONE_USERNAME="${ONE_CREDS%%:*}"
    export ONE_PASSWORD="${ONE_CREDS#*:}"
    echo "👤 Username: ${ONE_USERNAME}"

    # Source the matching URL file to set ONE_URL, ONE_XMLRPC, ONEFLOW_URL etc.
    # The file must contain shell variable assignments (e.g. ONE_URL=https://cloud.example.com/RPC2)
    if [[ -f "$URL_FILE" ]]; then
        echo "🔗 Loading URL configuration from: $URL_FILE"
        set -a
        # shellcheck source=/dev/null
        source "$URL_FILE"
        set +a
        echo "   ONE_URL=${ONE_URL:-not set}"
        echo "   ONE_XMLRPC=${ONE_XMLRPC:-not set}"
        echo "   ONEFLOW_URL=${ONEFLOW_URL:-not set}"
    else
        echo "⚠️  No matching URL file found at ${URL_FILE}"
        echo "   Set ONE_URL, ONE_XMLRPC, ONEFLOW_URL manually or create ${URL_FILE}"
        echo "   Expected format (shell variable assignments, one per line):"
        echo "     ONE_URL=https://cloud.example.com/RPC2"
        echo "     ONE_XMLRPC=https://cloud.example.com/RPC2"
        echo "     ONEFLOW_URL=https://cloud.example.com:2474"
    fi

    # Persist the selection in one env file, wired into four channels below so
    # that every kind of shell and subprocess sees the same credentials.
    cat > "$ONE_ENV_FILE" <<ENVEOF
# OpenNebula credentials and endpoints (set by setup.sh for deployment: $SUFFIX)
export ONE_AUTH='${AUTH_TARGET}'
export ONE_USERNAME='${ONE_USERNAME}'
export ONE_PASSWORD='${ONE_PASSWORD}'
ENVEOF
    [[ -n "${ONE_URL:-}" ]]     && echo "export ONE_URL='${ONE_URL}'" >> "$ONE_ENV_FILE"
    [[ -n "${ONE_XMLRPC:-}" ]]  && echo "export ONE_XMLRPC='${ONE_XMLRPC}'" >> "$ONE_ENV_FILE"
    [[ -n "${ONEFLOW_URL:-}" ]] && echo "export ONEFLOW_URL='${ONEFLOW_URL}'" >> "$ONE_ENV_FILE"
    chmod 600 "$ONE_ENV_FILE"
    echo "📑 OpenNebula environment written to $ONE_ENV_FILE"

    # Pin endpoint URLs system-wide alongside ONE_AUTH. Interactive VS Code
    # terminals are non-login shells: they skip /etc/profile.d/, and devcontainer
    # features can regenerate ~/.bashrc and drop any appended block.
    # Ansible's opennebula inventory plugins read api_url from ONE_URL.
    if [[ -n "${ONE_URL:-}" ]]; then
        _pin_etc_environment ONE_URL "$ONE_URL"
        echo "📌 Pinned ONE_URL in /etc/environment (system-wide)"
    fi
    if [[ -n "${ONE_XMLRPC:-}" ]]; then
        _pin_etc_environment ONE_XMLRPC "$ONE_XMLRPC"
        echo "📌 Pinned ONE_XMLRPC in /etc/environment (system-wide)"
    fi

    # Wire credentials into /etc/profile.d/ so all login shells source them, even
    # after a devcontainer feature (Python, github-cli, etc.) regenerates ~/.bashrc
    # and drops any appended block. /etc/profile.d/ is never touched by features.
    # The guard keeps the file idempotent across repeated setup runs.
    PROFILE_D_HOOK="/etc/profile.d/opennebula.sh"
    if ! grep -q 'opennebula/env.sh' "$PROFILE_D_HOOK" 2>/dev/null; then
        # SC2016: single quotes are intentional - $HOME must expand when the file is
        # sourced at login, not when setup.sh writes it.
        # shellcheck disable=SC2016
        printf '# OpenNebula credentials selected by setup.sh (sourced for all login shells)\n[[ -f "$HOME/.config/opennebula/env.sh" ]] && source "$HOME/.config/opennebula/env.sh"\n' \
            | sudo tee "$PROFILE_D_HOOK" >/dev/null
        sudo chmod 644 "$PROFILE_D_HOOK"
        echo "📌 Wrote login-shell hook to $PROFILE_D_HOOK"
    else
        echo "📌 Login-shell hook already present at $PROFILE_D_HOOK"
    fi

    # Also append to ~/.bashrc as a belt-and-suspenders fallback: VS Code terminals
    # can open as interactive-only (not login), so they won't source /etc/profile.d/.
    # The guard avoids duplicate entries on repeated runs.
    if ! grep -q 'opennebula/env.sh' "$BASHRC_PATH" 2>/dev/null; then
        echo "" >> "$BASHRC_PATH"
        echo "# Load OpenNebula credentials selected during setup" >> "$BASHRC_PATH"
        echo "[[ -f \"\$HOME/.config/opennebula/env.sh\" ]] && source \"\$HOME/.config/opennebula/env.sh\"" >> "$BASHRC_PATH"
    fi
    echo "📑 Credentials wired into /etc/profile.d/, .bashrc, /etc/environment and BASH_ENV"
fi

# Force colour in agent / non-TTY shells (Cursor-launched ansible runs). Ansible
# and many CLIs suppress colour when stdout is not a TTY, which makes playbook
# output unreadable. remoteEnv in devcontainer.json covers rebuilds; pinning here
# means it also sticks when features regenerate bashrc without inheriting remoteEnv.
_pin_etc_environment ANSIBLE_FORCE_COLOR 1
_pin_etc_environment PY_COLORS 1
_pin_etc_environment FORCE_COLOR 1
_pin_etc_environment CLICOLOR_FORCE 1

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
echo ""
echo "🔍 Validating OpenNebula configuration..."

if [[ -z "${ONE_URL:-}" && -z "${ONE_XMLRPC:-}" ]]; then
    echo "⚠️  WARNING: Neither ONE_URL nor ONE_XMLRPC is set."
    echo "   Automatic version detection will be skipped; fallback versions will be used."
    echo "   Set these in your one_url_<SUFFIX> file."
else
    echo "✅ OpenNebula endpoint configured"
fi

if [[ -z "${ONE_USERNAME:-}" || -z "${ONE_PASSWORD:-}" ]]; then
    echo "⚠️  WARNING: ONE_USERNAME and/or ONE_PASSWORD not set."
    echo "   OpenNebula CLI and API calls will require manual authentication."
else
    echo "✅ OpenNebula credentials configured"
fi

# ---------------------------------------------------------------------------
# Git safe directory
# ---------------------------------------------------------------------------
# Derived from the workspace rather than hardcoded, so this file stays identical
# across repos with different names.
echo ""
echo "📝 Configuring git safe directory..."
WORKSPACE_DIR="$(cd "${DEVCONTAINER_DIR}/.." && pwd)"
git config --global --add safe.directory "$WORKSPACE_DIR"

# ---------------------------------------------------------------------------
# SSH host aliases
# ---------------------------------------------------------------------------
# The .ssh directory is bind-mounted from the host so key files are always
# present, but the host's ~/.ssh/config may not define these aliases (e.g. on a
# fresh machine). Writing them here means git remotes work after a container
# rebuild without manual host configuration.
#
# IdentitiesOnly yes prevents SSH from offering other loaded agent keys first,
# which would fail because the server only accepts the matching key.
#
# Configured per repo via SSH_ALIASES in site.env, as space-separated
# alias:hostname:keyfile triples.
if [[ -n "${SSH_ALIASES:-}" ]]; then
    SSH_CONFIG="$HOME/.ssh/config"
    for SPEC in $SSH_ALIASES; do
        IFS=':' read -r SSH_ALIAS SSH_HOST SSH_KEY <<< "$SPEC"
        if [[ -z "$SSH_ALIAS" || -z "$SSH_HOST" || -z "$SSH_KEY" ]]; then
            echo "⚠️  Malformed SSH_ALIASES entry '${SPEC}' (want alias:hostname:keyfile) - skipping"
            continue
        fi
        if ! grep -q "Host ${SSH_ALIAS}\$" "$SSH_CONFIG" 2>/dev/null; then
            printf '\nHost %s\n  HostName %s\n  IdentityFile %s\n  IdentitiesOnly yes\n' \
                "$SSH_ALIAS" "$SSH_HOST" "$SSH_KEY" >> "$SSH_CONFIG"
            echo "🔑 Added ${SSH_ALIAS} SSH alias to $SSH_CONFIG"
        else
            echo "🔑 ${SSH_ALIAS} SSH alias already present in $SSH_CONFIG"
        fi
    done
fi

# ---------------------------------------------------------------------------
# Ansible and related tools via uv
# ---------------------------------------------------------------------------
# uv replaces pip/pipx here purely for speed - it resolves and installs an order
# of magnitude faster, and this section dominates container-create time. It is
# provided by the base image, which also sets UV_TOOL_BIN_DIR to the same
# /usr/local/py-utils/bin that the devcontainer python feature uses for pipx, so
# tools land where PATH already looks and the shared "ruff.path" setting stays
# correct.
#
# Ansible and ansible-lint share ONE virtual environment. Installed separately
# (as they were under pipx) each one resolves and builds its own copy of
# ansible-core - the single most expensive dependency here - so sharing a venv
# removes a whole duplicate resolution. pyone, passlib and pytest join the same
# venv because they are all things Ansible content needs at runtime; pytest in
# particular has to live there so collection unit tests can import ansible.*.
#
# TODO(speed): the parts of this that do not depend on the server version -
# ansible, ansible-lint, passlib, pytest, ruff, pilfer - could be baked into the
# base image as cached layers, cutting them from every container create to zero.
# Only pyone and the opennebula-cli gem are genuinely server-version-dependent.
# Deferred because it means an image tag bump to update Ansible, rather than a
# plain rebuild.
#
# TODO(speed): the gem install, this venv build and the galaxy collection install
# are mutually independent and all network-bound. Backgrounding them with a
# single `wait` would overlap the three. Deferred: it makes a failure in any one
# of them harder to attribute in the setup log.

ANSIBLE_VENV="/usr/local/ansible-venv"

# Build the venv on the SYSTEM interpreter, explicitly. Left to its own devices
# uv will happily download and use a managed CPython, which silently gives
# Ansible a different Python from the /usr/bin/python3 that the shared
# "ansible.python.interpreterPath" and "python.defaultInterpreterPath" settings
# pin - so modules would resolve in the editor but not at runtime, or vice versa.
# --python-preference only-system makes that failure mode impossible.
SYSTEM_PYTHON="/usr/bin/python3"
if [[ ! -x "$SYSTEM_PYTHON" ]]; then
    echo "❌ $SYSTEM_PYTHON not found. The devcontainer python feature should provide it."
    echo "   Check the 'ghcr.io/devcontainers/features/python' entry in devcontainer.json."
    exit 1
fi

echo ""
echo "📦 Creating shared Ansible environment with uv (python: $("$SYSTEM_PYTHON" -V))..."
sudo mkdir -p "$ANSIBLE_VENV"
sudo chown -R "$(id -u):$(id -g)" "$ANSIBLE_VENV"
uv venv --python "$SYSTEM_PYTHON" --python-preference only-system "$ANSIBLE_VENV"

echo "🔌 Installing Ansible extensions and dependencies..."

# Detect compatible PyONE version before installation
echo "🔍 Auto-detecting compatible PyONE version..."
if [[ -n "${PYONE_VERSION_OVERRIDE:-}" ]]; then
    # OVERRIDE always wins, whether or not detection would have worked.
    echo "📌 Using PyONE version override: $PYONE_VERSION_OVERRIDE"
    PYONE_VERSION_SPEC="$PYONE_VERSION_OVERRIDE"
elif PYONE_VERSION_SPEC=$("${COMMON_DIR}/detect-opennebula-version.sh" pyone-spec 2>/dev/null); then
    echo "✅ Detected server version, using PyONE: $PYONE_VERSION_SPEC"
elif [[ -n "${PYONE_VERSION_FALLBACK:-}" ]]; then
    # FALLBACK applies only when server detection fails. Set per repo in site.env
    # to the newest version known to work against that institute's deployment.
    echo "⚠️  Auto-detection failed, using site fallback PyONE version: $PYONE_VERSION_FALLBACK"
    PYONE_VERSION_SPEC="$PYONE_VERSION_FALLBACK"
else
    echo "❌ PyONE auto-detection failed and no PYONE_VERSION_FALLBACK set in site.env."
    echo "   Set PYONE_VERSION_FALLBACK (e.g. '~=7.4.0') or fix connectivity to the server."
    exit 1
fi

# One resolution, one venv, everything Ansible-side in it.
echo "💎 Installing ansible, ansible-lint, pyone${PYONE_VERSION_SPEC}, passlib, pytest..."
uv pip install --python "${ANSIBLE_VENV}/bin/python" --python-preference only-system \
    ansible \
    ansible-lint \
    "pyone${PYONE_VERSION_SPEC}" \
    passlib \
    pytest

# uv installs into the venv but does not put its console scripts on PATH the way
# `pipx install` did. Symlink them into UV_TOOL_BIN_DIR so ansible, ansible-lint,
# ansible-playbook and friends stay available exactly as before.
UV_BIN_DIR="${UV_TOOL_BIN_DIR:-/usr/local/py-utils/bin}"
sudo mkdir -p "$UV_BIN_DIR"
LINKED=0
for script in "${ANSIBLE_VENV}"/bin/*; do
    name="$(basename "$script")"
    # Skip the venv's own plumbing - only real entry points should go on PATH.
    case "$name" in
        python|python3|python3.*|activate*|pydoc*|pip|pip3|pip3.*) continue ;;
    esac
    [[ -x "$script" ]] || continue
    sudo ln -sf "$script" "${UV_BIN_DIR}/${name}"
    LINKED=$((LINKED + 1))
done
echo "🔗 Linked ${LINKED} entry points into ${UV_BIN_DIR}"

echo "⚡ Installing Ruff (Python linter and formatter)..."
uv tool install --force ruff

echo "🔐 Installing pilfer (Ansible vault bulk operations)..."
uv tool install --force pilfer

# ---------------------------------------------------------------------------
# System Python packages
# ---------------------------------------------------------------------------
# Install pyone for system Python so standalone scripts (outside the Ansible
# venv) can import pyone directly. tqdm is used for progress bars in scripts.
# --break-system-packages is acceptable in an isolated devcontainer: Ubuntu marks
# the system Python as externally managed (PEP 668), which is the right default
# on a real machine but only an obstacle in a disposable container.
echo ""
echo "🐍 Installing pyone for system Python..."
echo "💎 Installing pyone version: $PYONE_VERSION_SPEC into system Python..."
sudo --preserve-env=UV_LINK_MODE uv pip install --system --break-system-packages \
    --python "$SYSTEM_PYTHON" --python-preference only-system \
    "pyone${PYONE_VERSION_SPEC}" tqdm

# ---------------------------------------------------------------------------
# Ansible collections
# ---------------------------------------------------------------------------
echo ""
echo "📚 Installing Ansible collections..."
if [ -f "roles/requirements.yml" ]; then
    ansible-galaxy collection install -r roles/requirements.yml
else
    echo "ℹ️  Info: roles/requirements.yml not found, skipping collection install"
fi

# ---------------------------------------------------------------------------
# OpenNebula CLI (Ruby gem)
# ---------------------------------------------------------------------------
echo ""
echo "🔧 Installing OpenNebula CLI tools..."

if [[ -n "${OPENNEBULA_CLI_VERSION_OVERRIDE:-}" ]]; then
    echo "📌 Using CLI version override: $OPENNEBULA_CLI_VERSION_OVERRIDE"
    CLI_VERSION_SPEC="$OPENNEBULA_CLI_VERSION_OVERRIDE"
else
    echo "🔍 Auto-detecting compatible CLI version..."
    if CLI_VERSION_SPEC=$("${COMMON_DIR}/detect-opennebula-version.sh" cli-spec 2>/dev/null); then
        echo "✅ Detected server version, using CLI tools: $CLI_VERSION_SPEC"
    elif [[ -n "${OPENNEBULA_CLI_VERSION_FALLBACK:-}" ]]; then
        echo "⚠️  Auto-detection failed, using site fallback version: $OPENNEBULA_CLI_VERSION_FALLBACK"
        CLI_VERSION_SPEC="$OPENNEBULA_CLI_VERSION_FALLBACK"
    else
        echo "❌ CLI auto-detection failed and no OPENNEBULA_CLI_VERSION_FALLBACK set in site.env."
        echo "   Set OPENNEBULA_CLI_VERSION_FALLBACK (e.g. '~> 7.4') or fix connectivity."
        exit 1
    fi
fi

# Install system-wide in container (handles both version specifiers and exact versions)
# --no-document skips ri/rdoc generation (saves ~7s, docs not needed in devcontainer)
echo "💎 Installing opennebula-cli version: $CLI_VERSION_SPEC"
sudo gem install opennebula-cli -v "$CLI_VERSION_SPEC" --no-document

# ---------------------------------------------------------------------------
# OpenNebula CLI compatibility stubs (legacy gems only)
# ---------------------------------------------------------------------------
# The standalone gem historically required files that only ship with the full
# server packages. Both gaps are now fixed upstream, at DIFFERENT versions, so
# each stub is applied from its own capability probe rather than a version
# comparison - that way they self-retire and cannot go stale:
#
#   load_opennebula_paths  - missing until 7.2.1  (OpenNebula/one#7608)
#   HostSyncManager        - top-level require until 7.4.0, which moved it into
#                            sync() behind a rescue LoadError. Before that, its
#                            absence broke EVERY onehost subcommand, not just sync.
echo ""
echo "🔧 OpenNebula CLI compatibility check..."
"${COMMON_DIR}/opennebula-cli-tools-patch.sh"

# ---------------------------------------------------------------------------
# Shell completions
# ---------------------------------------------------------------------------
echo ""
echo "🐚 Installing shell completions..."
"${COMMON_DIR}/shell-completions.sh"

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
echo ""
echo "🔍 Verifying installations..."
echo "  ✓ Ansible version: $(ansible --version | head -1)"
echo "  ✓ Ansible-lint version: $(ansible-lint --version | head -1)"
echo "  ✓ Ruff version: $(ruff --version)"
echo "  ✓ Pilfer version: $(uv tool list 2>/dev/null | awk '/^pilfer /{print $2; exit}')"
echo "  ✓ ShellCheck version: $(shellcheck --version | grep 'version:')"
PYONE_INSTALLED_VERSION=$(python3 -c "import importlib.metadata; print(importlib.metadata.version('pyone'))" 2>/dev/null || echo "unknown")
echo "  ✓ PyONE version: $PYONE_INSTALLED_VERSION"

echo ""
echo "OpenNebula Configuration:"
if [[ -n "${ONE_XMLRPC:-}" ]]; then
    echo "  📡 XML-RPC Endpoint (Ruby CLI): ${ONE_XMLRPC}"
fi
if [[ -n "${ONE_URL:-}" ]]; then
    echo "  📡 XML-RPC Endpoint (Ansible): ${ONE_URL}"
fi
echo "  👤 Username: ${ONE_USERNAME:-not set}"
echo "  🔗 OneFlow URL: ${ONEFLOW_URL:-Not set}"
echo ""

# Test OpenNebula CLI tools. onehost is probed separately because it was the
# subcommand family broken by the missing HostSyncManager - if onevm works but
# onehost does not, the CLI gem predates 7.4.0 and the stub did not apply.
echo "🔧 Testing OpenNebula CLI connectivity..."
if onevm list >/dev/null 2>&1; then
    echo "  ✅ onevm list OK"
    if onehost list >/dev/null 2>&1; then
        echo "  ✅ onehost list OK"
    else
        echo "  ⚠️  onehost list failed (onevm works - check the HostSyncManager stub)"
    fi
    CLI_VERSION=$(gem list opennebula-cli | grep opennebula-cli | head -1 || echo "Could not retrieve CLI version")
    echo "  💎 CLI version: $CLI_VERSION"
else
    echo "  ⚠️  OpenNebula CLI test failed - may need authentication"
    echo "     This is normal if credentials aren't available during build"
fi

# ---------------------------------------------------------------------------
# Shell environment
# ---------------------------------------------------------------------------
# Ensure Python requests picks up the system trust store (needed when a custom CA
# cert has been added to the image by a site-specific Dockerfile layer)
if ! grep -q "REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" "$BASHRC_PATH" 2>/dev/null; then
    echo 'export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt' >> "$BASHRC_PATH"
    echo "📑 Added REQUESTS_CA_BUNDLE to $BASHRC_PATH"
else
    echo "📑 REQUESTS_CA_BUNDLE already present in $BASHRC_PATH"
fi

_run_site_hook post-setup.sh

echo ""
echo "✅ Development environment setup complete!"
echo "🎯 You can now start developing with Ansible and OpenNebula tools"
