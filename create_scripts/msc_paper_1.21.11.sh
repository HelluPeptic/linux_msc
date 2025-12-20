#!/bin/bash

PAPER_VERSION="1.21.11"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/66/downloads/paper-1.21.11-66.jar"
PAPER_JAR="paper-$PAPER_VERSION.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Ensure a server directory name is provided
if [ -z "$server_dir" ]; then
    echo "Error: You must specify a server directory name as the first argument."
    echo "Usage: $0 <server_directory_name>"
    exit 1
fi

# Function to check if Java 21 is installed
check_java_version() {
    java_version=$(java -version 2>&1 | awk -F[\"_] 'NR==1 {print $2}')
    if [[ $java_version == 21* ]]; then
        return 0  # Java 21 is installed
    else
        return 1  # Java 21 is not installed
    fi
}

# Function to switch to Java 21 if available
switch_to_java21() {
    echo "Switching to Java 21..."
    sudo update-alternatives --config java <<EOF
1
EOF
}

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
        
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            echo "Retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    echo "Failed to download after $max_attempts attempts."
    return 1
}

# Function to download the Minecraft server .jar file
download_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1
    
    echo "Downloading Paper server version $PAPER_VERSION..."
    if ! download_with_retry "$PAPER_API_URL" "$PAPER_JAR" 10000000; then
        echo "Failed to download Paper server. Check the version and build number."
        exit 1
    fi
    
    echo "eula=true" > eula.txt
    echo "#!/bin/bash
java -Xms1024M -Xmx$ram_allocation -jar $PAPER_JAR nogui" > start.sh
    chmod +x start.sh
    echo "Paper server for Minecraft $PAPER_VERSION is ready! To start the server, navigate to '$server_dir' and run: 'bash start.sh'."
}

# Main script execution flow
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
