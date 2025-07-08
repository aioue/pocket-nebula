# Pocket Nebula ✨→👖

A Skeleton Dev Container preconfigured with the OpenNebula CLI, and Ansible

[OpenNebula](https://opennebula.io/) is an Open Source Cloud & Edge Computing Platform.

A [development container](https://containers.dev/) allows you to use a container as an isolated, full-featured development environment.

Pocket Nebula provides an instant isolated environment for OpenNebula operations (host and guest config and management).

## Overview

This repository provides a clean starting point for OpenNebula automation projects. It includes:

- **DevContainer**: Complete development environment with Ansible and OpenNebula tools
- **Ansible Structure**: Basic inventory and playbook examples
- **Documentation**: Setup guides and usage examples

## Complete Setup Guide

This guide walks you through setting up Pocket Nebula from scratch to running your first automation.

### Step 1: Prerequisites

Before starting, ensure you have:

1. **Git**: For cloning the repository
2. **VS Code**: With the [Dev Containers Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
3. **Docker**: For running the development container
4. **OpenNebula Access**: Your OpenNebula instance URL and credentials
5. **SSH Keys**: For Ansible host access (optional but recommended)

### Step 2: Clone and Setup

**Run these commands on your HOST system (not in the container):**

```bash
# Clone the repository
git clone https://github.com/your-username/pocket-nebula.git
cd pocket-nebula

# Verify the repository structure
ls -la
# Expected: .devcontainer/, inventory/, roles/, README.md, etc.
```

**⚠️ Important**: If you see a prompt like `vscode ➜ /workspaces/pocket-nebula (main) $`, you're already inside the dev container! Exit to your host system first.

### Step 3: Configure Environment Variables

**Run these commands on your HOST system (not in the container):**

Set up your OpenNebula credentials on your host system:

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export ONE_USERNAME=your-opennebula-username
export ONE_PASSWORD=your-opennebula-password
export ONE_XMLRPC=https://your-opennebula-host/RPC2
export ONE_URL=https://your-opennebula-host/RPC2
export ONEFLOW_URL=https://your-opennebula-host:2474

# Optional: Ansible vault password for encrypted files
export ANSIBLE_VAULT_PASSWORD=your-vault-password

# Reload your shell profile
source ~/.bashrc  # or ~/.zshrc
```

### Step 4: Setup OpenNebula CLI (Optional)

**Run these commands on your HOST system (not in the container):**

For OpenNebula CLI authentication:

```bash
# Create OpenNebula credentials directory
mkdir -p ~/.one

# Create authentication file
echo "your-username:your-password" > ~/.one/one_auth
chmod 600 ~/.one/one_auth

# Verify the file was created
ls -la ~/.one/
```

### Step 5: Setup Ansible Vault (Recommended)

**Run these commands on your HOST system (not in the container):**

For encrypted sensitive data:

```bash
# Create vault directory
mkdir -p ~/.ansible-vault

# Create vault password file
echo "your-vault-password" > ~/.ansible-vault/.vault-file
chmod 600 ~/.ansible-vault/.vault-file

# Verify the setup
ls -la ~/.ansible-vault/
```

### Step 6: Launch the DevContainer

**Run these commands on your HOST system (not in the container):**

```bash
# Open VS Code in the project directory
code .

# In VS Code:
# 1. Press Ctrl+Shift+P (Cmd+Shift+P on Mac)
# 2. Type "Dev Containers: Reopen in Container"
# 3. Select the command
# 4. Wait for the container to build (first time may take 5-10 minutes)
```

**✅ Success**: You'll know you're in the container when you see the prompt change to `vscode ➜ /workspaces/pocket-nebula (main) $`

### Step 7: Verify the Setup

**Run these commands INSIDE the dev container (you should see `vscode ➜ /workspaces/pocket-nebula (main) $`):**

Once the container is running, verify everything is working:

```bash
# Check environment variables are loaded
env | grep ONE
# Expected output:
# ONE_USERNAME=your-username
# ONE_PASSWORD=your-password
# ONE_XMLRPC=https://your-opennebula-host/RPC2
# ONE_URL=https://your-opennebula-host/RPC2
# ONEFLOW_URL=https://your-opennebula-host:2474

# Test OpenNebula CLI
onevm list
# Should show your VMs or an empty list

# Test Ansible installation
ansible --version
# Should show Ansible version and configuration

# Test ansible-lint
ansible-lint --version
# Should show ansible-lint version

# Check mounted directories
ls -la ~/.ssh/     # Should show your SSH keys
ls -la ~/.one/     # Should show OpenNebula credentials
ls -la ~/.ansible-vault/  # Should show vault files
```

### Step 8: Run Your First Automation

**Run these commands INSIDE the dev container (you should see `vscode ➜ /workspaces/pocket-nebula (main) $`):**

```bash
# View the available inventory
ansible-inventory --inventory inventory/opennebula --graph

# Run the example playbook
ansible-playbook --inventory inventory/opennebula catalog-guests.yml

# Check the playbook output
cat catalog-guests.yml
```

## Environment Variables

The devcontainer supports multiple vault password sources in order of precedence:

1. **Environment Variable**: `ANSIBLE_VAULT_PASSWORD` (highest priority)
2. **Vault File**: `~/.ansible-vault/.vault-file` (mounted from host)
3. **Ansible Config**: `vault_password_file` setting in `ansible.cfg`

**Note**: The `OPENNEBULA_USER_PASS` variable in `devcontainer.env` is a template and not used by default. Your actual OpenNebula credentials should be set via the `ONE_USERNAME` and `ONE_PASSWORD` environment variables, which take precedence.

## Host Mounts

The container automatically mounts these directories from your host:

- `~/.ssh` → `/home/vscode/.ssh` (SSH keys for Ansible)
- `~/.one` → `/home/vscode/.one` (OpenNebula CLI credentials)
- `~/.ansible-vault` → `/home/vscode/.ansible-vault` (Ansible vault files)

## Usage Examples

**All commands below should be run INSIDE the dev container (you should see `vscode ➜ /workspaces/pocket-nebula (main) $`):**

### OpenNebula CLI Operations

```bash
# List all VMs
onevm list

# List networks
onevnet list

# List hosts
onehost list

# List users
oneuser list

# Get VM details
onevm show <vm-id>

# Create a VM from template
onevm create <template-name>
```

### Ansible Automation

```bash
# View inventory structure
ansible-inventory --inventory inventory/opennebula --graph

# Run playbook with inventory
ansible-playbook --inventory inventory/opennebula catalog-guests.yml

# Run with vault password
ansible-playbook --inventory inventory/opennebula your-playbook.yml --ask-vault-pass

# Test connectivity to hosts
ansible all --inventory inventory/opennebula -m ping

# Run ad-hoc commands
ansible all --inventory inventory/opennebula -m shell -a "uptime"
```

### Code Quality

```bash
# Lint your Ansible playbooks
ansible-lint catalog-guests.yml

# Check syntax
ansible-playbook --syntax-check catalog-guests.yml

# Dry run (check mode)
ansible-playbook --inventory inventory/opennebula catalog-guests.yml --check
```

## Available Tools

The devcontainer provides a complete development environment with:

- **Ansible**: Latest version with pipx isolation
- **ansible-lint**: Code quality and best practices checking
- **OpenNebula CLI**: Ruby-based command-line tools
- **pyone**: Python library for API integration
- **VS Code Extensions**: Docker and Ansible support

## Project Structure

```
pocket-nebula/
├── .devcontainer/          # Development container configuration
│   ├── Dockerfile          # Container image definition
│   ├── devcontainer.json   # VS Code devcontainer config
│   ├── devcontainer.env    # Environment variables template
│   └── setup.sh           # Container setup script
├── inventory/              # Ansible inventory files
│   └── opennebula/        # OpenNebula-specific inventory
├── roles/                  # Ansible roles (add your own)
│   └── requirements.yml    # Role dependencies
├── catalog-guests.yml      # Example playbook
└── ansible.cfg            # Ansible configuration
```

## Customization

This is a skeleton repository. Customize it for your specific needs:

1. **Add Your Roles**: Create Ansible roles in the `roles/` directory
2. **Configure Inventory**: Update `inventory/opennebula/opennebula.yml` with your hosts
3. **Create Playbooks**: Add your automation playbooks
4. **Environment Variables**: Set up your specific OpenNebula instance details
5. **CA Certificates**: Add your own CA certificates if needed for your OpenNebula instance

## Troubleshooting

### Common Issues

**SSL Certificate Issues**:
```bash
# Add your CA certificate to the Dockerfile if needed
# Edit .devcontainer/Dockerfile and add:
# COPY your-ca.crt /usr/local/share/ca-certificates/
# RUN update-ca-certificates
```

**Authentication Problems**:
```bash
# Verify your OpenNebula credentials (run INSIDE container)
env | grep ONE

# Test OpenNebula connection (run INSIDE container)
onevm list
```

**Ansible Connection Issues**:
```bash
# Check SSH key permissions (run INSIDE container)
ls -la ~/.ssh/

# Test host connectivity (run INSIDE container)
ansible all --inventory inventory/opennebula -m ping
```

**Vault Issues**:
```bash
# Verify vault password is accessible (run INSIDE container)
ls -la ~/.ansible-vault/

# Test vault password (run INSIDE container)
echo $ANSIBLE_VAULT_PASSWORD
```

**Container Build Issues**:
```bash
# Rebuild the container
# In VS Code: Ctrl+Shift+P → "Dev Containers: Rebuild Container"
```

**Wrong Terminal Location**:
- If you see `vscode ➜ /workspaces/pocket-nebula (main) $` but need to run host commands, exit the container first
- If you don't see that prompt but need to run container commands, make sure you're in the dev container

## Contributing

This is a skeleton repository. Feel free to:

- Fork and customize for your projects
- Submit improvements to the devcontainer setup
- Add example playbooks and roles
- Improve documentation

## License

This project is provided as-is for educational and development purposes.
