#!/bin/bash

# Function to prompt for RAM allocation
get_ram_allocation() {
    echo "Calculating optimal RAM allocation..." >&2

    # Get total system memory in MB
    total_mem=$(free -m | awk '/^Mem:/{print $2}')

    # Calculate 90% of total memory
    recommended_ram=$((total_mem * 90 / 100))

    # Convert recommended RAM to GB for better user understanding
    recommended_gb=$(awk "BEGIN {printf \"%.1f\", $recommended_ram/1024}")

    # Provide the recommended RAM allocation to the user
    ram=$(dialog --inputbox \
        "Enter the amount of RAM to allocate to the server (in MB):\n\nRecommended: ${recommended_ram}MB (~${recommended_gb}GB)" \
        10 50 "${recommended_ram}M" 2>&1 >/dev/tty)

    # Validate user input
    if [[ "$ram" -lt 512 ]]; then
        echo "Warning: Allocating less than 512MB may cause performance issues." >&2
    fi

    # Only output the RAM value to stdout
    echo "$ram"
}

# Function to prompt for server name
get_server_name() {
    local name
    name=$(dialog --inputbox "Enter a name for your server:" 10 50 2>&1 >/dev/tty)
    echo "$name"
}

# Function to prompt for a Minecraft version. Versions are resolved live
# against each loader's own API when the create script runs, so any
# version that loader has published - including ones released after this
# menu was written - can be typed in here.
get_mc_version() {
    local example="$1"
    local version
    version=$(dialog --inputbox \
        "Enter the Minecraft version to install (e.g. $example):\n\nThis is looked up live, so brand-new releases work as soon as the loader publishes a build for them." \
        11 60 "$example" 2>&1 >/dev/tty)
    echo "$version"
}

# Main Menu
options=(
    1 "Vanilla"
    2 "Paper"
    3 "Fabric"
    4 "Forge"
    5 "Folia"
    6 "NeoForge"
)

choice=$(dialog --clear \
                --title "Choose a Minecraft Client" \
                --menu "Select an option using the arrow keys, or press Enter:" 15 40 7 \
                "${options[@]}" \
                2>&1 >/dev/tty)

clear

# Handle the case where the user presses 'Cancel' in the client selection dialog
if [ -z "$choice" ]; then
    echo "Exiting..."
    exit 0
fi

case $choice in
    1) server_type="vanilla";  version_example="26.2" ;;
    2) server_type="paper";    version_example="26.2" ;;
    3) server_type="fabric";   version_example="26.2" ;;
    4) server_type="forge";    version_example="26.2" ;;
    5) server_type="folia";    version_example="26.2" ;;
    6) server_type="neoforge"; version_example="26.2" ;;
esac

# Add a dialog warning message for Folia immediately after client selection
if [ "$server_type" = "folia" ]; then
    dialog --title "Warning" \
           --yesno "Folia is an experimental version of Paper, utilizing a complex threading model to enhance performance on servers with large playerbases. Some plugins and datapacks may not function as expected. Additionally, the installation process may take longer than usual.\n\nDo you want to proceed?" 11 60

    response=$?
    if [ $response -eq 1 ]; then
        # User selected 'No', return to client list
        exec "$0"
    fi
fi

# Prompt for the Minecraft version (resolved live by the create script)
server_version=$(get_mc_version "$version_example")

clear

if [[ -z "$server_version" ]]; then
    echo "No version entered. Exiting..."
    exit 0
fi

# Fabric/Forge/NeoForge each have a mod loader version that's separate
# from the Minecraft version. Offer to pin an exact one (e.g. because a
# mod requires a newer loader build than whatever is "latest" today);
# leaving it blank keeps the previous latest/recommended behavior.
loader_version=""
if [[ "$server_type" == "fabric" || "$server_type" == "forge" || "$server_type" == "neoforge" ]]; then
    loader_version=$(dialog --inputbox \
        "Optional: pin a specific $server_type loader/build version (e.g. because a mod requires a newer one than the default).\n\nLeave blank to use the latest/recommended version." \
        11 65 2>&1 >/dev/tty)
    clear
fi

# Prompt for RAM allocation
server_ram=$(get_ram_allocation)

if [[ -z "$server_ram" ]]; then
    echo "RAM allocation cannot be empty. Exiting..."
    exit 1
fi

# Prompt for server name
server_name=$(get_server_name)

if [[ -z "$server_name" ]]; then
    echo "Server name cannot be empty. Exiting..."
    exit 1
fi

# Construct the server directory name
server_dir="${server_name}_${server_type}_${server_version}"

# Locate the create_scripts directory relative to this script
# This ensures the script works no matter where it's run from.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
create_scripts_dir="$script_dir/create_scripts"

# Ensure create_scripts directory exists
if [[ ! -d "$create_scripts_dir" ]]; then
    echo "Error: create_scripts directory not found at $create_scripts_dir."
    exit 1
fi

# Clear the screen before running the create script
clear

# Every server type is backed by one generic script that resolves the
# exact build/installer for the requested version at run time.
bash "$create_scripts_dir/msc_${server_type}.sh" "$server_version" "$server_dir" "$server_ram" "$loader_version"

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to create the $server_type server for Minecraft $server_version."
    exit 1
fi

clear
echo "Server created successfully!"
