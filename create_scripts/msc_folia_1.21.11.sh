#!/bin/bash

# Ensure Git user identity is configured globally at the start of the script
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

# Get the server directory name from the first argument
SERVER_DIR="$1"
PAPER_VERSION="1.21.11"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/66/downloads/paper-1.21.11-66.jar"
FOLIA_JAR="folia-1.21.11.jar"
RAM_ALLOCATION="6G"

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

# Function to download the Minecraft server .jar file
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

    echo "Downloading Paper server version $PAPER_VERSION..."
    curl -o "$FOLIA_JAR" "$PAPER_API_URL"
    if [ ! -f "$FOLIA_JAR" ]; then
        echo "Download failed. Check the version and build number and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt

    echo "Cloning Folia repository..."
    git clone https://github.com/PaperMC/Folia.git
    if [ ! -d "Folia" ]; then
        echo "Failed to clone Folia repository."
        exit 1
    fi

    cd Folia || exit 1

    # Apply patches and build Folia
    echo "Building Folia (this may take several minutes)..."
    ./gradlew applyPatches
    ./gradlew createReobfBundlerJar

    # Locate the built Folia jar
    FOLIA_BUILD_JAR=$(find build/libs -name "folia-bundler-*.jar" | head -n 1)
    if [ -z "$FOLIA_BUILD_JAR" ]; then
        echo "Failed to find the built Folia jar. Build may have failed."
        exit 1
    fi

    # Copy the built jar to the server directory
    cp "$FOLIA_BUILD_JAR" "../$FOLIA_JAR"
    cd ..

    # Clean up the Folia repository folder
    rm -rf Folia

    echo "#!/bin/bash
java -Xms1024M -Xmx$RAM_ALLOCATION -jar $FOLIA_JAR nogui" > start.sh
    chmod +x start.sh

    echo "Folia server for Minecraft $PAPER_VERSION is ready! To start the server, navigate to '$SERVER_DIR' and run: 'bash start.sh'."
}

# Main script execution
if check_java_version; then
    echo "Correct Java version is already installed."
    download_server
else
    echo "Java 22 is not installed. Installing Java 22..."
    install_java_22
    if check_java_version; then
        echo "Java 22 installed successfully."
        download_server
    else
        echo "There was an issue installing Java 22. Attempting to switch to Java 22..."
        switch_to_java22
        switch_to_javac22
        download_server
    fi
fi
