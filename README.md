# Pocket Nebula

OpenNebula Devcontainer preconfigured with the OpenNebula CLI, and Ansible.

# Setup

1. Ensure OpenNebula environment variables are set on your local host (used for Ansible authentication)

    ```shell
    # Place in your shell rc file (e.g. ~/.zshrc)
    export ONE_USERNAME=foo
    export ONE_PASSWORD=bar

    export ONE_XMLRPC="https://opennebula.host/RPC2"
    export ONE_URL="https://opennebula.host/RPC2"
    export ONEFLOW_URL="https://opennebula.host:2474"
    ```

1. Ensure OpenNebula credentials are set in `~/.one/one_auth` (used for Ruby CLI authentication)

1. Ensure VSCode is installed, with the [Dev Containers Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

1. Open this repo in VSCode and allow it to build the files in a Devcontainer.

    When built, open a new terminal in VSCode, and ensure the host variables have loaded into your container.

    ```shell
    vscode ➜ /pocket-nebula (main) $ env | grep ONE
    ONE_USERNAME=foo
    ONE_PASSWORD=bar
    ONE_XMLRPC=https://opennebula.host/RPC2
    ONE_URL=https://opennebula.host/RPC2
    ONEFLOW_URL=https://opennebula.host:2474
    ```

    If they have not loaded, make sure they are present locally, then quit and restart VSCode.

# Usage

To use the CLI and Ansible tooling, open a terminal inside your VSCode Dev Container

## Ruby CLI

```
onevm list
```

## Ansible CLI

```shell
ansible-inventory --inventory inventory/opennebula --graph

ansible-playbook --inventory inventory/opennebula catalog-guests.yml
```
