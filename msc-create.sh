#!/bin/bash

# Function to prompt for server name
get_server_name() {
    local name
    name=$(dialog --inputbox "Enter a name for your server:" 10 50 2>&1 >/dev/tty)
    echo "$name"
}

# Main Menu
options=(
    1 "Vanilla"
    2 "Paper"
    3 "Fabric"
    4 "Forge"
    5 "Folia"
    6 "Quit"
    
)

choice=$(dialog --clear \
                --title "Choose a Minecraft Client" \
                --menu "Select an option using the arrow keys, or press Enter:" 15 40 6 \
                "${options[@]}" \
                2>&1 >/dev/tty)

clear

case $choice in
    1) server_type="vanilla" ;;
    2) server_type="paper" ;;
    3) server_type="fabric" ;;
    4) server_type="forge" ;;
    5) server_type="folia" ;;
    6) echo "Exiting..."; exit 0 ;;
esac

# Prompt for Minecraft version
versions=(
    1 "1.21.4"
    2 "1.21.1"
    3 "1.20.4"
    4 "1.20.1"
    5 "Quit"
)

version_choice=$(dialog --clear \
                        --title "Choose a Minecraft Version" \
                        --menu "Select an option using the arrow keys, or press Enter:" 15 40 4 \
                        "${versions[@]}" \
                        2>&1 >/dev/tty)

clear

case $version_choice in
    1) server_version="1.21.4" ;;
    2) server_version="1.21.1" ;;
    3) server_version="1.20.4" ;;
    4) server_version="1.20.1" ;;
    5) echo "Exiting..."; exit 0 ;;
esac

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

# Execute the specific creation script based on server type and version
case $server_type in
    "vanilla")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_vanilla_1.21.4.sh" "$server_dir" ;;
            "1.21.1") bash "$create_scripts_dir/msc_vanilla_1.21.1.sh" "$server_dir" ;;
            "1.20.4") bash "$create_scripts_dir/msc_vanilla_1.20.4.sh" "$server_dir" ;;
            "1.20.1") bash "$create_scripts_dir/msc_vanilla_1.20.1.sh" "$server_dir" ;;
        esac
        ;;
    "paper")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_paper_1.21.4.sh" "$server_dir" ;;
            "1.21.1") bash "$create_scripts_dir/msc_paper_1.21.1.sh" "$server_dir" ;;
            "1.20.4") bash "$create_scripts_dir/msc_paper_1.20.4.sh" "$server_dir" ;;
            "1.20.1") bash "$create_scripts_dir/msc_paper_1.20.1.sh" "$server_dir" ;;
        esac
        ;;
    "fabric")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_fabric_1.21.4.sh" "$server_dir" ;;
            "1.21.1") bash "$create_scripts_dir/msc_fabric_1.21.1.sh" "$server_dir" ;;
            "1.20.4") bash "$create_scripts_dir/msc_fabric_1.20.4.sh" "$server_dir" ;;
            "1.20.1") bash "$create_scripts_dir/msc_fabric_1.20.1.sh" "$server_dir" ;;
        esac
        ;;
    "forge")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_forge_1.21.4.sh" "$server_dir" ;;
            "1.21.1") bash "$create_scripts_dir/msc_forge_1.21.1.sh" "$server_dir" ;;
            "1.20.4") bash "$create_scripts_dir/msc_forge_1.20.4.sh" "$server_dir" ;;
            "1.20.1") bash "$create_scripts_dir/msc_forge_1.20.1.sh" "$server_dir" ;;
        esac
        ;;
    "folia")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_folia_1.21.4.sh" "$server_dir" ;;
        esac
        ;;
esac

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute the script for $server_type $server_version."
    exit 1
fi

clear
echo "Server created successfully!"

