#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-/usr/local/bin/claude}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CONTEXT="${SCRIPT_DIR}"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"
IMAGE_NAME="${IMAGE_NAME:-claude-dev}"

DEFAULT_AUTH_MODE="${DEFAULT_AUTH_MODE:-anthropic}"
DEFAULT_INSTALL_AWSCLI="${DEFAULT_INSTALL_AWSCLI:-1}"
DEFAULT_INSTALL_NODE="${DEFAULT_INSTALL_NODE:-1}"
DEFAULT_INSTALL_CLAUDE="${DEFAULT_INSTALL_CLAUDE:-1}"
DEFAULT_CLAUDE_VERSION="${DEFAULT_CLAUDE_VERSION:-latest}"
DEFAULT_NODE_MAJOR="${DEFAULT_NODE_MAJOR:-22}"
DEFAULT_INSTALL_JAVA="${DEFAULT_INSTALL_JAVA:-0}"
DEFAULT_JAVA_VERSION="${DEFAULT_JAVA_VERSION:-21}"
DEFAULT_INSTALL_MAVEN="${DEFAULT_INSTALL_MAVEN:-0}"
DEFAULT_MOUNT_AWS="${DEFAULT_MOUNT_AWS:-auto}"
DEFAULT_MOUNT_SSH="${DEFAULT_MOUNT_SSH:-1}"
DEFAULT_MOUNT_GITCONFIG="${DEFAULT_MOUNT_GITCONFIG:-1}"
DEFAULT_MOUNT_M2="${DEFAULT_MOUNT_M2:-1}"
INTERACTIVE="${INTERACTIVE:-1}"

usage() {
  cat <<EOF
Usage: ./install-claude-wrapper.sh

Interactive installer that writes a Docker-backed Claude wrapper to:
  ${INSTALL_PATH}

Behavior:
- asks for default image/runtime options
- writes those defaults into the generated wrapper
- still allows runtime overrides via environment variables

Useful environment variables:
  INSTALL_PATH             Override the output wrapper path
  IMAGE_NAME               Override the default Docker image repository
  INTERACTIVE=0            Skip prompts and use defaults/env values
EOF
}

prompt_text() {
  local prompt="$1"
  local default_value="$2"
  local answer

  if [[ "${INTERACTIVE}" != "1" || ! -t 0 ]]; then
    printf '%s' "${default_value}"
    return
  fi

  read -r -p "${prompt} [${default_value}]: " answer
  printf '%s' "${answer:-${default_value}}"
}

prompt_choice() {
  local prompt="$1"
  local default_value="$2"
  shift 2
  local options=("$@")
  local answer
  local option

  if [[ "${INTERACTIVE}" != "1" || ! -t 0 ]]; then
    printf '%s' "${default_value}"
    return
  fi

  while true; do
    printf '%s [%s]: ' "${prompt}" "${default_value}" >&2
    IFS= read -r answer
    answer="${answer:-${default_value}}"
    for option in "${options[@]}"; do
      if [[ "${answer}" == "${option}" ]]; then
        printf '%s' "${answer}"
        return
      fi
    done
  done
}

normalize_csv_tokens() {
  local value="$1"
  printf '%s' "${value}" | tr ',' ' ' | xargs
}

csv_has_token() {
  local csv_value="$1"
  local wanted="$2"
  local token
  for token in $(normalize_csv_tokens "${csv_value}"); do
    if [[ "${token}" == "${wanted}" ]]; then
      return 0
    fi
  done
  return 1
}

