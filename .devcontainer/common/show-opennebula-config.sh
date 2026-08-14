#!/bin/bash
# OpenNebula Configuration Display Script
# Shows current OpenNebula environment configuration on container start.

# Source the credentials file written by setup.sh to get the selected deployment.
# This deliberately takes precedence over any values already in the environment:
# a host that exports another deployment's ONE_* vars would otherwise shadow the
# selected credentials, and the CLI would silently act as the wrong user.
ONE_ENV_FILE="$HOME/.config/opennebula/env.sh"
if [[ -f "$ONE_ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ONE_ENV_FILE"
fi

echo "OpenNebula Configuration:"

if [[ -n "${ONE_XMLRPC:-}" ]]; then
    echo "  📡 XML-RPC Endpoint (Ruby CLI): ${ONE_XMLRPC}"
else
    echo "  ❌ XML-RPC Endpoint (Ruby CLI): Not set (ONE_XMLRPC)"
fi

if [[ -n "${ONE_URL:-}" ]]; then
    echo "  📡 XML-RPC Endpoint (Ansible): ${ONE_URL}"
else
    echo "  ❌ XML-RPC Endpoint (Ansible): Not set (ONE_URL)"
fi

if [[ -n "${ONE_USERNAME:-}" ]]; then
    echo "  👤 Username: ${ONE_USERNAME}"
else
    echo "  ❌ Username: Not set (ONE_USERNAME)"
fi

if [[ -n "${ONE_PASSWORD:-}" ]]; then
    echo "  🔐 Password: ******* (set)"
else
    echo "  ❌ Password: Not set (ONE_PASSWORD)"
fi

if [[ -n "${ONEFLOW_URL:-}" ]]; then
    echo "  🔗 OneFlow URL: ${ONEFLOW_URL}"
else
    echo "  ℹ️  OneFlow URL: Not set (optional)"
fi

# Show where the credentials came from, since the file is intentionally kept in
# the container home directory rather than the bind-mounted workspace.
if [[ -f "$ONE_ENV_FILE" ]]; then
    echo "  📑 Environment file: $ONE_ENV_FILE"
fi

# Show PyONE version if available
if command -v python3 >/dev/null 2>&1; then
    PYONE_VERSION=$(python3 -c "import importlib.metadata; print(importlib.metadata.version('pyone'))" 2>/dev/null || echo "Not installed")
    echo "  🐍 PyONE Version: $PYONE_VERSION"
fi

# Show CLI version if available
if command -v onevm >/dev/null 2>&1; then
    CLI_VERSION=$(gem list opennebula-cli 2>/dev/null | grep opennebula-cli | head -1 || echo "Unknown")
    echo "  💎 CLI Version: $CLI_VERSION"

    # Test connectivity and capture error output if any. Surfacing the actual
    # error beats a bare "authentication may be required" - the failure is just
    # as often a VPN/DNS problem as a credential one.
    if error_output=$(onevm list 2>&1 >/dev/null); then
        echo "  ✅ CLI Connection: Working"

        # A working connection is more useful stated as what you can see. Counts
        # come from the same list commands, with --csv so the parse does not
        # depend on column widths, and are best-effort: a failure here must never
        # turn a healthy container start into a scary message.
        one_count() {
            local out
            out=$("$1" list --csv 2>/dev/null) || { echo "?"; return; }
            # First line is the CSV header.
            printf '%s' "$out" | awk 'NR>1' | grep -c . || echo 0
        }
        printf "  📊 Visible to %s: %s VMs, %s hosts, %s templates, %s images\n" \
            "${ONE_USERNAME:-you}" \
            "$(one_count onevm)" \
            "$(one_count onehost)" \
            "$(one_count onetemplate)" \
            "$(one_count oneimage)"
    else
        echo "  ⚠️  CLI Connection test failed. Error output:"
        echo ""
        # Indent each line of error message for readability
        echo "$error_output" | sed 's/^/       /'

        # Provide helpful troubleshooting hints without exposing credentials
        echo ""
        echo "     ➤ Tip: The OpenNebula CLI needs a valid authentication token ( ~/.one_auth ) or the ONE_AUTH env variable."
        echo "       You can initialise it by running:"
        echo "         oneuser login --user \"${ONE_USERNAME:-<username>}\" --endpoint \"${ONE_URL:-<XML-RPC URL>}\""
        echo "       (you will be prompted for your password and a token will be stored in ~/.one_auth)"
        echo "       After logging in, try 'onevm list' to confirm the session works, then re-run this script."
    fi
else
    echo "  ❌ CLI Tools: Not installed"
fi

# Warn if required variables are missing, but don't exit 1 - postStartCommand failing
# on every container start is confusing. The warning is enough; credentials can be
# set up interactively after the container is running.
if [[ -z "${ONE_XMLRPC:-}" && -z "${ONE_URL:-}" ]] || [[ -z "${ONE_USERNAME:-}" ]] || [[ -z "${ONE_PASSWORD:-}" ]]; then
    echo ""
    echo "⚠️  Some OpenNebula environment variables are not set."
    echo "   This is expected if the container has been restarted after setup."
    echo "   Re-open in Container to re-run setup.sh, or source the environment file:"
    echo "     source $ONE_ENV_FILE"
fi

echo ""
