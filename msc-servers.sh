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

create_backup() {
    local server_name="$1"
    local backup_dir="$server_name/backups"
    mkdir -p "$backup_dir"

    local backup_name=$(dialog --inputbox "Choose a name for the backup:" 10 50 3>&1 1>&2 2>&3)
    if [ -z "$backup_name" ]; then
        dialog --msgbox "Backup creation canceled." 10 50
        return
    fi

    # Replace spaces in the backup name with underscores to ensure compatibility
    local sanitized_backup_name=$(echo "$backup_name" | sed 's/ /_/g')
    local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
    local backup_path="$backup_dir/${sanitized_backup_name}_$timestamp.tar.gz"

    {
        echo -e "5"
        sleep 0.2
        echo -e "10"
        sleep 0.2
        echo -e "15"
        sleep 0.2
        echo -e "20"
        sleep 0.2
        echo -e "25"
        sleep 0.2
        echo -e "30"
        sleep 0.2
        echo -e "35"
        sleep 0.2

        # Simulate progress during compression
        for i in {36..85}; do
            echo -e "$i\nCompressing... ($((i - 35))%)"
            sleep 0.05
        done

        # Actual compression, excluding the backups folder
        tar --exclude="$server_name/backups" -czf "$backup_path" "$server_name" 2>/dev/null

        echo -e "90"
        sleep 0.2
        echo -e "95"
        sleep 0.2
        echo -e "100"
        sleep 0.2
    } | dialog --title "Creating Backup" --gauge "Please wait..." 10 60 0

    if [ -f "$backup_path" ]; then
        dialog --msgbox "Backup created successfully: $backup_path" 10 50
    else
        dialog --msgbox "Backup creation failed." 10 50
    fi
}



view_backups() {
    local server_name="$1"
    local backup_dir="$server_name/backups"

    if [ ! -d "$backup_dir" ]; then
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

    if [ -z "$backup_choice" ]; then
        return
    fi

    local selected_filename="${label_to_file[$backup_choice]}"
    local action=$(dialog --menu "Manage $backup_choice:" 15 50 10 \
        "1" "Restore to this backup" \
        "2" "Rename this backup" \
        "3" "Delete this backup" 3>&1 1>&2 2>&3)

    case $action in
        1)
            {
                echo -e "5"
                sleep 0.2
                echo -e "10"
                sleep 0.2
                echo -e "15"
                sleep 0.2
                echo -e "20"
                sleep 0.2
                echo -e "25"
                sleep 0.2
                echo -e "30"
                sleep 0.2
                echo -e "35"
                sleep 0.2

                # Simulate progress during restoration
                for i in {36..60}; do
                    echo -e "$i\nPreparing to restore... ($((i - 35))%)"
                    sleep 0.05
                done

                # Remove all files/folders except backups, suppress errors
                find "$server_name" -mindepth 1 -not -path "$backup_dir" -not -path "$backup_dir/*" -exec rm -rf {} + 2>/dev/null

                for i in {61..85}; do
                    echo -e "$i\nRestoring... ($((i - 35))%)"
                    sleep 0.05
                done

                # Actual restoration
                tar -xzf "$backup_dir/$selected_filename" -C .

                echo -e "90"
                sleep 0.2
                echo -e "95"
                sleep 0.2
                echo -e "100"
                sleep 0.2
            } | dialog --title "Restoring Backup" --gauge "Please wait..." 10 60 0

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
            server_dirs+=("${dir%/}")
        fi
    done

    if [ ${#server_dirs[@]} -eq 0 ]; then
        dialog --title "No Servers Found" --msgbox "No Minecraft servers with a start.sh file found." 10 50
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

    menu_items=()
    for server in "${sorted_server_dirs[@]}"; do
        status=$(is_server_running "$server")
        emoji="🔴"
        [ "$status" == "Running" ] && emoji="🟢"
        menu_items+=("$server" "$emoji $status")
    done

    # Display the menu
    selected_server=$(dialog --menu "Select a server:" 15 50 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)

    # Handle cancellation
    if [ -z "$selected_server" ]; then
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
            "4" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) view_console "$full_server_name" ;;
            2) stop_server "$full_server_name" ;;  # Update status dynamically
            3) kill_server "$full_server_name" ;;
        esac
    elif [ "$status" == "Shutting Down" ]; then
        # Refresh the menu while the server is shutting down
        dialog --msgbox "The server $full_server_name is currently shutting down. Please wait." 10 50
    else
        action=$(dialog --menu "Manage $full_server_name (🔴 Stopped):" 15 50 10 \
            "1" "Start Server" \
            "2" "Edit server.properties" \
            "3" "Delete Server" \
            "4" "Exit Menu" 3>&1 1>&2 2>&3)

        case $action in
            1) start_server "$full_server_name" ;;
            2) edit_properties "$full_server_name" ;;
            3) delete_server "$full_server_name" ;;
            4) ;;
        esac
    fi

done
