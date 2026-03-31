# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04 AS os-base

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_AWSCLI=1
ARG INSTALL_JAVA=0
ARG INSTALL_MAVEN=0
ARG JAVA_VERSION=21
ARG INSTALL_GH=0
ARG TARGETARCH
ARG EXTRA_APT_PACKAGES=tar
ARG NODE_MAJOR=22

COPY shared/install-os-base.sh /tmp/docker-shared/install-os-base.sh
COPY shared/create-runtime-user.sh /tmp/docker-shared/create-runtime-user.sh

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    INSTALL_JAVA="${INSTALL_JAVA}" \
    INSTALL_MAVEN="${INSTALL_MAVEN}" \
    JAVA_VERSION="${JAVA_VERSION}" \
    INSTALL_GH="${INSTALL_GH}" \
    EXTRA_APT_PACKAGES="${EXTRA_APT_PACKAGES}" \
    /bin/bash /tmp/docker-shared/install-os-base.sh

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

ARG USERNAME=opencode
ARG USER_UID=1000
ARG USER_GID=1000
RUN EXTRA_HOME_DIRS="$(printf '%s\n' \
      "/home/${USERNAME}/.cache/opencode" \
      "/home/${USERNAME}/.config/opencode" \
      "/home/${USERNAME}/.local/share/opencode" \
      "/home/${USERNAME}/.local/state/opencode")" \
    USERNAME="${USERNAME}" \
    USER_UID="${USER_UID}" \
    USER_GID="${USER_GID}" \
    /bin/bash /tmp/docker-shared/create-runtime-user.sh

FROM os-base AS opencode-runtime

ARG USERNAME=opencode
ARG INSTALL_OPENCODE=1
ARG OPENCODE_VERSION=1.2.27
ARG TARGETARCH

ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

RUN set -eux; \
    if [ "${INSTALL_OPENCODE}" = "1" ]; then \
      arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
      case "${arch}" in \
        amd64|x86_64) opencode_arch="x64" ;; \
        arm64|aarch64) opencode_arch="arm64" ;; \
        *) echo "Unsupported architecture for opencode: ${arch}" >&2; exit 1 ;; \
      esac; \
      curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${opencode_arch}.tar.gz" -o /tmp/opencode.tar.gz; \
      tar -xzf /tmp/opencode.tar.gz -C /tmp; \
      install -m 0755 /tmp/opencode /usr/local/bin/opencode; \
      rm -rf /tmp/opencode /tmp/opencode.tar.gz; \
      curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -; \
      apt-get update; \
      apt-get install -y --no-install-recommends nodejs; \
      rm -rf /var/lib/apt/lists/*; \
      npm install -g @fission-ai/openspec@latest; \
    fi

WORKDIR /workspace
USER ${USERNAME}

ENTRYPOINT ["opencode"]
