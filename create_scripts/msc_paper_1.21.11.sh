#!/bin/bash

PAPER_VERSION="1.21.11"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/69/downloads/paper-1.21.11-69.jar"
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

# Function to switch to Java 22 if available
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

# Function to download the Minecraft server .jar file
download_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading Paper server version $PAPER_VERSION..."
    curl -o "$PAPER_JAR" "$PAPER_API_URL"
    if [ ! -f "$PAPER_JAR" ]; then
        echo "Download failed. Check the version and build number and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt
    echo "#!/bin/bash
java -Xms1024M -Xmx$ram_allocation -jar $PAPER_JAR nogui" > start.sh

    chmod +x start.sh
    echo "Paper server for Minecraft $PAPER_VERSION is ready! Navigate to '$server_dir' and run './start.sh' to start."
}

# Main script flow
switch_to_java22

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
