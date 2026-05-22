#!/bin/bash

# Get the server directory name and RAM allocation from arguments
SERVER_DIR="$1"
FOLIA_VERSION="26.1.2"
FOLIA_JAR="folia-26.1.2.jar"
FOLIA_DOWNLOAD_URL="https://fill-data.papermc.io/v1/objects/607afd1c3320008e1ffd2eaee6780ace4419d5f8c527b75e79f259be79ebf57b/folia-26.1.2-8.jar"

# Accept the custom server directory name and RAM allocation as parameters
server_dir="$1"
ram_allocation="$2"

# Check if the directory name was provided
if [[ -z "$server_dir" || -z "$ram_allocation" ]]; then
    echo "Error: Missing parameters."
    echo "Usage: $0 <server_directory> <ram_allocation>"
    exit 1
fi

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

# Function to switch to Java 22 if available
switch_to_java22() {
    echo "Switching to Java 22..."
    if [ -f /opt/jdk-22/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-22/bin/java 2>/dev/null || true
    fi
    export JAVA_HOME=/opt/jdk-22
    export PATH=$JAVA_HOME/bin:$PATH
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

# Function to download and set up the Folia server
download_folia_server() {
    SERVER_DIR="$(realpath "$server_dir")"
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit 1

    echo "Downloading Folia $FOLIA_VERSION..."
    curl -o "$FOLIA_JAR" "$FOLIA_DOWNLOAD_URL"

    if [ ! -f "$FOLIA_JAR" ]; then
        echo "Download failed. Please check the Folia download URL."
        exit 1
    fi

    # Accept the EULA
    echo "eula=true" > eula.txt

    # Create the start script
    echo "#!/bin/bash
java -Xms1024M -Xmx$ram_allocation -jar $FOLIA_JAR nogui" > start.sh
    chmod +x start.sh

    echo "Folia server for Minecraft $FOLIA_VERSION is ready! To start the server, navigate to '$SERVER_DIR' and run: 'bash start.sh'."
}

# Main script flow
if check_java_version; then
    echo "Correct Java version is already installed."
    download_folia_server
else
    echo "Java 22 is not installed. Installing Java 22..."
    install_java_22
    if check_java_version; then
        echo "Java 22 installed successfully."
        download_folia_server
    else
        echo "There was an issue installing Java 22. Attempting to switch to Java 22..."
        switch_to_java22
        download_folia_server
    fi
fi
