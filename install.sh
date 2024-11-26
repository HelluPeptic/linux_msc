#!/bin/bash

# Define the target directory
TARGET_DIR="/usr/local/bin"

# Copy the script to the target directory
echo "Installing scripts to $TARGET_DIR..."

# Check for permissions
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or use sudo to install."
  exit 1
fi

# Install the script
cp msc "$TARGET_DIR/"
chmod +x "$TARGET_DIR/msc"

echo "Installation complete! You can now use 'msc' from the command line."
