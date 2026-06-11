#!/bin/bash

MINECRAFT_VERSION="26.1.2"
FABRIC_INSTALLER_URL="https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.1/fabric-installer-1.1.1.jar"
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

download_fabric_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1
    echo "Downloading Fabric installer..."
    curl -o "$FABRIC_INSTALLER_JAR" "$FABRIC_INSTALLER_URL"
    if [ ! -f "$FABRIC_INSTALLER_JAR" ]; then
        echo "Download failed. Please check the Fabric installer URL."
        exit 1
    fi
    echo "Running Fabric installer for Minecraft version $MINECRAFT_VERSION..."
    /opt/jdk-25/bin/java -jar "$FABRIC_INSTALLER_JAR" server -mcversion $MINECRAFT_VERSION -downloadMinecraft
    if [ ! -f "$MINECRAFT_SERVER_JAR" ]; then
        echo "Fabric installation failed. Please check the installer output."
        exit 1
    fi
    echo "eula=true" > eula.txt
    printf '#!/bin/bash\n/opt/jdk-25/bin/java -Xms1024M -Xmx%s -jar %s nogui\n' "$ram_allocation" "$MINECRAFT_SERVER_JAR" > start.sh
    chmod +x start.sh
    echo "Fabric server for Minecraft $MINECRAFT_VERSION is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

if check_java_version; then
    echo "Java 25 is already installed."
    download_fabric_server
else
    echo "Java 25 is not installed. Installing Java 25..."
    install_java_25
    if check_java_version; then
        echo "Java 25 installed successfully."
        download_fabric_server
    else
        echo "There was an issue installing Java 25. Attempting to switch to Java 25..."
        switch_to_java25
        download_fabric_server
    fi
fi
