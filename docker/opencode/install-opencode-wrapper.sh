#!/usr/bin/env bash
set -euo pipefail

INSTALL_PATH="${INSTALL_PATH:-/usr/local/bin/opencode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE_PATH="${SCRIPT_DIR}/Dockerfile"
DOCKER_CONTEXT="${SCRIPT_DIR}/.."
IMAGE_NAME="${IMAGE_NAME:-opencode-dev}"

DEFAULT_AUTH_MODE="${DEFAULT_AUTH_MODE:-bedrock}"
DEFAULT_INSTALL_AWSCLI="${DEFAULT_INSTALL_AWSCLI:-1}"
DEFAULT_INSTALL_OPENCODE="${DEFAULT_INSTALL_OPENCODE:-1}"
DEFAULT_OPENCODE_VERSION="${DEFAULT_OPENCODE_VERSION:-1.2.27}"
DEFAULT_INSTALL_JAVA="${DEFAULT_INSTALL_JAVA:-0}"
DEFAULT_JAVA_VERSION="${DEFAULT_JAVA_VERSION:-21}"
DEFAULT_INSTALL_MAVEN="${DEFAULT_INSTALL_MAVEN:-0}"
DEFAULT_INSTALL_GH="${DEFAULT_INSTALL_GH:-0}"
DEFAULT_MOUNT_AWS="${DEFAULT_MOUNT_AWS:-auto}"
DEFAULT_MOUNT_SSH="${DEFAULT_MOUNT_SSH:-1}"
DEFAULT_MOUNT_GITCONFIG="${DEFAULT_MOUNT_GITCONFIG:-1}"
DEFAULT_MOUNT_M2="${DEFAULT_MOUNT_M2:-1}"
DEFAULT_MOUNT_OPENCODE_CONFIG="${DEFAULT_MOUNT_OPENCODE_CONFIG:-1}"
INTERACTIVE="${INTERACTIVE:-1}"

usage() {
  cat <<EOF
Usage: ./install-opencode-wrapper.sh

Interactive installer that writes a Docker-backed opencode wrapper to:
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
  local normalized_answer

  if [[ "${INTERACTIVE}" != "1" || ! -t 0 ]]; then
    printf '%s' "$(normalize_csv_tokens "${default_value}")"
    return
  fi

  while true; do
    printf '%s [empty=none]: ' "${prompt}" >&2
    IFS= read -r answer
    normalized_answer="$(normalize_csv_tokens "${answer}")"
    if [[ -z "${normalized_answer}" || "${normalized_answer}" == "none" ]]; then
      printf '%s' "none"
      return
    fi
    if [[ "${normalized_answer}" == "all" ]]; then
      printf '%s' "$(printf '%s\n' "${options[@]}" | grep -vx 'none' | grep -vx 'all' | xargs)"
      return
    fi
    valid="1"
    for token in ${normalized_answer}; do
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
      printf '%s' "${normalized_answer}"
      return
    fi
  done
}

