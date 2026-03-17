# syntax=docker/dockerfile:1.7
FROM ubuntu:24.04 AS os-base

ARG DEBIAN_FRONTEND=noninteractive
ARG INSTALL_AWSCLI=1
ARG INSTALL_JAVA=0
ARG INSTALL_MAVEN=0
ARG JAVA_VERSION=21
ARG TARGETARCH

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    set -eux; \
    apt-get update; \
    packages="\
      ca-certificates \
      curl \
      git \
      jq \
      less \
      ncurses-term \
      openssh-client \
      python3 \
      python3-pip \
      ripgrep \
      tar \
      unzip \
      vim \
      wget \
      zsh"; \
    if [ "${INSTALL_JAVA}" = "1" ] || [ "${INSTALL_MAVEN}" = "1" ]; then \
      case "${JAVA_VERSION}" in \
        17) java_package="openjdk-17-jdk" ;; \
        21) java_package="openjdk-21-jdk" ;; \
        *) echo "Unsupported JAVA_VERSION: ${JAVA_VERSION}" >&2; exit 1 ;; \
      esac; \
      packages="${packages} ${java_package}"; \
    fi; \
    if [ "${INSTALL_MAVEN}" = "1" ]; then \
      packages="${packages} maven"; \
    fi; \
    apt-get install -y --no-install-recommends ${packages}; \
    rm -rf /var/lib/apt/lists/*

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
RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null; then \
      primary_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
      primary_group="${USERNAME}"; \
      groupadd --gid "${USER_GID}" "${primary_group}"; \
    fi; \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
      usermod --gid "${USER_GID}" --shell /bin/zsh "${USERNAME}"; \
    elif getent passwd "${USER_UID}" >/dev/null; then \
      existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
      usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home --gid "${USER_GID}" --shell /bin/zsh "${existing_user}"; \
      if getent group "${existing_user}" >/dev/null 2>&1; then \
        groupmod --new-name "${USERNAME}" "${existing_user}"; \
      fi; \
      primary_group="$(id -gn "${USERNAME}")"; \
    else \
      useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" -s /bin/zsh; \
    fi; \
    usermod --groups "" "${USERNAME}"; \
    chown -R "${USERNAME}:${primary_group}" "/home/${USERNAME}"

RUN mkdir -p \
      /workspace \
      /home/${USERNAME}/.cache/opencode \
      /home/${USERNAME}/.config/opencode \
      /home/${USERNAME}/.local/share/opencode \
      /home/${USERNAME}/.local/state/opencode \
    && chown -R ${USERNAME}:${USER_GID} /workspace /home/${USERNAME}

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
    fi

WORKDIR /workspace
USER ${USERNAME}

ENTRYPOINT ["opencode"]
