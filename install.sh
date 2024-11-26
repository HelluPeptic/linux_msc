#!/bin/bash

# Define the installation directory
INSTALL_DIR="/usr/local/bin"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root or use sudo."
  exit 1
fi

echo "Installing scripts to $INSTALL_DIR..."

# Get the directory where this script is located
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Copy all files from the repository to the installation directory
for file in "$SCRIPT_DIR"/*; do
  if [ -f "$file" ]; then
    cp "$file" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$(basename "$file")"
    echo "Installed $(basename "$file") to $INSTALL_DIR"
  fi
done

echo "Installation complete! Scripts are now available globally."
