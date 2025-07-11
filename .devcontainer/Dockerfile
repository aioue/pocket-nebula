FROM mcr.microsoft.com/devcontainers/base:noble

ARG USERNAME=vscode
ARG USER_HOME_PATH="/home/${USERNAME}"

# https://code.visualstudio.com/remote/advancedcontainers/reduce-docker-warnings
# Validate that this Dockerfile is being built within VS Code devcontainer context
# This prevents the container from being built in other Docker contexts where 
# devcontainer-specific features and assumptions wouldn't be available
ARG vscodedevcontainer
RUN if [[ -z "$vscodedevcontainer" ]] ; then printf "\nERROR: This Dockerfile needs to be built with VS Code !" && exit 1; else printf "VS Code is detected: $vscodedevcontainer"; fi

# Add a custom CA certificate to trust store (must be done before package installation)
# If you server use a non-trusted cert, it must added to the CA to avoid SSL errors
#COPY TRUSTED_CERT.crt /usr/local/share/ca-certificates/TRUSTED_CERT.crt
#RUN apt-get -y install ca-certificates && update-ca-certificates
# Set CA bundle path after certificate is installed and trust store is updated
#RUN echo "export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt" >> ${USER_HOME_PATH}/.bashrc

# Install system packages and OpenNebula CLI in optimized single layer
# Using DEBIAN_FRONTEND=noninteractive prevents prompts during package installation
# Installing ruby packages first, then use dynamic version detection for OpenNebula CLI
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        apt-utils \
        dialog \
        plocate \
        ruby-dev \
        rubygems \
        curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/*

# Copy the version detection script and make it executable, used by setup.sh to install the correct version of OpenNebula CLI
COPY detect-opennebula-version.sh /usr/local/bin/detect-opennebula-version.sh
RUN chmod +x /usr/local/bin/detect-opennebula-version.sh

# Configure complete shell environment, pipx completion, and persistent history in single layer
# Combines all bash configuration to minimize layers and improve build cache efficiency
# Follows VS Code devcontainer best practices: https://code.visualstudio.com/remote/advancedcontainers/persist-bash-history
#   Configure persistent bash history for both users in optimized layers
RUN echo "eval \"\$(register-python-argcomplete pipx)\"" >> ${USER_HOME_PATH}/.bashrc \
    && mkdir -p ${USER_HOME_PATH}/.one \
    && SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && echo "$SNIPPET" >> "/root/.bashrc" \
    && echo "$SNIPPET" >> "${USER_HOME_PATH}/.bashrc" \
    && mkdir -p /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory
