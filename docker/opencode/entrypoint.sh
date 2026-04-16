#!/usr/bin/env bash
set -e

# This script runs as root, fixes permissions on mounted volumes, then drops to opencode user

# Ensure directories exist
mkdir -p \
  /home/opencode/.cache/opencode \
  /home/opencode/.config/opencode \
  /home/opencode/.local/share/opencode \
  /home/opencode/.local/state/opencode

# Fix ownership of mounted directories (writable ones)
chown -R opencode:opencode \
  /home/opencode/.cache/opencode \
  /home/opencode/.config/opencode \
  /home/opencode/.local/share/opencode \
  /home/opencode/.local/state/opencode \
  2>/dev/null || true

# Fix ownership of read-only mounted directories if they exist
[ -d /home/opencode/.aws ] && chown -R opencode:opencode /home/opencode/.aws 2>/dev/null || true
[ -d /home/opencode/.ssh ] && chown -R opencode:opencode /home/opencode/.ssh 2>/dev/null || true
[ -f /home/opencode/.gitconfig ] && chown opencode:opencode /home/opencode/.gitconfig 2>/dev/null || true
[ -d /home/opencode/.config/gh ] && chown -R opencode:opencode /home/opencode/.config/gh 2>/dev/null || true
[ -d /home/opencode/.m2 ] && chown -R opencode:opencode /home/opencode/.m2 2>/dev/null || true

# Drop to opencode user and run the command
exec gosu opencode "$@"
