#!/usr/bin/env bash
set -euo pipefail

: "${USERNAME:?USERNAME is required}"
: "${USER_UID:=1000}"
: "${USER_GID:=1000}"
: "${EXTRA_HOME_DIRS:=}"

if getent group "${USER_GID}" >/dev/null; then
  primary_group="$(getent group "${USER_GID}" | cut -d: -f1)"
else
  primary_group="${USERNAME}"
  groupadd --gid "${USER_GID}" "${primary_group}"
fi

if id -u "${USERNAME}" >/dev/null 2>&1; then
  usermod --gid "${USER_GID}" --shell /bin/zsh "${USERNAME}"
elif getent passwd "${USER_UID}" >/dev/null; then
  existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"
  usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home --gid "${USER_GID}" --shell /bin/zsh "${existing_user}"
  if getent group "${existing_user}" >/dev/null 2>&1; then
    groupmod --new-name "${USERNAME}" "${existing_user}"
  fi
  primary_group="$(id -gn "${USERNAME}")"
else
  useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}" -s /bin/zsh
fi

usermod --groups "" "${USERNAME}"
mkdir -p /workspace "/home/${USERNAME}"

if [[ -n "${EXTRA_HOME_DIRS}" ]]; then
  while IFS= read -r path; do
    [[ -n "${path}" ]] && mkdir -p "${path}"
  done < <(printf '%s\n' "${EXTRA_HOME_DIRS}")
fi

chown -R "${USERNAME}:${primary_group}" /workspace "/home/${USERNAME}"
