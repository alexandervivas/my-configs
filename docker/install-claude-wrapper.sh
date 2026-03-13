#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-/usr/local/bin/claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CONTEXT="${SCRIPT_DIR}"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"
IMAGE_NAME="${IMAGE_NAME:-claude-dev}"

usage() {
  cat <<EOF
Usage: ./install-claude-wrapper.sh

Writes a host wrapper to ${INSTALL_PATH} that builds and runs Claude from:
  ${DOCKERFILE_PATH}

Optional environment variables:
  INSTALL_PATH  Override the output wrapper path
  IMAGE_NAME    Override the Docker image tag used by the wrapper
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ ! -f "${DOCKERFILE_PATH}" ]]; then
  echo "error: Dockerfile not found at ${DOCKERFILE_PATH}" >&2
  exit 1
fi

TARGET_DIR="$(dirname "${INSTALL_PATH}")"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "error: target directory does not exist: ${TARGET_DIR}" >&2
  exit 1
fi

cat >"${INSTALL_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME}"
DOCKER_CONTEXT="${DOCKER_CONTEXT}"
DOCKERFILE_PATH="${DOCKERFILE_PATH}"
WORKSPACE_ROOT="/workspace"
HOST_CLAUDE_DIR="\${HOME}/.claude"
HOST_CACHE_DIR="\${HOME}/.cache/claude-docker"
HOST_CONFIG_DIR="\${HOME}/.config/claude-docker"

ensure_image() {
  if ! docker image inspect "\${IMAGE_NAME}" >/dev/null 2>&1; then
    docker build -t "\${IMAGE_NAME}" -f "\${DOCKERFILE_PATH}" "\${DOCKER_CONTEXT}"
  fi
}

main() {
  local docker_args=(
    run
    --rm
    --init
    -i
    --workdir "\${WORKSPACE_ROOT}"
    -v "\$(pwd):\${WORKSPACE_ROOT}"
    -v "\${HOST_CLAUDE_DIR}:/home/claude/.claude"
    -v "\${HOST_CACHE_DIR}:/home/claude/.cache"
    -v "\${HOST_CONFIG_DIR}:/home/claude/.config"
    -e "ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY:-}"
    -e "ANTHROPIC_BASE_URL=\${ANTHROPIC_BASE_URL:-}"
    -e "AWS_PROFILE=\${AWS_PROFILE:-}"
    -e "AWS_REGION=\${AWS_REGION:-}"
    -e "AWS_DEFAULT_REGION=\${AWS_DEFAULT_REGION:-}"
    -e "BEDROCK_MODEL_ID=\${BEDROCK_MODEL_ID:-}"
  )

  mkdir -p "\${HOST_CLAUDE_DIR}" "\${HOST_CACHE_DIR}" "\${HOST_CONFIG_DIR}"

  if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-t)
  fi

  if [[ -d "\${HOME}/.aws" ]]; then
    docker_args+=(-v "\${HOME}/.aws:/home/claude/.aws:ro")
  fi

  if [[ -d "\${HOME}/.ssh" ]]; then
    docker_args+=(-v "\${HOME}/.ssh:/home/claude/.ssh:ro")
  fi

  if [[ -f "\${HOME}/.gitconfig" ]]; then
    docker_args+=(-v "\${HOME}/.gitconfig:/home/claude/.gitconfig:ro")
  fi

  ensure_image
  exec docker "\${docker_args[@]}" "\${IMAGE_NAME}" "\$@"
}

main "\$@"
EOF

chmod 0755 "${INSTALL_PATH}"

printf 'Installed Docker Claude wrapper to %s\n' "${INSTALL_PATH}"
