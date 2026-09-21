#!/bin/bash
# Creates (or re-installs, in place) a Fabric server for any Minecraft
# version. By default it resolves the latest stable loader version;
# pass a 4th argument to pin an exact loader version instead (also how
# msc-servers.sh performs an in-place loader update).

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/msc_common.sh"

mc_version="$1"
server_dir="$2"
ram_allocation="$3"
loader_version="$4"

if [[ -z "$mc_version" || -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Usage: $0 <minecraft_version> <server_directory> <ram_allocation> [loader_version]"
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

# Resolve the exact loader version up front (rather than letting the
# installer pick its own default) so it's known for certain afterwards -
# re-running the installer in an existing directory doesn't clean up the
# previous loader's library folder, so trying to detect the installed
# version from what's on disk afterward can pick up a stale one.
loader_list=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader")
if [ -n "$loader_version" ]; then
    loader_exists=$(echo "$loader_list" | jq -r --arg v "$loader_version" '.[] | select(.version == $v) | .version')
    if [ -z "$loader_exists" ]; then
        echo "Error: Fabric loader version '$loader_version' does not exist."
        echo "See https://fabricmc.net/develop/versions/ for the full list."
        exit 1
    fi
    echo "Pinning Fabric loader $loader_version."
else
    loader_version=$(echo "$loader_list" | jq -r '[.[] | select(.stable == true)][0].version')
    if [ -z "$loader_version" ] || [ "$loader_version" == "null" ]; then
        echo "Error: Could not resolve the latest stable Fabric loader version."
        exit 1
    fi
    echo "No loader version given, using the latest stable one: $loader_version."
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
"$JAVA_BIN" -jar fabric-installer.jar server -mcversion "$mc_version" -loader "$loader_version" -downloadMinecraft
if [ ! -f fabric-server-launch.jar ]; then
    echo "Error: Fabric installation failed. Minecraft $mc_version may not be supported by Fabric yet, or the loader version isn't compatible."
    exit 1
fi

echo "eula=true" > eula.txt
printf '#!/bin/bash\n%s -Xms1024M -Xmx%s -jar fabric-server-launch.jar nogui\n' "$JAVA_BIN" "$ram_allocation" > start.sh
chmod +x start.sh

write_meta "." "server_type=fabric" "mc_version=$mc_version" "loader_version=$loader_version" "ram=$ram_allocation"

echo "Fabric server for Minecraft $mc_version (loader $loader_version) is ready! Navigate to '$server_dir' and run './start.sh' to start."
