#!/bin/bash
# Creates a Fabric server for any Minecraft version, using the latest
# Fabric installer resolved live from the Fabric meta API at run time.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/msc_common.sh"

mc_version="$1"
server_dir="$2"
ram_allocation="$3"

if [[ -z "$mc_version" || -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Usage: $0 <minecraft_version> <server_directory> <ram_allocation>"
    exit 1
fi

require_cmd curl
require_cmd jq "sudo apt install jq"

echo "Resolving Java requirement for Minecraft $mc_version..."
resolve_vanilla_manifest "$mc_version"
ensure_java "$JAVA_MAJOR"

is_known=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/game" | jq -r --arg v "$mc_version" '.[] | select(.version == $v) | .version')
if [ -z "$is_known" ]; then
    echo "Warning: Minecraft $mc_version is not in Fabric's known game version list yet. Trying anyway."
fi

installer_url=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/installer" | jq -r '.[0].url')
if [ -z "$installer_url" ] || [ "$installer_url" == "null" ]; then
    echo "Error: Could not resolve the latest Fabric installer."
    exit 1
fi

mkdir -p "$server_dir"
cd "$server_dir" || exit 1

echo "Downloading Fabric installer..."
curl -fL -o fabric-installer.jar "$installer_url"
if [ ! -f fabric-installer.jar ]; then
    echo "Error: Failed to download the Fabric installer."
    exit 1
fi

echo "Running Fabric installer for Minecraft $mc_version..."
"$JAVA_BIN" -jar fabric-installer.jar server -mcversion "$mc_version" -downloadMinecraft
if [ ! -f fabric-server-launch.jar ]; then
    echo "Error: Fabric installation failed. Minecraft $mc_version may not be supported by Fabric yet."
    exit 1
fi

echo "eula=true" > eula.txt
printf '#!/bin/bash\n%s -Xms1024M -Xmx%s -jar fabric-server-launch.jar nogui\n' "$JAVA_BIN" "$ram_allocation" > start.sh
chmod +x start.sh

echo "Fabric server for Minecraft $mc_version is ready! Navigate to '$server_dir' and run './start.sh' to start."
