#!/bin/bash

SERVER_DIR="vanilla_1.21.4"
MINECRAFT_VERSION="1.21.4"
MINECRAFT_SERVER_JAR="server.jar"
MINECRAFT_DOWNLOAD_URL="https://piston-data.mojang.com/v1/objects/4707d00eb834b446575d89a61a11b5d548d8c001/server.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Check if the directory name was provided
if [[ -z "$server_dir" ]]; then
    echo "Error: No server directory specified. Usage: $0 <server_directory>"
    exit 1
fi

# Create the server directory
mkdir -p "$server_dir"

# Create the startup script in the server directory
cat <<EOF > "$server_dir/start.sh"
#!/bin/bash
java -Xmx$ram_allocation -Xms1024M -jar vanilla_$MINECRAFT_VERSION.jar nogui
EOF
chmod +x "$server_dir/start.sh"

# Placeholder for the server JAR file
touch "$server_dir/vanilla_$MINECRAFT_VERSION.jar"

# Confirmation message
echo "Vanilla server $MINECRAFT_VERSION created successfully in $server_dir."

# Function to install Java 21 if needed
install_java_21() {
    echo "Installing Java 21..."
    sudo apt update
    sudo apt install -y openjdk-21-jdk openjdk-21-jre
}

# Function to automatically switch Java version to Java 21
switch_to_java21() {
    echo "Switching to Java 21..."
    sudo update-alternatives --config java <<EOF
1
EOF
}

# Function to check if Java 21 is installed
check_java_version() {
    switch_to_java21
    java_version=$(java -version 2>&1 | grep -oP 'version "\K[^"]*')

    if [[ $java_version == 21* ]]; then
        return 0  # Java 21 is installed
    else
        return 1  # Java 21 is not installed
    fi
}

# Function to download and set up the Vanilla Minecraft server
download_server() {
    cd "$server_dir" || exit 1

    echo "Downloading Vanilla Minecraft server version $MINECRAFT_VERSION..."
    curl -o "$MINECRAFT_SERVER_JAR" "$MINECRAFT_DOWNLOAD_URL"

    # Check if download was successful
    if [ ! -f "$MINECRAFT_SERVER_JAR" ]; then
        echo "Download failed. Please check the Minecraft download URL."
        exit 1
    fi

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Create a start script
    echo "#!/bin/bash
java -Xms1G -Xmx$ram_allocation -jar $MINECRAFT_SERVER_JAR nogui" > start.sh

    chmod +x start.sh
    echo "Server is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_server
else
    echo "Java 21 is not installed. Installing Java 21..."
    install_java_21
    if check_java_version; then
        echo "Java 21 installed successfully."
        download_server
    else
        echo "There was an issue installing Java 21. Attempting to switch to Java 21..."
        switch_to_java21
        download_server
    fi
fi
