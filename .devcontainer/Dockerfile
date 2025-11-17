FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

ENV HADOLINT_VERSION v2.12.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
    # Install shellcheck
    && apt-get install -y --no-install-recommends shellcheck \
    # Install hadolint
    && curl -SL "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-arm64" -o /usr/local/bin/hadolint \
    && chmod +x /usr/local/bin/hadolint \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*
