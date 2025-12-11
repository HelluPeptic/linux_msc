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
echo "#!/bin/bash
java -Xms1024M -Xmx${ram_allocation} -jar server.jar nogui" > "$server_dir/start.sh"

chmod +x "$server_dir/start.sh"

# Placeholder for the server JAR file
touch "$server_dir/vanilla_$MINECRAFT_VERSION.jar"

# Confirmation message
echo "Vanilla server $MINECRAFT_VERSION created successfully in $server_dir."

# Function to install Java 21 if needed
install_java_21() {
    echo "Installing Java 21 manually..."

    # Step 1: Download OpenJDK 21 (aarch64 build) from Adoptium
    cd ~
    wget https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.2%2B13/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.2_13.tar.gz

    # Step 2: Extract and move it to /opt
    tar -xvf OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.2_13.tar.gz
    sudo mv jdk-21.0.2+13 /opt/jdk-21

    # Step 3: Create a system-wide environment setup
    echo "export JAVA_HOME=/opt/jdk-21" | sudo tee /etc/profile.d/jdk21.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/jdk21.sh

    # Step 4: Apply the environment variables
    source /etc/profile.d/jdk21.sh

    # Step 5: Enable java 21 to appear in the alternatives system
    sudo update-alternatives --install /usr/bin/java java /opt/jdk-21/bin/java 2
    sudo update-alternatives --install /usr/bin/javac javac /opt/jdk-21/bin/javac 2

    echo "Java 21 installation completed and environment variables set."
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

# Function to download and set up the Vanilla Minecraft server
download_server() {
    # Check disk space (estimate 2GB needed for server)
    local available_gb=$(df . | awk 'NR==2 {print int($4/1024/1024)}')
    if [ "$available_gb" -lt 2 ]; then
        echo "Error: Insufficient disk space. Need at least 2GB, available: ${available_gb}GB"
        exit 1
    fi
    
    cd "$server_dir" || exit 1

    echo "Downloading Vanilla Minecraft server version $MINECRAFT_VERSION..."
    
    # Download with retry and verification (minimum 20MB for server jar)
    if ! download_with_retry "$MINECRAFT_DOWNLOAD_URL" "$MINECRAFT_SERVER_JAR" 20000000; then
        echo "Failed to download server jar. Exiting."
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
