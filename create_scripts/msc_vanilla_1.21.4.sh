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

# Function to download and set up the Vanilla Minecraft server
download_server() {
    cd "$server_dir" || exit 1

    echo "Downloading Vanilla Minecraft server version $MINECRAFT_VERSION..."
    curl -o "$MINECRAFT_SERVER_JAR" "$MINECRAFT_DOWNLOAD_URL"

    # Check if download was successful
    if [ ! -f "$MINECRAFT_SERVER_JAR" ]; then
        echo "Download failed. Please check the Minecraft download URL."
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
