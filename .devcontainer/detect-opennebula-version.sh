#!/bin/bash
# OpenNebula Server Version Detection Script
# This script detects the server version via the one.system.version XML-RPC method

set -euo pipefail

# Use existing environment variables from devcontainer setup
ONE_ENDPOINT="${ONE_URL:-${ONE_XMLRPC:-}}"
ONE_AUTH="${ONE_USERNAME:-oneadmin}:${ONE_PASSWORD:-}"

# Validate required environment variables
if [[ -z "$ONE_ENDPOINT" ]]; then
    echo "ERROR: ONE_URL environment variable is not set" >&2
    echo "Please refer to the 'Prerequisites' section in README.md for setup instructions" >&2
    exit 1
fi

if [[ -z "$ONE_USERNAME" || -z "$ONE_PASSWORD" ]]; then
    echo "ERROR: ONE_USERNAME and ONE_PASSWORD environment variables are not set" >&2
    echo "Please refer to the 'Prerequisites' section in README.md for setup instructions" >&2
    exit 1
fi

# Function to make XML-RPC call to get server version
detect_server_version() {
    local endpoint="$1"
    local auth="$2"
    
    # Create temporary XML-RPC request
    local request=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<methodCall>
    <methodName>one.system.version</methodName>
    <params>
        <param>
            <value><string>${auth}</string></value>
        </param>
    </params>
</methodCall>
EOF
)

    # Make the XML-RPC call with timeout
    local response
    if ! response=$(curl -s --max-time 10 \
        -H "Content-Type: text/xml" \
        -d "$request" \
        "$endpoint" 2>/dev/null); then
        echo "ERROR: Failed to connect to OpenNebula server at $endpoint" >&2
        echo "Check your network connection and ONE_URL setting" >&2
        return 1
    fi

    # Check for XML-RPC fault
    if echo "$response" | grep -q "<name>faultCode</name>"; then
        echo "ERROR: OpenNebula authentication failed" >&2
        echo "Check your ONE_USERNAME and ONE_PASSWORD credentials" >&2
        return 1
    fi

    # Extract version from XML response
    # Response format (XML-RPC array): <value><string>6.10.4</string></value>
    local version
    if version=$(echo "$response" | grep -o '<value><string>[0-9]*\.[0-9]*\.[0-9]*</string></value>' | head -1 | sed 's/<[^>]*>//g'); then
        echo "OpenNebula $version"
        return 0
    else
        echo "ERROR: Could not parse version from server response" >&2
        echo "Response: $response" >&2
        return 1
    fi
}

# Function to convert server version to CLI version specifier
version_to_cli_spec() {
    local version="$1"
    # Extract major.minor from version (e.g., "OpenNebula 6.10.4" -> "6.10")
    local major_minor
    if major_minor=$(echo "$version" | grep -o '[0-9]*\.[0-9]*' | head -1); then
        echo "~> ${major_minor}.0"
        return 0
    else
        echo "ERROR: Could not extract major.minor version from: $version" >&2
        return 1
    fi
}

# Function to convert server version to just CLI version number
version_to_cli_version() {
    local version="$1"
    # Extract major.minor from version (e.g., "OpenNebula 6.10.4" -> "6.10")
    local major_minor
    if major_minor=$(echo "$version" | grep -o '[0-9]*\.[0-9]*' | head -1); then
        echo "${major_minor}"
        return 0
    else
        echo "ERROR: Could not extract major.minor version from: $version" >&2
        return 1
    fi
}

# Main execution
case "${1:-version}" in
    "version")
        detect_server_version "$ONE_ENDPOINT" "$ONE_AUTH"
        ;;
    "cli-spec")
        server_version=$(detect_server_version "$ONE_ENDPOINT" "$ONE_AUTH")
        if [[ $? -eq 0 ]]; then
            version_to_cli_spec "$server_version"
        else
            exit 1
        fi
        ;;
    "cli-version")
        server_version=$(detect_server_version "$ONE_ENDPOINT" "$ONE_AUTH")
        if [[ $? -eq 0 ]]; then
            version_to_cli_version "$server_version"
        else
            exit 1
        fi
        ;;
    "help"|"--help"|"-h")
        echo "OpenNebula Server Version Detection"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  version     Show full server version (default)"
        echo "  cli-spec    Show CLI gem version specifier for compatibility"
        echo "  cli-version Show CLI version number for compatibility"
        echo "  help        Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  ONE_URL      OpenNebula XML-RPC endpoint (required)"
        echo "  ONE_USERNAME OpenNebula username (required)"
        echo "  ONE_PASSWORD OpenNebula password (required)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Show server version"
        echo "  $0 cli-spec          # Show gem version spec (~> 6.10.0)"
        echo "  $0 cli-version       # Show version number (6.10)"
        ;;
    *)
        echo "ERROR: Unknown command: $1" >&2
        echo "Use '$0 help' for usage information" >&2
        exit 1
        ;;
esac 
