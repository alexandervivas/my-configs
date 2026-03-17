#!/usr/bin/env bash
set -euo pipefail

: "${INSTALL_JAVA:=0}"
: "${INSTALL_MAVEN:=0}"
: "${JAVA_VERSION:=21}"
: "${EXTRA_APT_PACKAGES:=}"

packages=(
  ca-certificates
  curl
  git
  jq
  less
  ncurses-term
  openssh-client
  python3
  python3-pip
  ripgrep
  unzip
  vim
  wget
  zsh
)

if [[ -n "${EXTRA_APT_PACKAGES}" ]]; then
  # Intentional word splitting so callers can pass a plain package list.
  # shellcheck disable=SC2206
  extra_packages=( ${EXTRA_APT_PACKAGES} )
  packages+=("${extra_packages[@]}")
fi

if [[ "${INSTALL_JAVA}" == "1" || "${INSTALL_MAVEN}" == "1" ]]; then
  case "${JAVA_VERSION}" in
    17) packages+=(openjdk-17-jdk) ;;
    21) packages+=(openjdk-21-jdk) ;;
    *) echo "Unsupported JAVA_VERSION: ${JAVA_VERSION}" >&2; exit 1 ;;
  esac
fi

if [[ "${INSTALL_MAVEN}" == "1" ]]; then
  packages+=(maven)
fi

apt-get update
apt-get install -y --no-install-recommends "${packages[@]}"
rm -rf /var/lib/apt/lists/*
