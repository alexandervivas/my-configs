# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04 AS os-base

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_AWSCLI=1
ARG INSTALL_JAVA=0
ARG INSTALL_MAVEN=0
ARG JAVA_VERSION=21
ARG INSTALL_GH=0
ARG TARGETARCH
ARG EXTRA_APT_PACKAGES=

COPY shared/install-os-base.sh /tmp/docker-shared/install-os-base.sh
COPY shared/create-runtime-user.sh /tmp/docker-shared/create-runtime-user.sh

# Core tools for an AI coding/dev container
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    INSTALL_JAVA="${INSTALL_JAVA}" \
    INSTALL_MAVEN="${INSTALL_MAVEN}" \
    JAVA_VERSION="${JAVA_VERSION}" \
    INSTALL_GH="${INSTALL_GH}" \
    EXTRA_APT_PACKAGES="${EXTRA_APT_PACKAGES}" \
    /bin/bash /tmp/docker-shared/install-os-base.sh

# Install AWS CLI v2 from official AWS bundle (optional)
RUN set -eux; \
    if [ "${INSTALL_AWSCLI}" = "1" ]; then \
      arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
      case "${arch}" in \
        amd64|x86_64) aws_arch="x86_64" ;; \
        arm64|aarch64) aws_arch="aarch64" ;; \
        *) echo "Unsupported architecture for AWS CLI v2: ${arch}" >&2; exit 1 ;; \
      esac; \
      curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${aws_arch}.zip" -o /tmp/awscliv2.zip; \
      unzip -q /tmp/awscliv2.zip -d /tmp; \
      /tmp/aws/install; \
      rm -rf /tmp/awscliv2.zip /tmp/aws; \
    fi

# Create a non-root user for safer defaults
ARG USERNAME=claude
ARG USER_UID=1000
ARG USER_GID=1000
RUN EXTRA_HOME_DIRS="$(printf '%s\n' \
      "/home/${USERNAME}/.cache" \
      "/home/${USERNAME}/.config" \
      "/home/${USERNAME}/.claude")" \
    USERNAME="${USERNAME}" \
    USER_UID="${USER_UID}" \
    USER_GID="${USER_GID}" \
    /bin/bash /tmp/docker-shared/create-runtime-user.sh

FROM os-base AS claude-runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=claude
ARG INSTALL_NODE=1
ARG INSTALL_CLAUDE=1
ARG NODE_MAJOR=22
ARG CLAUDE_NPM_PACKAGE=@anthropic-ai/claude-code
ARG CLAUDE_NPM_VERSION=
ARG CLAUDE_NATIVE_VERSION=latest

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"
ENV DISABLE_AUTOUPDATER=1

# Claude-specific layer: Node.js + Claude Code
RUN set -eux; \
    if [ "${INSTALL_NODE}" = "1" ]; then \
      curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
      apt-get update; \
      apt-get install -y --no-install-recommends nodejs; \
      rm -rf /var/lib/apt/lists/*; \
    fi; \
    if [ "${INSTALL_CLAUDE}" = "1" ]; then \
      install_version="${CLAUDE_NATIVE_VERSION}"; \
      if [ -n "${CLAUDE_NPM_VERSION}" ]; then \
        install_version="${CLAUDE_NPM_VERSION}"; \
      fi; \
      su "${USERNAME}" -s /bin/sh -c "curl -fsSL https://claude.ai/install.sh | bash -s -- ${install_version}"; \
      npm install -g @fission-ai/openspec@latest; \
    fi

WORKDIR /workspace
USER ${USERNAME}

# Default to the Claude CLI; override the entrypoint at runtime for debugging shells.
ENTRYPOINT ["claude"]
