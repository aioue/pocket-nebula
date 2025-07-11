#!/bin/bash
set -e  # Exit on any error

echo "🚀 Setting up development environment..."

# Validate OpenNebula environment variables
echo "🔍 Validating OpenNebula configuration..."
if [[ -z "${ONE_URL:-}" ]]; then
    echo "❌ ERROR: ONE_URL environment variable is not set"
    echo "Please refer to the 'Prerequisites' section in README.md for setup instructions"
    exit 1
fi

if [[ -z "${ONE_USERNAME:-}" || -z "${ONE_PASSWORD:-}" ]]; then
    echo "❌ ERROR: ONE_USERNAME and ONE_PASSWORD environment variables are not set"
    echo "Please refer to the 'Prerequisites' section in README.md for setup instructions"
    exit 1
fi

echo "✅ OpenNebula environment variables validated"

# Configure git safe directory
echo "📝 Configuring git safe directory..."
git config --global --add safe.directory /workspaces/pocket-nebula

# Install Ansible and related tools via pipx (preferred method for isolated CLI tools)
echo "📦 Installing Ansible via pipx..."
pipx install --include-deps ansible

echo "🔌 Installing Ansible extensions and dependencies..."
# Install pyone and passlib into ansible environment - this provides pyone for ansible use
pipx inject --include-deps --include-apps ansible pyone
pipx inject ansible passlib

echo "🧹 Installing ansible-lint..."
pipx install ansible-lint

# Install pyone for system Python (devcontainer-safe approach)
# Using --break-system-packages is acceptable in isolated devcontainer environments
echo "🐍 Installing pyone for system Python..."
pip3 install pyone --break-system-packages

# Install Ansible collections
echo "📚 Installing Ansible collections..."
if [ -f "roles/requirements.yml" ]; then
    ansible-galaxy collection install -r roles/requirements.yml
else
    echo "ℹ️  Info: roles/requirements.yml not found, skipping collection install"
fi

# Detect and install OpenNebula CLI tools with compatible version
echo "🔧 Installing OpenNebula CLI tools..."

# Check for version override from environment
if [[ -n "${OPENNEBULA_CLI_VERSION_OVERRIDE:-}" ]]; then
    echo "📌 Using CLI version override: $OPENNEBULA_CLI_VERSION_OVERRIDE"
    CLI_VERSION_SPEC="$OPENNEBULA_CLI_VERSION_OVERRIDE"
else
    echo "🔍 Auto-detecting compatible CLI version..."
    if CLI_VERSION_SPEC=$(/usr/local/bin/detect-opennebula-version.sh cli-spec 2>/dev/null); then
        echo "✅ Detected server version, using CLI tools: $CLI_VERSION_SPEC"
    else
        echo "⚠️  Auto-detection failed, using fallback version: ~> 6.10.0"
        CLI_VERSION_SPEC="~> 6.10.0"
    fi
fi

# Install the OpenNebula CLI with the determined version
echo "💎 Installing opennebula-cli version: $CLI_VERSION_SPEC"
sudo gem install --no-document opennebula-cli -v "$CLI_VERSION_SPEC"

# Verify installations
echo "🔍 Verifying installations..."
echo "  ✓ Ansible version: $(ansible --version | head -1)"
echo "  ✓ Ansible-lint version: $(ansible-lint --version)"
if python3 -c "import pyone" &> /dev/null; then
    echo "  ✓ pyone available in system Python environment"
else
    echo "  ⚠️  pyone not found in system Python (available in pipx/ansible environment only, independent scripts will not work)"
fi

echo ""
echo "✅ Development environment setup complete!"
echo "🎯 You can now start developing with Ansible and OpenNebula tools" 
