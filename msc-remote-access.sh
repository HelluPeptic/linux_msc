#!/bin/bash

# Function to manage remote access
manage_remote_access() {
    local ssh_keys_file="./.ssh_keys/global.keys"
    mkdir -p "./.ssh_keys"  # Ensure the directory exists

    # Check if ngrok is already running
    local ngrok_pid=$(pgrep -f "ngrok tcp 22")
    local ngrok_running=false
    if [ -n "$ngrok_pid" ]; then
        ngrok_running=true
    fi

    local action
    if [ "$ngrok_running" = true ]; then
        action=$(dialog --menu "Global Remote Access:" 15 50 10 \
            "1" "Add new user" \
            "2" "Close port" \
            "3" "View connection info" 3>&1 1>&2 2>&3)
    else
        action=$(dialog --menu "Global Remote Access:" 15 50 10 \
            "1" "Add new user" \
            "2" "Open port" \
            "3" "View connection info" 3>&1 1>&2 2>&3)
    fi

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
        2)  # Open or close port
            if [ "$ngrok_running" = true ]; then
                screen -S ngrok -X quit  # Shut down the screen session running ngrok
                dialog --msgbox "ngrok port closed successfully." 10 50
                bash msc  # Return to the main menu
            else
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

                screen -dmS ngrok ngrok tcp 22
                dialog --msgbox "ngrok is now running in a screen session named 'ngrok'." 10 50
                bash msc  # Return to the main menu
            fi
            ;;
        3)  # View connection info
            if [ "$ngrok_running" = true ]; then
                local ngrok_info=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -oE 'tcp://[^:]+:[0-9]+')
                if [ -n "$ngrok_info" ]; then
                    local host=$(echo "$ngrok_info" | cut -d':' -f2 | tr -d '/')
                    local port=$(echo "$ngrok_info" | cut -d':' -f3)
                    local username=$(whoami)  # Dynamically fetch the username
                    local ssh_command="ssh $username@$host -p $port"
                    dialog --msgbox "Use the following command to connect to the server:\n$ssh_command" 10 50
                else
                    dialog --msgbox "Unable to retrieve connection info. Please try again." 10 50
                fi
            else
                dialog --msgbox "No active ngrok session found. Please open a port first." 10 50
            fi
            ;;
    esac
}

# Main execution
manage_remote_access