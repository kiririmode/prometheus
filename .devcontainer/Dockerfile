FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV HADOLINT_VERSION v2.12.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    # Install shellcheck and unzip (required for AWS CLI)
    && apt-get install -y --no-install-recommends shellcheck unzip \
    # Install hadolint
    && curl -SL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64" -o /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint \
    # Install AWS CLI v2
    && ARCH=$(uname -m) \
    && if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then \
        curl -SL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"; \
    else \
        curl -SL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"; \
    fi \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
