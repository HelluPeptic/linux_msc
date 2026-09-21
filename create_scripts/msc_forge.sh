#!/bin/bash
# Creates (or re-installs, in place) a Forge server for any Minecraft
# version. By default it uses Forge's recommended (falling back to
# latest) build; pass a 4th argument to pin an exact Forge build
# instead (also how msc-servers.sh performs an in-place loader update).

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/msc_common.sh"

mc_version="$1"
server_dir="$2"
ram_allocation="$3"
forge_version_override="$4"

if [[ -z "$mc_version" || -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Usage: $0 <minecraft_version> <server_directory> <ram_allocation> [forge_version]"
    exit 1
fi

require_cmd curl
require_cmd jq "sudo apt install jq"

echo "Resolving Java requirement for Minecraft $mc_version..."
resolve_vanilla_manifest "$mc_version"
ensure_java "$JAVA_MAJOR"

if [ -n "$forge_version_override" ]; then
    echo "Checking that Forge $forge_version_override exists for Minecraft $mc_version..."
    metadata=$(curl -fsSL "https://maven.minecraftforge.net/net/minecraftforge/forge/maven-metadata.xml")
    match=$(echo "$metadata" | grep -F "<version>${mc_version}-${forge_version_override}</version>")
    if [ -z "$match" ]; then
        echo "Error: Forge $forge_version_override was not published for Minecraft $mc_version."
        exit 1
    fi
    forge_version="$forge_version_override"
    echo "Using Forge $forge_version (pinned)."
else
    echo "Looking up the Forge version for Minecraft $mc_version..."
    promos=$(curl -fsSL "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json")
    forge_version=$(echo "$promos" | jq -r --arg v "${mc_version}-recommended" '.promos[$v] // empty')
    if [ -z "$forge_version" ]; then
        forge_version=$(echo "$promos" | jq -r --arg v "${mc_version}-latest" '.promos[$v] // empty')
    fi
    if [ -z "$forge_version" ]; then
        echo "Error: Forge has no build published for Minecraft $mc_version yet."
        exit 1
    fi
    echo "Using Forge $forge_version."
fi

installer_name="forge-${mc_version}-${forge_version}-installer.jar"
installer_url="https://maven.minecraftforge.net/net/minecraftforge/forge/${mc_version}-${forge_version}/${installer_name}"

mkdir -p "$server_dir"
cd "$server_dir" || exit 1

echo "Downloading Forge installer..."
curl -fL -o "$installer_name" "$installer_url"
if [ ! -f "$installer_name" ]; then
    echo "Error: Failed to download the Forge installer."
    exit 1
fi

echo "Running Forge installer for Minecraft $mc_version..."
"$JAVA_BIN" -jar "$installer_name" --installServer

echo "eula=true" > eula.txt
echo "-Xms1024M" > user_jvm_args.txt
echo "-Xmx$ram_allocation" >> user_jvm_args.txt

printf '#!/usr/bin/env sh\n# Add custom program arguments (such as nogui) to the next line before the "$@" or pass them to this script directly\n%s @user_jvm_args.txt @libraries/net/minecraftforge/forge/%s-%s/unix_args.txt "$@"\n' "$JAVA_BIN" "$mc_version" "$forge_version" > start.sh
chmod +x start.sh

write_meta "." "server_type=forge" "mc_version=$mc_version" "loader_version=$forge_version" "ram=$ram_allocation"

echo "Forge server for Minecraft $mc_version ($forge_version) is ready! Navigate to '$server_dir' and run './start.sh' to start."
