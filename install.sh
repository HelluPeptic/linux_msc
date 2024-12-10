#!/bin/bash

# Define the installation directory
INSTALL_DIR="/usr/local/bin"

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root or use sudo."
  exit 1
fi

echo "Installing scripts and directories to $INSTALL_DIR..."

# Install/Update Dialog
sudo apt install dialog

# Get the directory where this script is located
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# Copy all files and directories (including create_scripts) from the repository to the installation directory
for item in "$SCRIPT_DIR"/*; do
  if [ -f "$item" ]; then
    # If it's a file, copy it and make it executable
    cp "$item" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$(basename "$item")"
    echo "Installed $(basename "$item") to $INSTALL_DIR"
  elif [ -d "$item" ]; then
    # If it's a directory, copy it and its contents recursively
    cp -r "$item" "$INSTALL_DIR/"
    echo "Installed directory $(basename "$item") to $INSTALL_DIR"
  fi
done

# Remove the repository to save space
echo "Cleaning up..."
cd "$SCRIPT_DIR/.." || exit
rm -rf "$SCRIPT_DIR"

echo "Installation complete! Scripts and directories are now available globally, and the repository has been removed."
