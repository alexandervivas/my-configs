#!/usr/bin/env bash
if ! command -v ansible &>/dev/null; then
  echo "Installing Ansible..."
  brew install ansible
else
  echo "Ansible already installed. Skipping."
fi

if ! command -v fzf &>/dev/null; then
  echo "Installing fzf..."
  brew install fzf
else
  echo "fzf already installed. Skipping."
fi
