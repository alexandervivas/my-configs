#!/usr/bin/env bash
if xcode-select -p &>/dev/null; then
  echo "Xcode CLT already installed. Skipping."
  return 0
fi

echo "Installing Xcode Command Line Tools..."
xcode-select --install

echo "Waiting for Xcode CLT installation to complete..."
until xcode-select -p &>/dev/null; do
  sleep 5
done

echo "Xcode CLT installed."
