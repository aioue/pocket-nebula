#!/bin/bash
set -e  # Exit on any error

echo "🚀 Setting up development environment..."

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
    echo "⚠️  Warning: roles/requirements.yml not found, skipping collection install"
fi

# Verify installations
echo "🔍 Verifying installations..."
echo "  ✓ Ansible version: $(ansible --version | head -1)"
echo "  ✓ Ansible-lint version: $(ansible-lint --version)"
if python3 -c "import pyone" &> /dev/null; then
    echo "  ✓ pyone available in system Python environment"
else
    echo "  ⚠️  pyone not found in system Python (available in pipx/ansible environment only, independent scripts will not work)"
fi

echo "✅ Development environment setup complete!"
echo "🎯 You can now start developing with Ansible and OpenNebula tools" 
