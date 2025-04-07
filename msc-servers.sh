#!/bin/bash

# Ensure dependencies are installed
if ! command -v dialog &> /dev/null; then
    echo "Dialog is not installed. Installing it now..."
    sudo apt update
    sudo apt install -y dialog
fi

if ! command -v screen &> /dev/null; then
    echo "Screen is not installed. Installing it now..."
    sudo apt update
    sudo apt install -y screen
fi

# Function to check if any server is running (regardless of the type/version)
any_server_running() {
    if sudo screen -list | grep -qE '1 Socket in'; then
        return 0  # A server is running
    else
        return 1  # No servers are running
    fi
}

# Function to check if a server is running
is_server_running() {
    local server_name="$1"
    if screen -list | grep -q "$server_name"; then
        echo "Running"
    else
        echo "Not Running"
    fi
}

# Function to automatically switch Java version to Java 17
switch_to_java17() {
    echo "Switching to Java 17..."
    sudo update-alternatives --config java <<EOF
0
EOF
}

# Function to automatically switch Java version to Java 21
switch_to_java21() {
    echo "Switching to Java 21..."
    sudo update-alternatives --config java <<EOF
1
EOF
}

# Function to start a server
start_server() {
    local full_server_name="$1"  # Full server name in format [name]_[client]_[version]

    # Prevent starting a server if any server is already running
    if any_server_running; then
        dialog --msgbox "Another server is already running. Please stop it before starting a new one." 10 50
        return
    fi

    # Extract the version number from the server name (assuming the version is always the last part, after the last '_')
    local version=$(echo "$full_server_name" | awk -F'_' '{print $NF}')

    # Switch Java version based on server version
    case "$version" in
        "1.21.1")
            switch_to_java21
            ;;
        "1.20.4"|"1.20.1")
            switch_to_java17
            ;;
        *)
            echo "No specific Java version switch required for $full_server_name"
            ;;
    esac

    # Check if start.sh exists in the full server directory
    if [ -f "$full_server_name/start.sh" ]; then
        # Start the server in a detached screen and keep the screen open after crash
        screen -dmS "$full_server_name" bash -c "cd $full_server_name && bash start.sh; echo 'Server crashed. Press Enter to close.'; read"

        # Check if the screen session was created
        if screen -list | grep -q "$full_server_name"; then
            dialog --msgbox "Server $full_server_name started successfully." 10 50
        else
            dialog --msgbox "Failed to start server $full_server_name. Please check start.sh." 10 50
        fi
    else
        dialog --msgbox "start.sh not found in $full_server_name. Cannot start server." 10 50
    fi
}
echo "Full server name: $full_server_name"

# Function to edit server.properties
edit_properties() {
    if [ -f "$selected_server/server.properties" ]; then
        nano "$selected_server/server.properties"
    else
        dialog --msgbox "server.properties not found in $selected_server. Run the server once to generate it." 10 50
    fi
}

# Function to delete a server
delete_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to delete the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        rm -rf "./$server_name"
        dialog --msgbox "Server $server_name deleted." 10 50
        clear
    fi
}

# Function to attach to a running server's screen
view_console() {
    local server_name="$1"
    clear
    echo "Attaching to screen session for $server_name. Use Ctrl+A, then D to detach."
    sleep 7
    screen -r "$server_name"
}

# Function to stop a running server
stop_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to stop the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        screen -S "$server_name" -X quit
        dialog --msgbox "Server $server_name stopped." 10 50
    fi
}

# Main menu loop
while true; do
    # Fetch all server directories that contain a start.sh file
    server_dirs=()
    for dir in */; do
        if [ -f "$dir/start.sh" ]; then
            server_dirs+=("${dir%/}") # Remove trailing slash
        fi
    done

    # If no servers are found, display a message and exit
    if [ ${#server_dirs[@]} -eq 0 ]; then
        dialog --title "No Servers Found" --msgbox "No Minecraft servers with a start.sh file found in the current directory." 10 50
        clear
        exit 0
    fi

    # Build the menu
    menu_items=()
    for server in "${server_dirs[@]}"; do
        status=$(is_server_running "$server")
        menu_items+=("$server" "$status")
    done

    # Display the menu
    selected_server=$(dialog --menu "Select a server:" 15 50 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    # Handle cancellation
    if [ -z "$selected_server" ]; then
        clear
        exit 0
    fi

    # Full server name: include the client and version
    full_server_name="$selected_server"

    # Check the server's status
    status=$(is_server_running "$full_server_name")

    # Build actions based on status
    if [ "$status" == "Running" ]; then
        action=$(dialog --menu "Manage $full_server_name (Running):" 15 50 10 \
            "1" "View Console" \
            "2" "Stop Server" \
            "3" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) view_console "$full_server_name" ;;
            2) stop_server "$full_server_name" ;;
            3) ;;
        esac
    else
        action=$(dialog --menu "Manage $full_server_name (Not Running):" 15 50 10 \
            "1" "Start Server" \
            "2" "Edit server.properties" \
            "3" "Delete Server" \
            "4" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) start_server "$full_server_name" ;;  # Use full server name
            2) edit_properties "$full_server_name" ;;
            3) delete_server "$full_server_name" ;;
            4) ;;
        esac
    fi
done
