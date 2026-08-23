#!/bin/bash

MINECRAFT_VERSION="26.2"
NEOFORGE_VERSION="26.2.0.66"
NEOFORGE_INSTALLER_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/26.2.0.66/neoforge-26.2.0.66-installer.jar"
NEOFORGE_INSTALLER_JAR="neoforge-26.2.0.66-installer.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Check if the directory name was provided
if [[ -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Error: Missing parameters."
    echo "Usage: $0 <server_directory> <ram_allocation>"
    exit 1
fi

# Function to install Java 25 manually from Adoptium
install_java_25() {
    echo "Installing Java 25 manually..."

    # Step 1: Download OpenJDK 25 (aarch64 build) from Adoptium
    cd ~
    wget https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz

    # Step 2: Extract and move it to /opt
    tar -xvf OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz
    sudo mv jdk-25.0.3+9 /opt/jdk-25

    # Step 3: Create a system-wide environment setup
    echo "export JAVA_HOME=/opt/jdk-25" | sudo tee /etc/profile.d/jdk25.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/jdk25.sh

    # Step 4: Apply the environment variables
    source /etc/profile.d/jdk25.sh

    # Step 5: Enable java 25 to appear in the alternatives system
    sudo update-alternatives --install /usr/bin/java java /opt/jdk-25/bin/java 3
    sudo update-alternatives --install /usr/bin/javac javac /opt/jdk-25/bin/javac 3

    # Step 6: Clean up the downloaded archive
    rm -f ~/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz

    echo "Java 25 installation completed and environment variables set."
}

switch_to_java25() {
    echo "Switching to Java 25..."
    if [ -f /opt/jdk-25/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-25/bin/java 2>/dev/null || true
    fi
    export JAVA_HOME=/opt/jdk-25
    export PATH=$JAVA_HOME/bin:$PATH
}

check_java_version() {
    if [ -f /opt/jdk-25/bin/java ]; then
        return 0
    fi
    return 1
}

# Function to download and set up the NeoForge server
download_neoforge_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading NeoForge installer..."
    curl -o "$NEOFORGE_INSTALLER_JAR" "$NEOFORGE_INSTALLER_URL"

    # Check if download was successful
    if [ ! -f "$NEOFORGE_INSTALLER_JAR" ]; then
        echo "Download failed. Please check the NeoForge installer URL."
        exit 1
    fi

    echo "Running NeoForge installer for Minecraft version $MINECRAFT_VERSION..."
    /opt/jdk-25/bin/java -jar "$NEOFORGE_INSTALLER_JAR" --installServer

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Configure JVM arguments with specified RAM allocation
    echo "-Xms1024M" > user_jvm_args.txt
    echo "-Xmx$ram_allocation" >> user_jvm_args.txt

    # Create the start script
    printf '#!/usr/bin/env sh\n# Add custom program arguments (such as nogui) to the next line before the "$@" or pass them to this script directly\n/opt/jdk-25/bin/java @user_jvm_args.txt @libraries/net/neoforged/neoforge/%s/unix_args.txt "$@"\n' "$NEOFORGE_VERSION" > start.sh

    chmod +x start.sh
    echo "NeoForge server for Minecraft $MINECRAFT_VERSION is ready! To start the server, navigate to '$server_dir' and run: './start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Java 25 is already installed."
    download_neoforge_server
else
    echo "Java 25 is not installed. Installing Java 25..."
    install_java_25
    if check_java_version; then
        echo "Java 25 installed successfully."
        download_neoforge_server
    else
        echo "There was an issue installing Java 25. Attempting to switch to Java 25..."
        switch_to_java25
        download_neoforge_server
    fi
fi
