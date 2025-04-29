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

# Function to kill a running server
kill_server() {
    local server_name="$1"
    dialog --yesno "Are you sure you want to forcefully kill the server $server_name?" 10 50
    if [ $? -eq 0 ]; then
        screen -S "$server_name" -X quit  # Forcefully terminate the screen session
        dialog --msgbox "Server $server_name has been forcefully killed." 10 50
    fi
}

create_backup() {
    local server_name="$1"
    local backup_dir="$server_name/backups"
    echo "[DEBUG] Creating backup directory: $backup_dir" >&2
    mkdir -p "$backup_dir"

    local backup_name=$(dialog --inputbox "Choose a name for the backup:" 10 50 3>&1 1>&2 2>&3)
    echo "[DEBUG] User entered backup name: $backup_name" >&2
    if [ -z "$backup_name" ]; then
        dialog --msgbox "Backup creation canceled." 10 50
        return
    fi

    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_path="$backup_dir/${backup_name}_$timestamp.tar.gz"
    echo "[DEBUG] Backup path: $backup_path" >&2

    # Start the dialog progress bar in the background
    {
        echo "5"; echo "Initializing backup..."
        sleep 0.2
        echo "10"; echo "Preparing directories..."
        sleep 0.2
        echo "15"; echo "Scanning files..."
        sleep 0.2
        echo "20"; echo "Counting files..."
        sleep 0.2
        echo "25"; echo "Estimating size..."
        sleep 0.2
        echo "30"; echo "Creating archive structure..."
        sleep 0.2
        echo "35"; echo "Starting compression..."
        sleep 0.2

        # Simulate progress during compression
        for i in {36..85}; do
            percent=$((i))
            message="Compressing... ($((i - 35))%)"
            echo "$percent"; echo "$message"
            sleep 0.05
        done

        # Actual compression, excluding the backups folder
        tar --exclude="$server_name/backups" -czf "$backup_path" "$server_name" 2>/dev/null

        echo "90"; echo "Finalizing archive..."
        sleep 0.2
        echo "95"; echo "Cleaning up..."
        sleep 0.2
        echo "100"; echo "Backup complete."
        sleep 0.2
    } | dialog --title "Creating Backup" --gauge "Please wait..." 10 60 0

    if [ -f "$backup_path" ]; then
        echo "[DEBUG] Backup created successfully: $backup_path" >&2
        dialog --msgbox "Backup created successfully: $backup_path" 10 50
    else
        echo "[DEBUG] Backup creation failed." >&2
        dialog --msgbox "Backup creation failed." 10 50
    fi
}


view_backups() {
    local server_name="$1"
    local backup_dir="$server_name/backups"
    echo "[DEBUG] Viewing backups in directory: $backup_dir" >&2

    if [ ! -d "$backup_dir" ]; then
        echo "[DEBUG] Backup directory does not exist." >&2
        dialog --msgbox "No backups found for $server_name." 10 50
        return
    fi

    local menu_items=()
    declare -A label_to_file

    # Get files sorted by creation time (newest first)
    while IFS= read -r file; do
        local filename=$(basename "$file")
        local name_date=$(echo "$filename" | sed -E 's/(.*)_([0-9]{4}-[0-9]{2}-[0-9]{2})_([0-9]{2})-([0-9]{2})-([0-9]{2}).tar.gz/\1 | \2 \3:\4:\5/')
        menu_items+=("$name_date" "")
        label_to_file["$name_date"]="$filename"
    done < <(find "$backup_dir" -type f -name "*.tar.gz" -printf "%T@ %p\n" | sort -nr | awk '{print $2}')

    local backup_choice=$(dialog --menu "Select a backup:" 15 50 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    echo "[DEBUG] User selected backup: $backup_choice" >&2

    if [ -z "$backup_choice" ]; then
        return
    fi

    local selected_filename="${label_to_file[$backup_choice]}"
    local action=$(dialog --menu "Manage $backup_choice:" 15 50 10 \
        "1" "Restore to this backup" \
        "2" "Rename this backup" \
        "3" "Delete this backup" 3>&1 1>&2 2>&3)
    echo "[DEBUG] User selected action: $action" >&2

    case $action in
        1)
            tar -xzf "$backup_dir/$selected_filename" -C .
            dialog --msgbox "Backup restored successfully." 10 50
            ;;
        2)
            local new_name=$(dialog --inputbox "Enter a new name for the backup (date will be preserved):" 10 50 3>&1 1>&2 2>&3)
            if [ -n "$new_name" ]; then
                local timestamp=$(echo "$selected_filename" | sed -E 's/.*_([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}).tar.gz/\1/')
                local new_file="${new_name}_${timestamp}.tar.gz"
                mv "$backup_dir/$selected_filename" "$backup_dir/$new_file"
                dialog --msgbox "Backup renamed successfully to $new_file." 10 50
            fi
            ;;
        3)
            rm "$backup_dir/$selected_filename"
            dialog --msgbox "Backup deleted successfully." 10 50
            ;;
    esac
}


while true; do
    server_dirs=()
    for dir in */; do
        if [ -f "$dir/start.sh" ]; then
            server_dirs+=("${dir%/}") # Remove trailing slash
        fi
    done

    if [ ${#server_dirs[@]} -eq 0 ]; then
        dialog --title "No Servers Found" --msgbox "No Minecraft servers with a start.sh file found in the current directory." 10 50
        clear
        exit 0
    fi

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

    menu_items=()
    for server in "${sorted_server_dirs[@]}"; do
        status=$(is_server_running "$server")
        menu_items+=("$server" "$status")
    done

    selected_server=$(dialog --menu "Select a server:" 15 50 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_server" ]; then
        clear
        exit 0
    fi

    echo "[DEBUG] Selected server: $selected_server" >&2

    full_server_name="$selected_server"
    status=$(is_server_running "$full_server_name")

    if [ "$status" == "Running" ]; then
        action=$(dialog --menu "Manage $full_server_name (Running):" 15 50 10 \
            "1" "View Console" \
            "2" "Stop Server" \
            "3" "Kill Server" \
            "4" "Exit Menu" 3>&1 1>&2 2>&3)



        case $action in
            1) view_console "$full_server_name" ;;
            2) stop_server "$full_server_name" ;;
            3) kill_server "$full_server_name" ;;
            4) ;;
        esac
    elif [ "$status" == "Shutting Down" ]; then
        dialog --msgbox "The server $full_server_name is currently shutting down. Please wait." 10 50
    else
        action=$(dialog --menu "Manage $full_server_name (Not Running):" 15 50 10 \
            "1" "Start Server" \
            "2" "Edit server.properties" \
            "3" "Backups" \
            "4" "Delete Server" \
            "5" "Exit Menu" 3>&1 1>&2 2>&3)


        case $action in
            1) start_server "$full_server_name" ;;
            2) edit_properties "$full_server_name" ;;
            3)
                backup_action=$(dialog --menu "Backups for $full_server_name:" 15 50 10 \
                    "1" "Create a new backup" \
                    "2" "View backups" 3>&1 1>&2 2>&3)


                case $backup_action in
                    1) create_backup "$full_server_name" ;;
                    2) view_backups "$full_server_name" ;;
                esac
                ;;
            4) delete_server "$full_server_name" ;;
            5) ;;
        esac
    fi

done
