FROM mcr.microsoft.com/devcontainers/base:noble

ARG USERNAME=vscode
ARG USER_HOME_PATH="/home/${USERNAME}"

# https://code.visualstudio.com/remote/advancedcontainers/reduce-docker-warnings
ARG vscode
RUN if [[ -z "$devcontainercli" ]] ; then printf "\nERROR: This Dockerfile needs to be built with VS Code !" && exit 1; else printf "VS Code is detected: $devcontainercli"; fi

RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1

# Install ruby
RUN apt install -y \
    ruby-dev \
    rubygems
    # && rm -rf ~/.cache/* /usr/local/share/man /tmp/*

# Install OpenNebula ruby CLI
RUN gem install opennebula-cli

# Enable pipx completion
RUN echo "eval \"\$(register-python-argcomplete pipx)\"" >> ${USER_HOME_PATH}/.bashrc

# Setup OpenNebula creds path for the Ruby CLI authentication
RUN mkdir ${USER_HOME_PATH}/.one

# Persist bash history
# https://code.visualstudio.com/remote/advancedcontainers/persist-bash-history
## persist for root user
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && echo "$SNIPPET" >> "/root/.bashrc"
## persist for vscode user
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir /commandhistory \
    && touch /commandhistory/.bash_history \
    && chown -R $USERNAME /commandhistory \
    && echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
