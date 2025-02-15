FROM gitpod/workspace-full

USER gitpod

# Install custom tools, runtime, etc.
RUN sudo apt-get update \
    && sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
    && sudo rm -rf /var/lib/apt/lists/*
