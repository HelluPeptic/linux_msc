#!/bin/bash

# Ensure dependencies are installed
for pkg in dialog screen; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "$pkg is not installed. Installing it now..."
        sudo apt update
        sudo apt install -y "$pkg"
    fi
done

# Function to check if any server is running
any_server_running() {
    sudo screen -list | grep -qE '1 Socket in'
}

# Function to check server status
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

# Start server
start_server() {
    local full_server_name="$1"

    if [ -f "$full_server_name/start.sh" ]; then
        dialog --infobox "Starting server $full_server_name..." 10 50
        screen -dmS "$full_server_name" bash -c "
            cd $full_server_name && bash start.sh;
            echo 'Server closed.'
        "
        sleep 2
        dialog --msgbox "🟢 Server $full_server_name started successfully." 10 50
    else
        dialog --msgbox "start.sh not found in $full_server_name. Cannot start server." 10 50
    fi
}

# Edit properties
edit_properties() {
    if [ -f "$selected_server/server.properties" ]; then
        nano "$selected_server/server.properties"
    else
        dialog --msgbox "server.properties not found in $selected_server." 10 50
    fi
}

# Delete server
delete_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to delete the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        rm -rf "./$server_name"
        dialog --msgbox "Server $server_name deleted." 10 50
        clear
    fi
}

# View console
view_console() {
    local server_name="$1"
    clear
    echo "Attaching to screen for $server_name. Use Ctrl+A then D to detach."
    sleep 4
    screen -r "$server_name"
}

# Stop server
stop_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to stop $server_name?" 10 50
    if [ $? -eq 0 ]; then
        echo "Shutting Down" > "/tmp/${server_name}_status"
        screen -S "$server_name" -X stuff "stop$(printf \\r)"

        (
            while screen -list | grep -q "$server_name"; do sleep 1; done
            echo "Not Running" > "/tmp/${server_name}_status"
        ) &
    fi
}

# Restart server
restart_server() {
    local server_name="$1"
    dialog --yesno "Restart $server_name?" 10 50
    if [ $? -eq 0 ]; then
        dialog --infobox "Stopping $server_name..." 10 50
        screen -S "$server_name" -X stuff "stop$(printf \\r)"
        while screen -list | grep -q "$server_name"; do sleep 1; done

        dialog --infobox "Starting $server_name..." 10 50
        screen -dmS "$server_name" bash -c "
            cd $server_name && bash start.sh;
            echo 'Server closed.'
        "
        sleep 2
        dialog --msgbox "Server $server_name restarted." 10 50
    fi
}

# Kill server
kill_server() {
    local server_name="$1"
    dialog --yesno "Force kill $server_name?" 10 50
    if [ $? -eq 0 ]; then
        screen -S "$server_name" -X quit
        dialog --msgbox "Server $server_name forcefully killed." 10 50
    fi
}

# View latest log
view_latest_log() {
    local server_name="$1"
    local log_file="$server_name/logs/latest.log"

    if [ -f "$log_file" ]; then
        nano "$log_file"
    else
        dialog --msgbox "latest.log not found. Run the server once." 10 50
    fi
}

# Function to manage remote access
manage_remote_access() {
    local server_name="$1"
    local ssh_keys_file="./.ssh_keys/$server_name.keys"
    mkdir -p "./.ssh_keys"  # Ensure the directory exists

    local action=$(dialog --menu "Remote Access for $server_name:" 15 50 10 \
        "1" "Add new user" \
        "2" "Open port" \
        "3" "View connection info" 3>&1 1>&2 2>&3)

    case $action in
        1)  # Add new user
            local ssh_key=$(dialog --inputbox "Paste the SSH key to add:" 10 50 3>&1 1>&2 2>&3)
            if [ -n "$ssh_key" ]; then
                echo "$ssh_key" >> "$ssh_keys_file"
                dialog --msgbox "SSH key added successfully." 10 50
            else
                dialog --msgbox "No SSH key provided. Operation canceled." 10 50
            fi
            ;;
        2)  # Open port
            if ! command -v ngrok &> /dev/null; then
                dialog --msgbox "ngrok is not installed. Installing now..." 10 50
                sudo apt update && sudo apt install -y ngrok
                local auth_token=$(dialog --inputbox "Enter your ngrok auth token:" 10 50 3>&1 1>&2 2>&3)
                if [ -n "$auth_token" ]; then
                    ngrok config add-authtoken "$auth_token"
                else
                    dialog --msgbox "No auth token provided. Operation canceled." 10 50
                    return
                fi
            fi

            dialog --msgbox "Opening ngrok port..." 10 50
            screen -dmS ngrok ngrok tcp 22
            dialog --msgbox "ngrok is now running in a screen session named 'ngrok'." 10 50
            ;;
        3)  # View connection info
            local ngrok_info=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'tcp://[^"]+')
            if [ -n "$ngrok_info" ]; then
                local ssh_command="ssh mc@${ngrok_info#tcp://}"
                dialog --msgbox "Use the following command to connect to the server:\n$ssh_command" 10 50
            else
                dialog --msgbox "No active ngrok session found. Please open a port first." 10 50
            fi
            ;;
    esac
}

# Main menu loop
while true; do
    server_dirs=()
    for dir in */; do
        if [ -f "$dir/start.sh" ]; then
            server_dirs+=("${dir%/}")
        fi
    done

    if [ ${#server_dirs[@]} -eq 0 ]; then
        dialog --title "No Servers Found" --msgbox "No Minecraft servers with a start.sh file found." 10 50
        clear
        exit 0
    fi

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

    menu_items=()
    for server in "${sorted_server_dirs[@]}"; do
        status=$(is_server_running "$server")
        emoji="🔴"
        [ "$status" == "Running" ] && emoji="🟢"
        menu_items+=("$server" "$emoji $status")
    done

    selected_server=$(dialog --menu "Select a server to manage:" 15 50 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_server" ] || [ "$selected_server" == "EXIT" ]; then
        clear
        exit 0
    fi

    full_server_name="$selected_server"
    status=$(is_server_running "$full_server_name")

    if [ "$status" == "Running" ]; then
        action=$(dialog --menu "Manage $full_server_name (🟢 Running):" 15 50 10 \
            "1" "View Console" \
            "2" "Restart Server" \
            "3" "Kill Server" \
            "4" "Remote Access" \
            "5" "Exit Menu" 3>&1 1>&2 2>&3)
        case $action in
            1) view_console "$full_server_name" ;;
            2) restart_server "$full_server_name" ;;
            3) kill_server "$full_server_name" ;;
            4) manage_remote_access "$full_server_name" ;;
        esac
    elif [ "$status" == "Shutting Down" ]; then
        dialog --msgbox "Server $full_server_name is shutting down. Please wait." 10 50
    else
        action=$(dialog --menu "Manage $full_server_name (🔴 Stopped):" 15 50 10 \
            "1" "Start Server" \
            "2" "Edit server.properties" \
            "3" "View latest.log" \
            "4" "Delete Server" \
            "5" "Remote Access" \
            "6" "Exit Menu" 3>&1 1>&2 2>&3)
        case $action in
            1) start_server "$full_server_name" ;;
            2) edit_properties "$full_server_name" ;;
            3) view_latest_log "$full_server_name" ;;
            4) delete_server "$full_server_name" ;;
            5) manage_remote_access "$full_server_name" ;;
        esac
    fi
done