prompt_multi_choice() {
  local prompt="$1"
  local default_value="$2"
  shift 2
  local options=("$@")
  local answer
  local token
  local option
  local valid

  if [[ "${INTERACTIVE}" != "1" || ! -t 0 ]]; then
    printf '%s' "$(normalize_csv_tokens "${default_value}")"
    return
  fi

  while true; do
    printf '%s [%s]: ' "${prompt}" "${default_value}" >&2
    IFS= read -r answer
    answer="$(normalize_csv_tokens "${answer:-${default_value}}")"
    valid="1"
    for token in ${answer}; do
      if [[ -z "${token}" || "${token}" == "none" ]]; then
        continue
      fi
      option=""
      for option in "${options[@]}"; do
        if [[ "${token}" == "${option}" ]]; then
          break
        fi
      done
      if [[ -z "${option}" || "${token}" != "${option}" ]]; then
        valid="0"
        break
      fi
    done
    if [[ "${valid}" == "1" ]]; then
      printf '%s' "${answer}"
      return
    fi
  done
}

collect_defaults() {
  IMAGE_NAME="$(prompt_text "Docker image repository" "${IMAGE_NAME}")"
  INSTALL_PATH="$(prompt_text "Wrapper install path" "${INSTALL_PATH}")"
  DEFAULT_AUTH_MODE="$(prompt_choice "Default auth mode" "${DEFAULT_AUTH_MODE}" anthropic bedrock)"
  DEFAULT_CLAUDE_VERSION="$(prompt_text "Default Claude version" "${DEFAULT_CLAUDE_VERSION}")"
  local default_extras="none"
  local default_mounts=""
  local selected_extras
  local selected_mounts

  if [[ "${DEFAULT_INSTALL_JAVA}" == "1" ]]; then
    default_extras="java"
  fi

  if [[ "${DEFAULT_MOUNT_AWS}" != "off" && "${DEFAULT_MOUNT_AWS}" != "0" ]]; then
    default_mounts="aws"
  fi
  if [[ "${DEFAULT_MOUNT_SSH}" == "1" ]]; then
    default_mounts="${default_mounts:+${default_mounts},}ssh"
  fi
  if [[ "${DEFAULT_MOUNT_GITCONFIG}" == "1" ]]; then
    default_mounts="${default_mounts:+${default_mounts},}gitconfig"
  fi
  if [[ "${DEFAULT_MOUNT_M2}" == "1" ]]; then
    default_mounts="${default_mounts:+${default_mounts},}m2"
  fi
  default_mounts="${default_mounts:-none}"

  selected_extras="$(prompt_multi_choice "Select image extras (comma-separated: java, none)" "${default_extras}" java none)"
  if [[ "${DEFAULT_AUTH_MODE}" == "bedrock" ]]; then
    DEFAULT_INSTALL_AWSCLI="1"
  else
    DEFAULT_INSTALL_AWSCLI="0"
  fi
  DEFAULT_INSTALL_JAVA="0"
  DEFAULT_INSTALL_MAVEN="0"
  if csv_has_token "${selected_extras}" "java"; then
    DEFAULT_INSTALL_JAVA="1"
    DEFAULT_INSTALL_MAVEN="1"
    DEFAULT_JAVA_VERSION="$(prompt_choice "Default Java version" "${DEFAULT_JAVA_VERSION}" 17 21)"
  fi

  selected_mounts="$(prompt_multi_choice "Select host mounts (comma-separated: aws, ssh, gitconfig, m2, none)" "${default_mounts}" aws ssh gitconfig m2 none)"
  DEFAULT_MOUNT_AWS="off"
  DEFAULT_MOUNT_SSH="0"
  DEFAULT_MOUNT_GITCONFIG="0"
  DEFAULT_MOUNT_M2="0"
  if [[ "${DEFAULT_AUTH_MODE}" == "bedrock" ]] || csv_has_token "${selected_mounts}" "aws"; then
    if [[ "${DEFAULT_AUTH_MODE}" == "bedrock" ]]; then
      DEFAULT_MOUNT_AWS="auto"
    else
      DEFAULT_MOUNT_AWS="on"
    fi
  fi
  if csv_has_token "${selected_mounts}" "ssh"; then
    DEFAULT_MOUNT_SSH="1"
  fi
  if csv_has_token "${selected_mounts}" "gitconfig"; then
    DEFAULT_MOUNT_GITCONFIG="1"
  fi
  if csv_has_token "${selected_mounts}" "m2"; then
    DEFAULT_MOUNT_M2="1"
  fi
}

