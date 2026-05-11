#!/bin/bash

MINECRAFT_VERSION="1.20.4"
NEOFORGE_VERSION="20.4.251"
NEOFORGE_INSTALLER_URL="https://maven.neoforged.net/releases/net/neoforged/neoforge/20.4.251/neoforge-20.4.251-installer.jar"
NEOFORGE_INSTALLER_JAR="neoforge-20.4.251-installer.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Check if the directory name was provided
if [[ -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Error: Missing parameters."
    echo "Usage: $0 <server_directory> <ram_allocation>"
    exit 1
fi

# Function to install Java 22 if needed
install_java_22() {
    echo "Installing Java 22 manually..."

    # Step 1: Download OpenJDK 22 (aarch64 build) from Adoptium
    cd ~
    wget https://github.com/adoptium/temurin22-binaries/releases/download/jdk-22.0.2%2B9/OpenJDK22U-jdk_aarch64_linux_hotspot_22.0.2_9.tar.gz

    # Step 2: Extract and move it to /opt
    tar -xvf OpenJDK22U-jdk_aarch64_linux_hotspot_22.0.2_9.tar.gz
    sudo mv jdk-22.0.2+9 /opt/jdk-22

    # Step 3: Create a system-wide environment setup
    echo "export JAVA_HOME=/opt/jdk-22" | sudo tee /etc/profile.d/jdk22.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/jdk22.sh

    # Step 4: Apply the environment variables
    source /etc/profile.d/jdk22.sh

    # Step 5: Enable java 22 to appear in the alternatives system
    sudo update-alternatives --install /usr/bin/java java /opt/jdk-22/bin/java 2
    sudo update-alternatives --install /usr/bin/javac javac /opt/jdk-22/bin/javac 2

    # Step 6: Clean up the downloaded archive
    rm -f ~/OpenJDK22U-jdk_aarch64_linux_hotspot_22.0.2_9.tar.gz

    echo "Java 22 installation completed and environment variables set."
}

# Function to automatically switch Java version to Java 22
switch_to_java22() {
    echo "Switching to Java 22..."
    if [ -f /opt/jdk-22/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-22/bin/java 2>/dev/null || true
    fi
    export JAVA_HOME=/opt/jdk-22
    export PATH=$JAVA_HOME/bin:$PATH
}

# Function to check if Java 22 is installed
check_java_version() {
    switch_to_java22
    java_version=$(java -version 2>&1 | grep -oP 'version "\K[^"]*')

    if [[ $java_version == 22* ]]; then
        return 0  # Java 22 is installed
    else
        return 1  # Java 22 is not installed
    fi
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
    java -jar "$NEOFORGE_INSTALLER_JAR" --installServer

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Configure JVM arguments with specified RAM allocation
    echo "-Xms1024M" > user_jvm_args.txt
    echo "-Xmx$ram_allocation" >> user_jvm_args.txt

    # Create the start script
    echo "#!/usr/bin/env sh
# Add custom program arguments (such as nogui) to the next line before the \"\$@\" or pass them to this script directly
java @user_jvm_args.txt @libraries/net/neoforged/neoforge/$NEOFORGE_VERSION/unix_args.txt \"\$@\"" > start.sh

    chmod +x start.sh
    echo "NeoForge server for Minecraft $MINECRAFT_VERSION is ready! To start the server, navigate to '$server_dir' and run: './start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_neoforge_server
else
    echo "Java 22 is not installed. Installing Java 22..."
    install_java_22
    if check_java_version; then
        echo "Java 22 installed successfully."
        download_neoforge_server
    else
        echo "There was an issue installing Java 22. Attempting to switch to Java 22..."
        switch_to_java22
        download_neoforge_server
    fi
fi
