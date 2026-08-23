#!/bin/bash

PAPER_VERSION="26.2"
PAPER_BUILD="116"
PAPER_API_URL="https://fill-data.papermc.io/v1/objects/17eee738bc0f6b747646be4199672c4efcb2084efd7e291ec5254a45d5ae6f2e/paper-26.2-116.jar"
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

# Function to download the Minecraft server .jar file
download_server() {
    mkdir -p "$server_dir"
    cd "$server_dir" || exit 1

    echo "Downloading Paper server version $PAPER_VERSION (build $PAPER_BUILD)..."
    curl -o "$PAPER_JAR" "$PAPER_API_URL"
    if [ ! -f "$PAPER_JAR" ]; then
        echo "Download failed. Check the version and build number and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt
    printf '#!/bin/bash\n/opt/jdk-25/bin/java -Xms1024M -Xmx%s -jar %s nogui\n' "$ram_allocation" "$PAPER_JAR" > start.sh

    chmod +x start.sh
    echo "Paper server for Minecraft $PAPER_VERSION is ready! Navigate to '$server_dir' and run './start.sh' to start."
}

# Main script flow
if check_java_version; then
    echo "Java 25 is already installed."
    download_server
else
    echo "Java 25 is not installed. Installing Java 25..."
    install_java_25
    if check_java_version; then
        echo "Java 25 installed successfully."
        download_server
    else
        echo "There was an issue installing Java 25. Attempting to switch to Java 25..."
        switch_to_java25
        download_server
    fi
fi