write_wrapper() {
  cat >"${INSTALL_PATH}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

IMAGE_REPO="${IMAGE_NAME}"
DOCKER_CONTEXT="${DOCKER_CONTEXT}"
DOCKERFILE_PATH="${DOCKERFILE_PATH}"
WORKSPACE_ROOT="/workspace"
DEFAULT_AUTH_MODE="${DEFAULT_AUTH_MODE}"
DEFAULT_INSTALL_AWSCLI="${DEFAULT_INSTALL_AWSCLI}"
DEFAULT_INSTALL_NODE="${DEFAULT_INSTALL_NODE}"
DEFAULT_INSTALL_CLAUDE="${DEFAULT_INSTALL_CLAUDE}"
DEFAULT_CLAUDE_VERSION="${DEFAULT_CLAUDE_VERSION}"
DEFAULT_NODE_MAJOR="${DEFAULT_NODE_MAJOR}"
DEFAULT_INSTALL_JAVA="${DEFAULT_INSTALL_JAVA}"
DEFAULT_JAVA_VERSION="${DEFAULT_JAVA_VERSION}"
DEFAULT_INSTALL_MAVEN="${DEFAULT_INSTALL_MAVEN}"
DEFAULT_MOUNT_AWS="${DEFAULT_MOUNT_AWS}"
DEFAULT_MOUNT_SSH="${DEFAULT_MOUNT_SSH}"
DEFAULT_MOUNT_GITCONFIG="${DEFAULT_MOUNT_GITCONFIG}"
DEFAULT_MOUNT_M2="${DEFAULT_MOUNT_M2}"
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
  local install_awscli="\${CLAUDE_DOCKER_INSTALL_AWSCLI:-\${DEFAULT_INSTALL_AWSCLI}}"
  local install_node="\${CLAUDE_DOCKER_INSTALL_NODE:-\${DEFAULT_INSTALL_NODE}}"
  local install_claude="\${CLAUDE_DOCKER_INSTALL_CLAUDE:-\${DEFAULT_INSTALL_CLAUDE}}"
  local node_major="\${CLAUDE_DOCKER_NODE_MAJOR:-\${DEFAULT_NODE_MAJOR}}"
  local install_java="\${CLAUDE_DOCKER_INSTALL_JAVA:-\${DEFAULT_INSTALL_JAVA}}"
  local java_version="\${CLAUDE_DOCKER_JAVA_VERSION:-\${DEFAULT_JAVA_VERSION}}"
  local install_maven="\${CLAUDE_DOCKER_INSTALL_MAVEN:-\${DEFAULT_INSTALL_MAVEN}}"
  local claude_version="\${CLAUDE_DOCKER_CLAUDE_VERSION:-\${DEFAULT_CLAUDE_VERSION}}"

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
    --build-arg "INSTALL_AWSCLI=\${CLAUDE_DOCKER_INSTALL_AWSCLI:-\${DEFAULT_INSTALL_AWSCLI}}"
    --build-arg "INSTALL_NODE=\${CLAUDE_DOCKER_INSTALL_NODE:-\${DEFAULT_INSTALL_NODE}}"
    --build-arg "INSTALL_CLAUDE=\${CLAUDE_DOCKER_INSTALL_CLAUDE:-\${DEFAULT_INSTALL_CLAUDE}}"
    --build-arg "NODE_MAJOR=\${CLAUDE_DOCKER_NODE_MAJOR:-\${DEFAULT_NODE_MAJOR}}"
    --build-arg "CLAUDE_NATIVE_VERSION=\${CLAUDE_DOCKER_CLAUDE_VERSION:-\${DEFAULT_CLAUDE_VERSION}}"
    --build-arg "INSTALL_JAVA=\${CLAUDE_DOCKER_INSTALL_JAVA:-\${DEFAULT_INSTALL_JAVA}}"
    --build-arg "JAVA_VERSION=\${CLAUDE_DOCKER_JAVA_VERSION:-\${DEFAULT_JAVA_VERSION}}"
    --build-arg "INSTALL_MAVEN=\${CLAUDE_DOCKER_INSTALL_MAVEN:-\${DEFAULT_INSTALL_MAVEN}}"
  )

  if ! docker image inspect "\${image_name}" >/dev/null 2>&1 || [[ "\${CLAUDE_DOCKER_FORCE_BUILD:-0}" == "1" ]]; then
    DOCKER_BUILDKIT=1 docker build "\${build_args[@]}" -t "\${image_name}" -f "\${DOCKERFILE_PATH}" "\${DOCKER_CONTEXT}"
  fi
}

