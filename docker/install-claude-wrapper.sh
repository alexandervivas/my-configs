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

IMAGE_REPO="${IMAGE_NAME}"
DOCKER_CONTEXT="${DOCKER_CONTEXT}"
DOCKERFILE_PATH="${DOCKERFILE_PATH}"
WORKSPACE_ROOT="/workspace"
HOST_CLAUDE_DIR="\${HOME}/.claude"
HOST_CLAUDE_FILE="\${HOME}/.claude.json"
HOST_CACHE_DIR="\${HOME}/.cache/claude-docker"
HOST_CONFIG_DIR="\${HOME}/.config/claude-docker"
HOST_M2_DIR="\${HOME}/.m2"

sanitize_tag_value() {
  printf '%s' "\$1" | tr '/: ' '-' | tr -cd '[:alnum:]._-'
}

build_image_name() {
  local image_repo="\${CLAUDE_DOCKER_IMAGE_REPO:-\${IMAGE_REPO}}"
  local install_awscli="\${CLAUDE_DOCKER_INSTALL_AWSCLI:-1}"
  local install_node="\${CLAUDE_DOCKER_INSTALL_NODE:-1}"
  local install_claude="\${CLAUDE_DOCKER_INSTALL_CLAUDE:-1}"
  local node_major="\${CLAUDE_DOCKER_NODE_MAJOR:-22}"
  local install_java="\${CLAUDE_DOCKER_INSTALL_JAVA:-0}"
  local java_version="\${CLAUDE_DOCKER_JAVA_VERSION:-21}"
  local install_maven="\${CLAUDE_DOCKER_INSTALL_MAVEN:-0}"
  local claude_version="\${CLAUDE_DOCKER_CLAUDE_VERSION:-latest}"

  if [[ -n "\${CLAUDE_DOCKER_IMAGE_NAME:-}" ]]; then
    printf '%s\n' "\${CLAUDE_DOCKER_IMAGE_NAME}"
    return
  fi

  claude_version="\$(sanitize_tag_value "\${claude_version}")"
  printf '%s:%s\n' "\${image_repo}" "aws\${install_awscli}-node\${install_node}-n\${node_major}-java\${install_java}-j\${java_version}-maven\${install_maven}-claude\${install_claude}-c\${claude_version}"
}

ensure_image() {
  local image_name="\$1"
  local build_args=(
    --build-arg "INSTALL_AWSCLI=\${CLAUDE_DOCKER_INSTALL_AWSCLI:-1}"
    --build-arg "INSTALL_NODE=\${CLAUDE_DOCKER_INSTALL_NODE:-1}"
    --build-arg "INSTALL_CLAUDE=\${CLAUDE_DOCKER_INSTALL_CLAUDE:-1}"
    --build-arg "NODE_MAJOR=\${CLAUDE_DOCKER_NODE_MAJOR:-22}"
    --build-arg "CLAUDE_NATIVE_VERSION=\${CLAUDE_DOCKER_CLAUDE_VERSION:-latest}"
    --build-arg "INSTALL_JAVA=\${CLAUDE_DOCKER_INSTALL_JAVA:-0}"
    --build-arg "JAVA_VERSION=\${CLAUDE_DOCKER_JAVA_VERSION:-21}"
    --build-arg "INSTALL_MAVEN=\${CLAUDE_DOCKER_INSTALL_MAVEN:-0}"
  )

  if ! docker image inspect "\${image_name}" >/dev/null 2>&1 || [[ "\${CLAUDE_DOCKER_FORCE_BUILD:-0}" == "1" ]]; then
    DOCKER_BUILDKIT=1 docker build "\${build_args[@]}" -t "\${image_name}" -f "\${DOCKERFILE_PATH}" "\${DOCKER_CONTEXT}"
  fi
}

main() {
  local image_name
  local auth_mode="\${CLAUDE_DOCKER_AUTH_MODE:-anthropic}"
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
    -e "CLAUDE_CODE_USE_BEDROCK=\${CLAUDE_CODE_USE_BEDROCK:-}"
    -e "AWS_PROFILE=\${AWS_PROFILE:-}"
    -e "AWS_REGION=\${AWS_REGION:-}"
    -e "AWS_DEFAULT_REGION=\${AWS_DEFAULT_REGION:-}"
    -e "BEDROCK_MODEL_ID=\${BEDROCK_MODEL_ID:-}"
    -e "TERM=\${TERM:-xterm-256color}"
    -e "COLORTERM=\${COLORTERM:-truecolor}"
    -e "CLICOLOR=\${CLICOLOR:-1}"
    -e "CLICOLOR_FORCE=\${CLICOLOR_FORCE:-1}"
    -e "FORCE_COLOR=\${FORCE_COLOR:-1}"
  )

  image_name="\$(build_image_name)"
  mkdir -p "\${HOST_CLAUDE_DIR}" "\${HOST_CACHE_DIR}" "\${HOST_CONFIG_DIR}"

  if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-t)
  fi

  if [[ -f "\${HOST_CLAUDE_FILE}" ]]; then
    docker_args+=(-v "\${HOST_CLAUDE_FILE}:/home/claude/.claude.json")
  fi

  if [[ -d "\${HOST_M2_DIR}" ]]; then
    docker_args+=(-v "\${HOST_M2_DIR}:/home/claude/.m2")
  fi

  if [[ "\${auth_mode}" == "bedrock" && -d "\${HOME}/.aws" ]]; then
    docker_args+=(-v "\${HOME}/.aws:/home/claude/.aws:ro")
    docker_args+=(-e "CLAUDE_CODE_USE_BEDROCK=1")
  fi

  if [[ -d "\${HOME}/.ssh" ]]; then
    docker_args+=(-v "\${HOME}/.ssh:/home/claude/.ssh:ro")
  fi

  if [[ -f "\${HOME}/.gitconfig" ]]; then
    docker_args+=(-v "\${HOME}/.gitconfig:/home/claude/.gitconfig:ro")
  fi

  ensure_image "\${image_name}"
  exec docker "\${docker_args[@]}" "\${image_name}" "\$@"
}

main "\$@"
EOF

chmod 0755 "${INSTALL_PATH}"

printf 'Installed Docker Claude wrapper to %s\n' "${INSTALL_PATH}"
