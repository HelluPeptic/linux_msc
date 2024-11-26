#!/bin/bash

MINECRAFT_VERSION="1.20.1"
MINECRAFT_SERVER_JAR="server.jar"
MINECRAFT_DOWNLOAD_URL="https://piston-data.mojang.com/v1/objects/84194a2f286ef7c14ed7ce0090dba59902951553/server.jar"
RAM_ALLOCATION="6G"

# Accept the custom server directory name as a parameter
server_dir="$1"

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
java -Xmx$RAM_ALLOCATION -Xms1024M -jar vanilla_$MINECRAFT_VERSION.jar nogui
EOF
chmod +x "$server_dir/start.sh"

# Placeholder for the server JAR file
touch "$server_dir/vanilla_$MINECRAFT_VERSION.jar"

# Confirmation message
echo "Vanilla server $MINECRAFT_VERSION created successfully in $server_dir."

# Function to install Java 17 if needed
install_java_17() {
    echo "Installing Java 17..."
    sudo apt update
    sudo apt install -y openjdk-17-jdk openjdk-17-jre
}

# Function to automatically switch Java version to Java 17
switch_to_java17() {
    echo "Switching to Java 17..."
    sudo update-alternatives --config java <<EOF
0
EOF
}

# Function to check if Java 17 is installed
check_java_version() {
    switch_to_java17
    java_version=$(java -version 2>&1 | grep -oP 'version "\K[^"]*')

    if [[ $java_version == 17* ]]; then
        return 0  # Java 17 is installed
    else
        return 1  # Java 17 is not installed
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

    # Accept the EULA (create eula.txt with eula=true)
    echo "eula=true" > eula.txt

    # Create a start script
    echo "#!/bin/bash
java -Xms1G -Xmx$RAM_ALLOCATION -jar $MINECRAFT_SERVER_JAR nogui" > start.sh

    chmod +x start.sh
    echo "Server is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_server
else
    echo "Java 17 is not installed. Installing Java 17..."
    install_java_17
    if check_java_version; then
        echo "Java 17 installed successfully."
        download_server
    else
        echo "There was an issue installing Java 17. Attempting to switch to Java 17..."
        switch_to_java17
        download_server
    fi
fi
