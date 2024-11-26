#!/bin/bash

# Get the server directory name from the first argument
SERVER_DIR="$1"
PAPER_VERSION="1.21.1"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/131/downloads/paper-1.21.1-131.jar"
PAPER_JAR="paper-$PAPER_VERSION.jar"
RAM_ALLOCATION="6G"

# Ensure a server directory name is provided
if [ -z "$SERVER_DIR" ]; then
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

# Function to install Java 21 manually from Adoptium
install_java21() {
    echo "Java 21 is not installed. Attempting manual installation from Adoptium."

    JDK_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.5_11.tar.gz"

    # Download the JDK (manual link)
    wget "$JDK_URL" -O openjdk-21.tar.gz
    if [ ! -f openjdk-21.tar.gz ]; then
        echo "Failed to download Java 21. Exiting."
        exit 1
    fi

    # Extract the downloaded archive to /opt/java-21
    echo "Extracting Java 21..."
    sudo mkdir -p /opt/java-21
    if ! sudo tar -xzf openjdk-21.tar.gz -C /opt/java-21 --strip-components=1; then
        echo "Extraction of Java 21 failed."
        rm openjdk-21.tar.gz
        exit 1
    fi

    # Set up Java 21 as default
    export PATH=/opt/java-21/bin:$PATH
    sudo update-alternatives --install /usr/bin/java java /opt/java-21/bin/java 1
    rm openjdk-21.tar.gz
    echo "Java 21 installation completed successfully."
}

# Function to download the Minecraft server .jar file
download_server() {
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit 1

    echo "Downloading Paper server version $PAPER_VERSION..."
    curl -o "$PAPER_JAR" "$PAPER_API_URL"
    if [ ! -f "$PAPER_JAR" ]; then
        echo "Download failed. Check the version and build number and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt
    echo "#!/bin/bash
java -Xms1G -Xmx$RAM_ALLOCATION -jar $PAPER_JAR nogui" > start.sh
    chmod +x start.sh
    echo "Server setup complete! Navigate to '$SERVER_DIR' and run './start.sh' to start the server."
}

# Main script flow
# Attempt to switch to Java 21 first
switch_to_java21

# Now check if Java 21 is installed after switching
if check_java_version; then
    echo "Java 21 is already installed."
    download_server
else
    install_java21
    if check_java_version; then
        echo "Java 21 installed successfully."
        download_server
    else
        echo "There was a problem installing Java 21."
        exit 1
    fi
fi
