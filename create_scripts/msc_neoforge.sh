#!/bin/bash
# Creates a NeoForge server for any Minecraft version NeoForge has
# published, resolved live from NeoForge's maven metadata at run time.

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

# NeoForge drops the leading "1." that older Minecraft versions had
# (1.21.4 -> 21.4.x). The calendar-based scheme (26.2, ...) has no
# leading "1." to drop, so it's used as-is.
neo_prefix="${mc_version#1.}"
neo_prefix_re=$(printf '%s' "$neo_prefix" | sed 's/\./\\./g')

echo "Looking up the NeoForge version for Minecraft $mc_version..."
metadata=$(curl -fsSL "https://maven.neoforged.net/releases/net/neoforged/neoforge/maven-metadata.xml")
neoforge_version=$(echo "$metadata" | grep -oP "(?<=<version>)${neo_prefix_re}(\.[0-9]+)+(?=</version>)" | sort -V | tail -n 1)

if [ -z "$neoforge_version" ]; then
    echo "Error: NeoForge has no build published for Minecraft $mc_version yet."
    exit 1
fi
echo "Using NeoForge $neoforge_version."

installer_name="neoforge-${neoforge_version}-installer.jar"
installer_url="https://maven.neoforged.net/releases/net/neoforged/neoforge/${neoforge_version}/${installer_name}"

mkdir -p "$server_dir"
cd "$server_dir" || exit 1

echo "Downloading NeoForge installer..."
curl -fL -o "$installer_name" "$installer_url"
if [ ! -f "$installer_name" ]; then
    echo "Error: Failed to download the NeoForge installer."
    exit 1
fi

echo "Running NeoForge installer for Minecraft $mc_version..."
"$JAVA_BIN" -jar "$installer_name" --installServer

echo "eula=true" > eula.txt
echo "-Xms1024M" > user_jvm_args.txt
echo "-Xmx$ram_allocation" >> user_jvm_args.txt

printf '#!/usr/bin/env sh\n# Add custom program arguments (such as nogui) to the next line before the "$@" or pass them to this script directly\n%s @user_jvm_args.txt @libraries/net/neoforged/neoforge/%s/unix_args.txt "$@"\n' "$JAVA_BIN" "$neoforge_version" > start.sh
chmod +x start.sh

echo "NeoForge server for Minecraft $mc_version ($neoforge_version) is ready! Navigate to '$server_dir' and run './start.sh' to start."
