#!/bin/bash
# Creates a Vanilla server for any Minecraft version Mojang has published,
# resolved live from the official version manifest at run time.

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
require_cmd tar

echo "Resolving Minecraft $mc_version..."
resolve_vanilla_manifest "$mc_version"

ensure_java "$JAVA_MAJOR"

mkdir -p "$server_dir"
cd "$server_dir" || exit 1

echo "Downloading Vanilla server $mc_version..."
curl -fL -o server.jar "$MC_SERVER_URL"
if [ ! -f server.jar ]; then
    echo "Error: Download failed."
    exit 1
fi

echo "eula=true" > eula.txt
printf '#!/bin/bash\n%s -Xms1024M -Xmx%s -jar server.jar nogui\n' "$JAVA_BIN" "$ram_allocation" > start.sh
chmod +x start.sh

write_meta "." "server_type=vanilla" "mc_version=$mc_version" "ram=$ram_allocation"

echo "Vanilla server for Minecraft $mc_version is ready! Navigate to '$server_dir' and run './start.sh' to start."
