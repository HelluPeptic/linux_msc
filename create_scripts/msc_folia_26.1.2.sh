#!/bin/bash

# Get the server directory name from the first argument
SERVER_DIR="$1"
FOLIA_VERSION="26.1.2"
FOLIA_JAR="folia-26.1.2.jar"
FOLIA_DOWNLOAD_URL="https://fill-data.papermc.io/v1/objects/607afd1c3320008e1ffd2eaee6780ace4419d5f8c527b75e79f259be79ebf57b/folia-26.1.2-8.jar"
RAM_ALLOCATION="6G"
# v2

# Ensure a server directory name is provided
if [ -z "$SERVER_DIR" ]; then
    echo "Error: You must specify a server directory name as the first argument."
    echo "Usage: $0 <server_directory_name>"
    exit 1
fi

# Function to check if Java 22 is installed
check_java_version() {
    java_version=$(java -version 2>&1 | awk -F["_] 'NR==1 {print $2}')
    if [[ $java_version == 22* ]]; then
        return 0  # Java 22 is installed
    else
        return 1  # Java 22 is not installed
    fi
}

# Function to switch to Java 22 if available
switch_to_java22() {
    echo "Switching to Java 22..."
    if [ -f /opt/jdk-22/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-22/bin/java 2>/dev/null || true
    fi
    export JAVA_HOME=/opt/jdk-22
    export PATH=$JAVA_HOME/bin:$PATH
}

# Function to switch to javac 22 if available
switch_to_javac22() {
    echo "Switching to javac 22..."
    if [ -f /opt/jdk-22/bin/javac ]; then
        sudo update-alternatives --set javac /opt/jdk-22/bin/javac 2>/dev/null || true
    fi
}

# Function to install Java 22 manually from Adoptium
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

# Function to download the Folia server jar
download_server() {
    # Ensure SERVER_DIR is an absolute path
    SERVER_DIR="$(realpath "$SERVER_DIR")"

    # Debugging: Print the absolute path of SERVER_DIR
    echo "Debug: Absolute path of SERVER_DIR is $SERVER_DIR"

    # Ensure the SERVER_DIR exists
    mkdir -p "$SERVER_DIR"

    # Navigate to SERVER_DIR
    cd "$SERVER_DIR" || { echo "Error: Failed to navigate to SERVER_DIR: $SERVER_DIR"; exit 1; }

    # Debugging: Confirm the current working directory after navigating to SERVER_DIR
    echo "Debug: Current working directory after navigating to SERVER_DIR is $(pwd)"

    echo "Downloading Folia $FOLIA_VERSION..."
    curl -o "$FOLIA_JAR" "$FOLIA_DOWNLOAD_URL"
    if [ ! -f "$FOLIA_JAR" ]; then
        echo "Download failed. Check the download URL and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt
    echo '#!/bin/bash' > start.sh
    echo "java -Xms1G -Xmx$RAM_ALLOCATION -jar $FOLIA_JAR nogui" >> start.sh
    chmod +x start.sh
    echo "Folia $FOLIA_VERSION server setup complete!"
}

# Main script flow
# Attempt to switch to Java 22 first
switch_to_java22

# Now check if Java 22 is installed after switching
if check_java_version; then
    echo "Java 22 is already installed."
    download_server
else
    install_java_22
    if check_java_version; then
        echo "Java 22 installed successfully."
        download_server
    else
        echo "There was a problem installing Java 22."
        exit 1
    fi
fi
