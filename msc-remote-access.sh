#!/bin/bash

# Update password and SSH key prompts to handle cancel button
setup_password() {
    local password_file="./.ssh_keys/access_password.txt"

    if [ ! -f "$password_file" ]; then
        local password=$(dialog --insecure --passwordbox "Set a password for Remote Access:" 10 50 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            bash msc  # Return to the main menu if canceled
            exit 0
        fi
        if [ -z "$password" ]; then
            dialog --msgbox "Password setup canceled. Returning to the main menu." 10 50
            bash msc
            exit 0
        fi
        echo "$password" > "$password_file"
        dialog --msgbox "Password set successfully." 10 50
    fi

    local entered_password=$(dialog --insecure --passwordbox "Enter the Remote Access password:" 10 50 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        bash msc  # Return to the main menu if canceled
        exit 0
    fi
    if [ "$entered_password" != "$(cat $password_file)" ]; then
        dialog --msgbox "Incorrect password. Returning to the main menu." 10 50
        bash msc
        exit 0
    fi
}

# Function to manage remote access
manage_remote_access() {
    setup_password  # Ensure password is set and verified

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
            "3" "View connection info" \
            "4" "Back to Main Menu" 3>&1 1>&2 2>&3)
    else
        action=$(dialog --menu "Global Remote Access:" 15 50 10 \
            "1" "Add new user" \
            "2" "Open port" \
            "3" "View connection info" \
            "4" "Back to Main Menu" 3>&1 1>&2 2>&3)
    fi

    case $action in
        1)  # Add new user
            echo "Paste the SSH key below and press Enter when done (Ctrl+D to finish):"
            local ssh_key
            ssh_key=$(cat)  # Allow multi-line input for SSH key
            if [ $? -ne 0 ]; then
                manage_remote_access  # Return to the remote access menu if canceled
                return
            fi
            if [ -n "$ssh_key" ]; then
                echo "$ssh_key" >> "$ssh_keys_file"
                dialog --msgbox "SSH key added successfully." 10 50
            else
                dialog --msgbox "No SSH key provided. Operation canceled." 10 50
            fi
            manage_remote_access  # Return to the remote access menu
            ;;
        2)  # Open or close port
            if [ "$ngrok_running" = true ]; then
                screen -S ngrok -X quit  # Shut down the screen session running ngrok
                dialog --msgbox "ngrok port closed successfully." 10 50
            else
                if ! command -v ngrok &> /dev/null; then
                    dialog --msgbox "ngrok is not installed. Installing now..." 10 50
                    sudo apt update && sudo apt install -y ngrok
                    local auth_token=$(dialog --inputbox "Enter your ngrok auth token:" 10 50 3>&1 1>&2 2>&3)
                    if [ $? -ne 0 ]; then
                        manage_remote_access  # Return to the remote access menu if canceled
                        return
                    fi
                    if [ -n "$auth_token" ]; then
                        ngrok config add-authtoken "$auth_token"
                    else
                        dialog --msgbox "No auth token provided. Operation canceled." 10 50
                        manage_remote_access  # Return to the remote access menu
                        return
                    fi
                fi

                screen -dmS ngrok ngrok tcp 22
                dialog --msgbox "ngrok is now running in a screen session named 'ngrok'." 10 50
            fi
            manage_remote_access  # Return to the remote access menu
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
            manage_remote_access  # Return to the remote access menu
            ;;
        4)  # Back to Main Menu
            bash msc
            ;;
    esac
}

# Main execution
manage_remote_access