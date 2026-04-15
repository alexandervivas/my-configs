#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/scripts/install_xcode_clt.sh"
source "$SCRIPT_DIR/scripts/install_brew.sh"
source "$SCRIPT_DIR/scripts/install_ansible.sh"

echo ""
echo "Select laptop profile:"

PROFILES=("Adevinta" "Personal")
SELECTED=$(printf '%s\n' "${PROFILES[@]}" | fzf --height=10 --border --prompt="Profile: ")

case "$SELECTED" in
  "Adevinta") INVENTORY="adevinta" ;;
  "Personal")  INVENTORY="personal" ;;
  *) echo "No profile selected. Aborting."; exit 1 ;;
esac

echo "Running setup for: $SELECTED"
ansible-playbook "$SCRIPT_DIR/playbooks/site.yml" -i "$SCRIPT_DIR/inventory/${INVENTORY}.yml"
