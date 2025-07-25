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

# Main Menu
options=(
    1 "Vanilla"
    2 "Paper"
    3 "Fabric"
    4 "Forge"
    5 "Folia"
)

choice=$(dialog --clear \
                --title "Choose a Minecraft Client" \
                --menu "Select an option using the arrow keys, or press Enter:" 15 40 6 \
                "${options[@]}" \
                2>&1 >/dev/tty)

clear

# Handle the case where the user presses 'Cancel' in the client selection dialog
if [ -z "$choice" ]; then
    echo "Exiting..."
    exit 0
fi

# Update the version selection menu to show only supported versions for each server type
case $choice in
    1) 
        server_type="vanilla"
        versions=(
            1 "1.21.4"
            2 "1.21.1"
            3 "1.20.4"
            4 "1.20.1"
        )
        ;;
    2) 
        server_type="paper"
        versions=(
            1 "1.21.4"
            2 "1.21.1"
            3 "1.20.4"
            4 "1.20.1"
        )
        ;;
    3) 
        server_type="fabric"
        versions=(
            1 "1.21.5"
            2 "1.21.4"
            3 "1.21.1"
            4 "1.20.4"
            5 "1.20.1"
        )
        ;;
    4) 
        server_type="forge"
        versions=(
            1 "1.21.4"
            2 "1.21.1"
            3 "1.20.4"
            4 "1.20.1"
        )
        ;;
    5) 
        server_type="folia"
        versions=(
            1 "1.21.4"
        )
        ;;
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

# Prompt for Minecraft version
version_choice=$(dialog --clear \
                        --title "Choose a Minecraft Version" \
                        --menu "Select an option using the arrow keys, or press Enter:" 15 40 ${#versions[@]} \
                        "${versions[@]}" \
                        2>&1 >/dev/tty)

clear

# Handle the case where the user presses 'Cancel' in the version selection dialog
if [ -z "$version_choice" ]; then
    echo "Exiting..."
    exit 0
fi

case $version_choice in
    1) server_version="1.21.5" ;;
    2) server_version="1.21.4" ;;
    3) server_version="1.21.1" ;;
    4) server_version="1.20.4" ;;
    5) server_version="1.20.1" ;;
esac

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

# Execute the specific creation script based on server type and version
case $server_type in
    "vanilla")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_vanilla_1.21.4.sh" "$server_dir" "$server_ram" ;;
            "1.21.1") bash "$create_scripts_dir/msc_vanilla_1.21.1.sh" "$server_dir" "$server_ram" ;;
            "1.20.4") bash "$create_scripts_dir/msc_vanilla_1.20.4.sh" "$server_dir" "$server_ram" ;;
            "1.20.1") bash "$create_scripts_dir/msc_vanilla_1.20.1.sh" "$server_dir" "$server_ram" ;;
        esac
        ;;
    "paper")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_paper_1.21.4.sh" "$server_dir" "$server_ram" ;;
            "1.21.1") bash "$create_scripts_dir/msc_paper_1.21.1.sh" "$server_dir" "$server_ram" ;;
            "1.20.4") bash "$create_scripts_dir/msc_paper_1.20.4.sh" "$server_dir" "$server_ram" ;;
            "1.20.1") bash "$create_scripts_dir/msc_paper_1.20.1.sh" "$server_dir" "$server_ram" ;;
        esac
        ;;
    "fabric")
        case $server_version in
            "1.21.5") bash "$create_scripts_dir/msc_fabric_1.21.5.sh" "$server_dir" "$server_ram" ;;
            "1.21.4") bash "$create_scripts_dir/msc_fabric_1.21.4.sh" "$server_dir" "$server_ram" ;;
            "1.21.1") bash "$create_scripts_dir/msc_fabric_1.21.1.sh" "$server_dir" "$server_ram" ;;
            "1.20.4") bash "$create_scripts_dir/msc_fabric_1.20.4.sh" "$server_dir" "$server_ram" ;;
            "1.20.1") bash "$create_scripts_dir/msc_fabric_1.20.1.sh" "$server_dir" "$server_ram" ;;
        esac
        ;;
    "forge")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_forge_1.21.4.sh" "$server_dir" "$server_ram" ;;
            "1.21.1") bash "$create_scripts_dir/msc_forge_1.21.1.sh" "$server_dir" "$server_ram" ;;
            "1.20.4") bash "$create_scripts_dir/msc_forge_1.20.4.sh" "$server_dir" "$server_ram" ;;
            "1.20.1") bash "$create_scripts_dir/msc_forge_1.20.1.sh" "$server_dir" "$server_ram" ;;
        esac
        ;;
    "folia")
        case $server_version in
            "1.21.4") bash "$create_scripts_dir/msc_folia_1.21.4.sh" "$server_dir" ;;
        esac
esac

if [[ $? -ne 0 ]]; then
    echo "Error: Failed to execute the script for $server_type $server_version."
    exit 1
fi

clear
echo "Server created successfully!"
