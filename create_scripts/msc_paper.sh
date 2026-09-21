#!/bin/bash
# Creates a Paper server for any Minecraft version PaperMC has a build for,
# resolved live from the PaperMC Fill API at run time.

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

echo "Looking up the latest Paper build for $mc_version..."
build_json=$(curl -fsSL "https://fill.papermc.io/v3/projects/paper/versions/$mc_version/builds/latest")
build_id=$(echo "$build_json" | jq -r '.id // empty')
if [ -z "$build_id" ]; then
    echo "Error: No Paper build found for Minecraft $mc_version. Paper may not support this version (yet)."
    exit 1
fi

channel=$(echo "$build_json" | jq -r '.channel')
jar_url=$(echo "$build_json" | jq -r '.downloads."server:default".url')
jar_name=$(echo "$build_json" | jq -r '.downloads."server:default".name')
echo "Found Paper build #$build_id ($channel channel)."

mkdir -p "$server_dir"
cd "$server_dir" || exit 1

echo "Downloading $jar_name..."
curl -fL -o "$jar_name" "$jar_url"
if [ ! -f "$jar_name" ]; then
    echo "Error: Download failed."
    exit 1
fi

echo "eula=true" > eula.txt
printf '#!/bin/bash\n%s -Xms1024M -Xmx%s -jar %s nogui\n' "$JAVA_BIN" "$ram_allocation" "$jar_name" > start.sh
chmod +x start.sh

write_meta "." "server_type=paper" "mc_version=$mc_version" "loader_version=$build_id" "ram=$ram_allocation"

echo "Paper server for Minecraft $mc_version (build $build_id) is ready! Navigate to '$server_dir' and run './start.sh' to start."
