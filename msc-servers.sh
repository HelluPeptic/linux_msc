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

# Function to check if a server is running and return its status
is_server_running() {
    local server_name="$1"
    if screen -list | grep -q "$server_name"; then
        echo "Running"
    elif [ -f "/tmp/${server_name}_status" ]; then
        cat "/tmp/${server_name}_status"
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

    # Check if start.sh exists in the full server directory
    if [ -f "$full_server_name/start.sh" ]; then
        # Start the server in a detached screen
        screen -dmS "$full_server_name" bash -c "
            cd $full_server_name && bash start.sh;
            echo 'Server closed.';
        "

        # Notify the user that the server has started
        dialog --msgbox "Server $full_server_name started successfully." 10 50
    else
        dialog --msgbox "start.sh not found in $full_server_name. Cannot start server." 10 50
    fi
}

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
        # Update the status to "Shutting Down" immediately
        echo "Shutting Down" > "/tmp/${server_name}_status"

        # Send the "stop" command to the server
        screen -S "$server_name" -X stuff "stop$(printf \\r)"

        # Start a background process to monitor the shutdown
        (
            while screen -list | grep -q "$server_name"; do
                sleep 1
            done
            # Update the status to "Not Running" once the server is fully stopped
            echo "Not Running" > "/tmp/${server_name}_status"
        ) &
    fi
}

# Function to restart a running server
restart_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to restart the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        # Stop the server
        echo "Stopping server $server_name..."
        screen -S "$server_name" -X stuff "stop$(printf \r)"

        # Wait for the server to stop completely
        echo "Waiting for the server to stop..."
        while screen -list | grep -q "$server_name"; do
            sleep 1
        done

        echo "Server $server_name stopped. Starting it again..."

        # Start the server again
        screen -dmS "$server_name" bash -c "
            cd $server_name && bash start.sh;
            echo 'Server closed.';
        "

        dialog --msgbox "Server $server_name restarted successfully." 10 50
    fi
}

# Function to kill a running server
kill_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to forcefully kill the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        screen -S "$server_name" -X quit  # Forcefully terminate the screen session
        dialog --msgbox "Server $server_name has been forcefully killed." 10 50
    fi
}

# Function to view the latest log of a server
view_latest_log() {
    local server_name="$1"
    local log_file="$server_name/logs/latest.log"

    if [ -f "$log_file" ]; then
        nano "$log_file"
    else
        dialog --msgbox "latest.log not found in $server_name/logs. Please ensure the server has been started at least once." 10 50
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

    # Sort servers so that running servers appear at the top
    sorted_server_dirs=()
    running_servers=()
    not_running_servers=()

    for server in "${server_dirs[@]}"; do
        status=$(is_server_running "$server")
        if [ "$status" == "Running" ]; then
            running_servers+=("$server")
        else
            not_running_servers+=("$server")
        fi

    done

    sorted_server_dirs=("${running_servers[@]}" "${not_running_servers[@]}")

    # Build the menu
    menu_items=()
    for server in "${sorted_server_dirs[@]}"; do
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
            "2" "Restart Server" \
            "3" "Kill Server" \
            "4" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) view_console "$full_server_name" ;;
            2) restart_server "$full_server_name" ;;  # Update status dynamically
            3) kill_server "$full_server_name" ;;
            4) ;;
        esac
    elif [ "$status" == "Shutting Down" ]; then
        # Refresh the menu while the server is shutting down
        dialog --msgbox "The server $full_server_name is currently shutting down. Please wait." 10 50
    else
        action=$(dialog --menu "Manage $full_server_name (Not Running):" 15 50 10 \
            "1" "Start Server" \
            "2" "Edit server.properties" \
            "3" "View latest.log" \
            "5" "Delete Server" \
            "4" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) start_server "$full_server_name" ;;  # Use full server name
            2) edit_properties "$full_server_name" ;;
            3) view_latest_log "$full_server_name" ;;
            5) delete_server "$full_server_name" ;;
            4) ;;
        esac
    fi
done
