#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INTERACTIVE="${INTERACTIVE:-1}"
SELECTED_AGENT="${SELECTED_AGENT:-${AGENT:-}}"

usage() {
  cat <<EOF
Usage: ./docker/install-wrapper.sh [agent]

Interactive wrapper installer entrypoint.

Agents:
  claude
  opencode

Behavior:
- asks which agent wrapper to generate when no agent is provided
- dispatches to the concrete installer for the selected agent
- preserves the current environment so installer defaults can still be overridden

Useful environment variables:
  INTERACTIVE=0      Skip prompts and use env/default values
  SELECTED_AGENT     Preselect the agent without passing a positional argument
  AGENT              Alias for SELECTED_AGENT
EOF
}

normalize_agent() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | xargs
}

resolve_installer() {
  local agent="$1"
  case "${agent}" in
    claude) printf '%s\n' "${SCRIPT_DIR}/claude/install-claude-wrapper.sh" ;;
    opencode) printf '%s\n' "${SCRIPT_DIR}/opencode/install-opencode-wrapper.sh" ;;
    *) return 1 ;;
  esac
}

prompt_agent() {
  local answer

  if [[ "${INTERACTIVE}" != "1" || ! -t 0 ]]; then
    echo "error: agent must be provided when INTERACTIVE=0 (use 'claude' or 'opencode')" >&2
    exit 1
  fi

  while true; do
    printf 'Select agent [claude/opencode]: ' >&2
    IFS= read -r answer
    answer="$(normalize_agent "${answer}")"
    case "${answer}" in
      claude|opencode)
        printf '%s\n' "${answer}"
        return
        ;;
    esac
  done
}

main() {
  local agent="${1:-${SELECTED_AGENT}}"
  local installer

  case "${agent}" in
    -h|--help)
      usage
      exit 0
      ;;
  esac

  agent="$(normalize_agent "${agent}")"
  if [[ -z "${agent}" ]]; then
    agent="$(prompt_agent)"
  fi

  if ! installer="$(resolve_installer "${agent}")"; then
    echo "error: unsupported agent '${agent}'" >&2
    usage >&2
    exit 1
  fi

  if [[ $# -gt 0 ]]; then
    shift
  fi

  exec /usr/bin/env bash "${installer}" "$@"
}

main "$@"