collect_defaults() {
  IMAGE_NAME="$(prompt_text "Docker image repository" "${IMAGE_NAME}")"
  INSTALL_PATH="$(prompt_text "Wrapper install path" "${INSTALL_PATH}")"
  DEFAULT_AUTH_MODE="$(prompt_choice "Default auth mode" "${DEFAULT_AUTH_MODE}" bedrock other)"
  DEFAULT_OPENCODE_VERSION="$(prompt_text "Default opencode version" "${DEFAULT_OPENCODE_VERSION}")"
  local default_extras="none"
  local default_mounts=""
  local selected_extras
  local selected_mounts

  if [[ "${DEFAULT_INSTALL_JAVA}" == "1" ]]; then
    default_extras="java"
  fi
  if [[ "${DEFAULT_INSTALL_GH}" == "1" ]]; then
    default_extras="${default_extras:+${default_extras} }git"
  fi

  if [[ "${DEFAULT_MOUNT_AWS}" != "off" && "${DEFAULT_MOUNT_AWS}" != "0" ]]; then
    default_mounts="aws"
  fi
  if [[ "${DEFAULT_MOUNT_SSH}" == "1" ]]; then
    default_mounts="${default_mounts:+${default_mounts} }ssh"
  fi
  if [[ "${DEFAULT_MOUNT_OPENCODE_CONFIG}" == "1" ]]; then
    default_mounts="${default_mounts:+${default_mounts} }opencode"
  fi
  default_mounts="$(normalize_csv_tokens "${default_mounts}")"
  default_mounts="${default_mounts:-none}"

  selected_extras="$(prompt_multi_choice "Select image extras (comma-separated: java, git, all, none)" "${default_extras}" java git all none)"
  if [[ "${DEFAULT_AUTH_MODE}" == "bedrock" ]]; then
    DEFAULT_INSTALL_AWSCLI="1"
  else
    DEFAULT_INSTALL_AWSCLI="0"
  fi
  DEFAULT_INSTALL_JAVA="0"
  DEFAULT_INSTALL_MAVEN="0"
  DEFAULT_INSTALL_GH="0"
  if csv_has_token "${selected_extras}" "java"; then
    DEFAULT_INSTALL_JAVA="1"
    DEFAULT_INSTALL_MAVEN="1"
    DEFAULT_JAVA_VERSION="$(prompt_choice "Default Java version" "${DEFAULT_JAVA_VERSION}" 17 21)"
  fi
  if csv_has_token "${selected_extras}" "git"; then
    DEFAULT_INSTALL_GH="1"
  fi

  selected_mounts="$(prompt_multi_choice "Select host mounts (comma-separated: aws, ssh, opencode, all, none)" "${default_mounts}" aws ssh opencode all none)"
  DEFAULT_MOUNT_AWS="off"
  DEFAULT_MOUNT_SSH="0"
  DEFAULT_MOUNT_GITCONFIG="1"
  DEFAULT_MOUNT_M2="${DEFAULT_INSTALL_MAVEN}"
  DEFAULT_MOUNT_OPENCODE_CONFIG="0"
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
  if csv_has_token "${selected_mounts}" "opencode"; then
    DEFAULT_MOUNT_OPENCODE_CONFIG="1"
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
DEFAULT_INSTALL_OPENCODE="${DEFAULT_INSTALL_OPENCODE}"
DEFAULT_OPENCODE_VERSION="${DEFAULT_OPENCODE_VERSION}"
DEFAULT_INSTALL_JAVA="${DEFAULT_INSTALL_JAVA}"
DEFAULT_JAVA_VERSION="${DEFAULT_JAVA_VERSION}"
DEFAULT_INSTALL_MAVEN="${DEFAULT_INSTALL_MAVEN}"
DEFAULT_INSTALL_GH="${DEFAULT_INSTALL_GH}"
DEFAULT_MOUNT_AWS="${DEFAULT_MOUNT_AWS}"
DEFAULT_MOUNT_SSH="${DEFAULT_MOUNT_SSH}"
DEFAULT_MOUNT_GITCONFIG="${DEFAULT_MOUNT_GITCONFIG}"
DEFAULT_MOUNT_M2="${DEFAULT_MOUNT_M2}"
DEFAULT_MOUNT_OPENCODE_CONFIG="${DEFAULT_MOUNT_OPENCODE_CONFIG}"
HOST_CONFIG_DIR="\${HOME}/.config/opencode"
HOST_CACHE_DIR="\${HOME}/.cache/opencode"
HOST_DATA_DIR="\${HOME}/.local/share/opencode"
HOST_STATE_DIR="\${HOME}/.local/state/opencode"
HOST_M2_DIR="\${HOME}/.m2"

sanitize_tag_value() {
  printf '%s' "\$1" | tr '/: ' '-' | tr -cd '[:alnum:]._-'
}

add_env_if_set() {
  local var_name="\$1"
  if [[ -n "\${!var_name:-}" ]]; then
    docker_args+=(-e "\${var_name}=\${!var_name}")
  fi
}

inject_github_git_config() {
  local token="\${GITHUB_TOKEN:-\${GH_TOKEN:-}}"
  [[ -z "\${token}" ]] && return
  docker_args+=(
    -e "GIT_CONFIG_COUNT=1"
    -e "GIT_CONFIG_KEY_0=url.https://x-access-token:\${token}@github.com/.insteadOf"
    -e "GIT_CONFIG_VALUE_0=https://github.com/"
  )
}

find_gitenv() {
  local dir="\$(pwd)"
  local depth=0
  while [[ "\${depth}" -le 2 ]]; do
    if [[ -f "\${dir}/.gitenv" ]]; then
      printf '%s\n' "\${dir}/.gitenv"
      return
    fi
    [[ "\${dir}" == "/" ]] && return
    dir="\$(dirname "\${dir}")"
    (( depth++ ))
  done
}

load_gitenv() {
  local gitenv_file
  gitenv_file="\$(find_gitenv)"
  [[ -z "\${gitenv_file}" ]] && return
  local key value
  while IFS='=' read -r key value; do
    [[ -z "\${key}" || "\${key}" == \#* ]] && continue
    key="\$(printf '%s' "\${key}" | xargs)"
    [[ -z "\${key}" ]] && continue
    if [[ -z "\${!key:-}" ]]; then
      docker_args+=(-e "\${key}=\${value}")
    fi
  done < "\${gitenv_file}"
}

build_image_name() {
  local image_repo="\${OPENCODE_DOCKER_IMAGE_REPO:-\${IMAGE_REPO}}"
  local install_awscli="\${OPENCODE_DOCKER_INSTALL_AWSCLI:-\${DEFAULT_INSTALL_AWSCLI}}"
  local install_opencode="\${OPENCODE_DOCKER_INSTALL_OPENCODE:-\${DEFAULT_INSTALL_OPENCODE}}"
  local install_java="\${OPENCODE_DOCKER_INSTALL_JAVA:-\${DEFAULT_INSTALL_JAVA}}"
  local java_version="\${OPENCODE_DOCKER_JAVA_VERSION:-\${DEFAULT_JAVA_VERSION}}"
  local install_maven="\${OPENCODE_DOCKER_INSTALL_MAVEN:-\${DEFAULT_INSTALL_MAVEN}}"
  local install_gh="\${OPENCODE_DOCKER_INSTALL_GH:-\${DEFAULT_INSTALL_GH}}"
  local opencode_version="\${OPENCODE_DOCKER_OPENCODE_VERSION:-\${DEFAULT_OPENCODE_VERSION}}"

  if [[ -n "\${OPENCODE_DOCKER_IMAGE_NAME:-}" ]]; then
    printf '%s\n' "\${OPENCODE_DOCKER_IMAGE_NAME}"
    return
  fi

  opencode_version="\$(sanitize_tag_value "\${opencode_version}")"
  printf '%s:%s\n' "\${image_repo}" "aws\${install_awscli}-java\${install_java}-j\${java_version}-maven\${install_maven}-gh\${install_gh}-opencode\${install_opencode}-o\${opencode_version}"
}

ensure_image() {
  local image_name="\$1"
  local build_args=(
    --build-arg "INSTALL_AWSCLI=\${OPENCODE_DOCKER_INSTALL_AWSCLI:-\${DEFAULT_INSTALL_AWSCLI}}"
    --build-arg "INSTALL_OPENCODE=\${OPENCODE_DOCKER_INSTALL_OPENCODE:-\${DEFAULT_INSTALL_OPENCODE}}"
    --build-arg "OPENCODE_VERSION=\${OPENCODE_DOCKER_OPENCODE_VERSION:-\${DEFAULT_OPENCODE_VERSION}}"
    --build-arg "INSTALL_JAVA=\${OPENCODE_DOCKER_INSTALL_JAVA:-\${DEFAULT_INSTALL_JAVA}}"
    --build-arg "JAVA_VERSION=\${OPENCODE_DOCKER_JAVA_VERSION:-\${DEFAULT_JAVA_VERSION}}"
    --build-arg "INSTALL_MAVEN=\${OPENCODE_DOCKER_INSTALL_MAVEN:-\${DEFAULT_INSTALL_MAVEN}}"
    --build-arg "INSTALL_GH=\${OPENCODE_DOCKER_INSTALL_GH:-\${DEFAULT_INSTALL_GH}}"
  )

  if ! docker image inspect "\${image_name}" >/dev/null 2>&1 || [[ "\${OPENCODE_DOCKER_FORCE_BUILD:-0}" == "1" ]]; then
    DOCKER_BUILDKIT=1 docker build "\${build_args[@]}" -t "\${image_name}" -f "\${DOCKERFILE_PATH}" "\${DOCKER_CONTEXT}"
  fi
}

main() {
  local image_name
  local auth_mode="\${OPENCODE_DOCKER_AUTH_MODE:-\${DEFAULT_AUTH_MODE}}"
  local mount_aws="\${OPENCODE_DOCKER_MOUNT_AWS:-\${DEFAULT_MOUNT_AWS}}"
  local mount_ssh="\${OPENCODE_DOCKER_MOUNT_SSH:-\${DEFAULT_MOUNT_SSH}}"
  local mount_gitconfig="\${OPENCODE_DOCKER_MOUNT_GITCONFIG:-\${DEFAULT_MOUNT_GITCONFIG}}"
  local mount_m2="\${OPENCODE_DOCKER_MOUNT_M2:-\${DEFAULT_MOUNT_M2}}"
  local mount_opencode_config="\${OPENCODE_DOCKER_MOUNT_OPENCODE_CONFIG:-\${DEFAULT_MOUNT_OPENCODE_CONFIG}}"
  local aws_mount_mode="ro"
  local docker_args=(
    run
    --rm
    --init
    -i
    --workdir "\${WORKSPACE_ROOT}"
    -v "\$(pwd):\${WORKSPACE_ROOT}"
    -e "AWS_PROFILE=\${AWS_PROFILE:-}"
    -e "AWS_REGION=\${AWS_REGION:-}"
    -e "AWS_DEFAULT_REGION=\${AWS_DEFAULT_REGION:-}"
    -e "TERM=\${TERM:-xterm-256color}"
    -e "COLORTERM=\${COLORTERM:-truecolor}"
    -e "LANG=\${LANG:-C.UTF-8}"
    -e "CLICOLOR=\${CLICOLOR:-1}"
    -e "CLICOLOR_FORCE=\${CLICOLOR_FORCE:-1}"
    -e "FORCE_COLOR=\${FORCE_COLOR:-1}"
  )

  image_name="\$(build_image_name)"
  mkdir -p "\${HOST_CACHE_DIR}" "\${HOST_DATA_DIR}" "\${HOST_STATE_DIR}"

  if [[ "\${mount_opencode_config}" == "1" ]]; then
    mkdir -p "\${HOST_CONFIG_DIR}"
  fi

  if [[ "\${auth_mode}" == "bedrock" ]]; then
    aws_mount_mode="rw"
  fi

  if [[ -t 0 && -t 1 ]]; then
    docker_args+=(-t)
  fi

  add_env_if_set LC_ALL
  add_env_if_set LC_CTYPE
  add_env_if_set TERM_PROGRAM
  add_env_if_set TERM_PROGRAM_VERSION
  add_env_if_set TERM_SESSION_ID
  add_env_if_set GITHUB_TOKEN
  add_env_if_set GH_TOKEN
  add_env_if_set GH_HOST
  add_env_if_set GITHUB_HOST
  load_gitenv
  inject_github_git_config

  if [[ "\${mount_opencode_config}" == "1" ]]; then
    docker_args+=(-v "\${HOST_CONFIG_DIR}:/home/opencode/.config/opencode")
  fi
  docker_args+=(-v "\${HOST_CACHE_DIR}:/home/opencode/.cache/opencode")
  docker_args+=(-v "\${HOST_DATA_DIR}:/home/opencode/.local/share/opencode")
  docker_args+=(-v "\${HOST_STATE_DIR}:/home/opencode/.local/state/opencode")

  if [[ "\${mount_m2}" == "1" && -d "\${HOST_M2_DIR}" ]]; then
    docker_args+=(-v "\${HOST_M2_DIR}:/home/opencode/.m2")
  fi

  if [[ "\${mount_aws}" == "auto" ]]; then
    if [[ "\${auth_mode}" == "bedrock" && -d "\${HOME}/.aws" ]]; then
      docker_args+=(-v "\${HOME}/.aws:/home/opencode/.aws:\${aws_mount_mode}")
    fi
  elif [[ "\${mount_aws}" == "1" || "\${mount_aws}" == "on" ]]; then
    if [[ -d "\${HOME}/.aws" ]]; then
      docker_args+=(-v "\${HOME}/.aws:/home/opencode/.aws:\${aws_mount_mode}")
    fi
  fi

  if [[ "\${mount_ssh}" == "1" && -d "\${HOME}/.ssh" ]]; then
    docker_args+=(-v "\${HOME}/.ssh:/home/opencode/.ssh:ro")
  fi

  if [[ "\${mount_gitconfig}" == "1" && -f "\${HOME}/.gitconfig" ]]; then
    docker_args+=(-v "\${HOME}/.gitconfig:/home/opencode/.gitconfig:ro")
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

printf 'Installed Docker opencode wrapper to %s\n' "${INSTALL_PATH}"