main() {
  local image_name
  local auth_mode="\${CLAUDE_DOCKER_AUTH_MODE:-\${DEFAULT_AUTH_MODE}}"
  local mount_aws="\${CLAUDE_DOCKER_MOUNT_AWS:-\${DEFAULT_MOUNT_AWS}}"
  local mount_ssh="\${CLAUDE_DOCKER_MOUNT_SSH:-\${DEFAULT_MOUNT_SSH}}"
  local mount_gitconfig="\${CLAUDE_DOCKER_MOUNT_GITCONFIG:-\${DEFAULT_MOUNT_GITCONFIG}}"
  local mount_m2="\${CLAUDE_DOCKER_MOUNT_M2:-\${DEFAULT_MOUNT_M2}}"
  local aws_mount_mode="ro"
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

  if [[ "\${auth_mode}" == "bedrock" ]]; then
    aws_mount_mode="rw"
  fi

  if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-t)
  fi

  if [[ -f "\${HOST_CLAUDE_FILE}" ]]; then
    docker_args+=(-v "\${HOST_CLAUDE_FILE}:/home/claude/.claude.json")
  fi

  if [[ "\${mount_m2}" == "1" && -d "\${HOST_M2_DIR}" ]]; then
    docker_args+=(-v "\${HOST_M2_DIR}:/home/claude/.m2")
  fi

  if [[ "\${mount_aws}" == "auto" ]]; then
    if [[ "\${auth_mode}" == "bedrock" && -d "\${HOME}/.aws" ]]; then
      docker_args+=(-v "\${HOME}/.aws:/home/claude/.aws:\${aws_mount_mode}")
      docker_args+=(-e "CLAUDE_CODE_USE_BEDROCK=1")
    fi
  elif [[ "\${mount_aws}" == "1" || "\${mount_aws}" == "on" ]]; then
    if [[ -d "\${HOME}/.aws" ]]; then
      docker_args+=(-v "\${HOME}/.aws:/home/claude/.aws:\${aws_mount_mode}")
    fi
    if [[ "\${auth_mode}" == "bedrock" ]]; then
      docker_args+=(-e "CLAUDE_CODE_USE_BEDROCK=1")
    fi
  fi

  if [[ "\${mount_ssh}" == "1" && -d "\${HOME}/.ssh" ]]; then
    docker_args+=(-v "\${HOME}/.ssh:/home/claude/.ssh:ro")
  fi

  if [[ "\${mount_gitconfig}" == "1" && -f "\${HOME}/.gitconfig" ]]; then
    docker_args+=(-v "\${HOME}/.gitconfig:/home/claude/.gitconfig:ro")
  fi

  ensure_image "\${image_name}"
  exec docker "\${docker_args[@]}" "\${image_name}" "\$@"
}

main "\$@"
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

collect_defaults

TARGET_DIR="$(dirname "${INSTALL_PATH}")"

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "error: target directory does not exist: ${TARGET_DIR}" >&2
  exit 1
fi

write_wrapper
chmod 0755 "${INSTALL_PATH}"

printf 'Installed Docker Claude wrapper to %s\n' "${INSTALL_PATH}"
