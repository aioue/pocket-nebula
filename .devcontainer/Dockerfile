# Thin per-project layer over the shared base image.
#
# Everything common lives in ghcr.io/aioue/pocket-nebula-base, built from
# images/base/ in this repo. Pinned to the MAJOR tag so an ordinary rebuild
# picks up shared fixes with no edit here; a breaking change gets a new major.
#
# This file exists even when empty: it is the designated place for genuinely
# project-specific image layers (an extra apt package, a private CA cert), so
# that such things never get added to the shared base by mistake.
FROM ghcr.io/aioue/pocket-nebula-base:v1

# https://code.visualstudio.com/remote/advancedcontainers/reduce-docker-warnings
# Validate that this Dockerfile is being built within a VS Code devcontainer
# context, which prevents it being built in other Docker contexts where
# devcontainer-specific features and assumptions would not hold.
ARG vscodedevcontainer
RUN if [ -z "$vscodedevcontainer" ]; then \
        printf "ERROR: This Dockerfile needs to be built with VS Code!\n" && exit 1; \
    else \
        printf "VS Code is detected: %s\n" "$vscodedevcontainer"; \
    fi
