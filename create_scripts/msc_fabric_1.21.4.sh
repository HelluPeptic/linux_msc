#!/bin/bash

MINECRAFT_VERSION="1.21.4"
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
    # If Java 22 is already installed at /opt/jdk-22, set it directly by path
    if [ -f /opt/jdk-22/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-22/bin/java 2>/dev/null || true
    fi
    # Export JAVA_HOME for the current session
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

# Function to verify download integrity
verify_download() {
    local file="$1"
    local min_size="$2"
    
    if [ ! -f "$file" ]; then
        return 1
    fi
    
    local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt "$min_size" ]; then
        return 1
    fi
    
    return 0
}

# Function to download with retry mechanism
download_with_retry() {
    local url="$1"
    local output="$2"
    local min_size="${3:-1000000}"  # Default 1MB minimum
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Download attempt $attempt of $max_attempts..."
        
        if curl -L --fail --show-error -o "$output" "$url"; then
            if verify_download "$output" "$min_size"; then
                echo "Download successful and verified."
                return 0
            else
                echo "Download verification failed (file too small or corrupted)."
                rm -f "$output"
            fi
        else
            echo "Download failed."
            rm -f "$output"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Waiting 3 seconds before retry..."
            sleep 3
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Error: Failed to download after $max_attempts attempts."
    echo "Please check your internet connection and try again."
    echo "If the problem persists, the download URL may be outdated."
    return 1
}

# Function to download and set up the Fabric server
download_fabric_server() {
    # Check disk space (estimate 2GB needed for server)
    local available_gb=$(df . | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_gb" -lt 2 ]; then
        echo "Error: Insufficient disk space. Need at least 2GB, available: ${available_gb}GB"
        exit 1
    fi
    
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading Fabric installer..."
    
    # Download with retry and verification (minimum 1MB for installer)
    if ! download_with_retry "$FABRIC_INSTALLER_URL" "$FABRIC_INSTALLER_JAR" 1000000; then
        echo "Failed to download Fabric installer. Exiting."
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
    echo "Java 22 is not installed. Installing Java 22..."
    install_java_22
    if check_java_version; then
        echo "Java 22 installed successfully."
        download_fabric_server
    else
        echo "There was an issue installing Java 22. Attempting to switch to Java 22..."
        switch_to_java22
        download_fabric_server
    fi
fi
