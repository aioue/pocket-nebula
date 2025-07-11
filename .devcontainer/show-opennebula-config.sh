#!/bin/bash
# OpenNebula Configuration Display Script
# Shows current OpenNebula environment configuration

echo "🌐 OpenNebula Configuration:"

# Check and display environment variables
if [[ -n "${ONE_URL:-}" ]]; then
    echo "  📡 XML-RPC Endpoint: ${ONE_URL}"
else
    echo "  ❌ XML-RPC Endpoint: Not set (ONE_URL)"
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

# Show CLI version if available
if command -v onevm >/dev/null 2>&1; then
    CLI_VERSION=$(gem list opennebula-cli 2>/dev/null | grep opennebula-cli | head -1 || echo "Unknown")
    echo "  💎 CLI Version: $CLI_VERSION"
    
    # Test connectivity and capture error output if any
    if error_output=$(onevm list 2>&1 >/dev/null); then
        echo "  ✅ Connection: Working"
    else
        echo "  ⚠️  Connection test failed. Error output:\n"
        # Indent each line of error message for readability
        echo "$error_output" | sed 's/^/       /'

        # Provide helpful troubleshooting hints without exposing credentials
        echo "\n     ➤ Tip: The OpenNebula CLI needs a valid authentication token ( ~/.one/one_auth ) or the ONE_AUTH env variable."
        echo "       You can initialise it by running:"
        echo "         oneuser login --user \"$ONE_USERNAME\" --endpoint \"${ONE_URL:-<XML-RPC URL>}\""
        echo "       (you will be prompted for your password and a token will be stored in ~/.one/one_auth)"
        echo "       After logging in, try 'onevm list' to confirm the session works, then re-run this script."
    fi
else
    echo "  ❌ CLI Tools: Not installed"
fi

# Show missing configuration notice if needed
if [[ -z "${ONE_URL:-}" || -z "${ONE_USERNAME:-}" || -z "${ONE_PASSWORD:-}" ]]; then
    echo ""
    echo "⚠️  Missing configuration detected!"
    echo "   Please refer to the 'Prerequisites' section in README.md for setup instructions"
fi

echo "" 
