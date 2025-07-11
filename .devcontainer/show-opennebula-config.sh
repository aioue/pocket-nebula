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
    
    # Test connectivity (suppress output, just check if it works)
    if onevm list >/dev/null 2>&1; then
        echo "  ✅ Connection: Working"
    else
        echo "  ⚠️  Connection: Authentication may be required"
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
