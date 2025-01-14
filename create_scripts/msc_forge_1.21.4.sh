#!/bin/bash

MINECRAFT_VERSION="1.21.4"
FORGE_INSTALLER_URL="https://maven.minecraftforge.net/net/minecraftforge/forge/1.21.4-54.0.17/forge-1.21.4-54.0.17-shim.jar"
FORGE_INSTALLER_JAR="forge-installer.jar"
FORGE_UNIVERSAL_JAR="forge-1.21.4-54.0.17-shim.jar"

# Accept the custom server directory name as a parameter
server_dir="$1"

# Check if the directory name was provided
if [[ -z "$server_dir" ]]; then
    echo "Error: No server directory specified. Usage: $0 <server_directory>"
    exit 1
fi

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

# Function to download and set up the Forge server
download_forge_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading Forge installer..."
    curl -o "$FORGE_INSTALLER_JAR" "$FORGE_INSTALLER_URL"

    # Check if download was successful
    if [ ! -f "$FORGE_INSTALLER_JAR" ]; then
        echo "Download failed. Please check the Forge installer URL."
        exit 1
    fi

    echo "Running Forge installer for Minecraft version $MINECRAFT_VERSION..."
    java -jar "$FORGE_INSTALLER_JAR" --installServer

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Create a start script
    echo "#!/bin/bash
java -Xms1G -Xmx2G -jar $FORGE_UNIVERSAL_JAR nogui" > start.sh

    chmod +x start.sh
    echo "Forge server for Minecraft $MINECRAFT_VERSION is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_forge_server
else
    echo "Java 21 is not installed. Installing Java 21..."
    install_java_21
    if check_java_version; then
        echo "Java 21 installed successfully."
        download_forge_server
    else
        echo "There was an issue installing Java 21. Attempting to switch to Java 21..."
        switch_to_java21
        download_forge_server
    fi
fi
