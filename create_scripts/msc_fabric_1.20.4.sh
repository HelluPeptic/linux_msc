#!/bin/bash

MINECRAFT_VERSION="1.20.4"
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/0.11.2/fabric-installer-0.11.2.jar"
FABRIC_INSTALLER_JAR="fabric-installer.jar"
MINECRAFT_SERVER_JAR="fabric-server-launch.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Check if the directory name was provided
if [[ -z "$server_dir" ]]; then
    echo "Error: No server directory specified. Usage: $0 <server_directory>"
    exit 1
fi

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

# Function to download and set up the Fabric server
download_fabric_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading Fabric installer..."
    curl -o "$FABRIC_INSTALLER_JAR" "$FABRIC_INSTALLER_URL"

    # Check if download was successful
    if [ ! -f "$FABRIC_INSTALLER_JAR" ]; then
        echo "Download failed. Please check the Fabric installer URL."
        exit 1
    fi

    echo "Running Fabric installer for Minecraft version $MINECRAFT_VERSION..."
    java -jar "$FABRIC_INSTALLER_JAR" server -mcversion $MINECRAFT_VERSION -downloadMinecraft

    # Check if Fabric server was successfully created
    if [ ! -f "$MINECRAFT_SERVER_JAR" ]; then
        echo "Fabric installation failed. Please check the installer output."
        exit 1
    fi

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Create a start script
    echo "#!/bin/bash
java -Xms1024M -Xmx$ram_allocation -jar $MINECRAFT_SERVER_JAR nogui" > start.sh

    chmod +x start.sh
    echo "Fabric server for Minecraft $MINECRAFT_VERSION is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_fabric_server
else
    echo "Java 17 is not installed. Installing Java 17..."
    install_java_17
    if check_java_version; then
        echo "Java 17 installed successfully."
        download_fabric_server
    else
        echo "There was an issue installing Java 17. Attempting to switch to Java 17..."
        switch_to_java17
        download_fabric_server
    fi
fi
