#!/bin/bash

# Ensure Git user identity is configured globally at the start of the script
git config --global user.email "you@example.com"
git config --global user.name "Your Name"

# Get the server directory name from the first argument
SERVER_DIR="$1"
PAPER_VERSION="1.21.4"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/66/downloads/paper-1.21.4-66.jar"
FOLIA_JAR="folia-1.21.4.jar"
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

# Function to switch to javac 21 if available
switch_to_javac21() {
    echo "Switching to javac 21..."
    sudo update-alternatives --config javac <<EOF
1
EOF
}

# Function to install Java 21 manually from Adoptium
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

    # Step 6: Clean up the downloaded folder
    rm -r OpenJDK21U-jdk_aarch64_linux_hotspot_21.0.2_13.tar.gz

    echo "Java 21 installation completed and environment variables set."
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
    echo "#!/bin/bash
    java -Xms1G -Xmx$RAM_ALLOCATION -jar $FOLIA_JAR nogui" > start.sh
    chmod +x start.sh
    echo "Folia server setup complete!"
}

# Update the build_folia function to configure Git identity before building
build_folia() {
    echo "Cloning Folia repository..."
    git clone https://github.com/PaperMC/Folia.git folia_build
    cd folia_build || exit 1

    echo "Building Folia..."
    ./gradlew applyPatches && ./gradlew createMojmapBundlerJar

    # Check if the build was successful
    if [ $? -eq 0 ]; then
        echo "Folia build succeeded."
        # Debugging: Print the server directory and search path
        echo "Debug: SERVER_DIR is set to $SERVER_DIR"
        echo "Debug: Searching for Folia jar in $SERVER_DIR"

        # Ensure we are in the correct directory before searching for the Folia jar
        cd "$SERVER_DIR" || { echo "Error: Failed to navigate to SERVER_DIR: $SERVER_DIR"; exit 1; }

        # Debugging: Confirm the current working directory
        echo "Debug: Current working directory after navigating to SERVER_DIR is $(pwd)"

        # Dynamically search for the Folia jar within the created folder
        folia_jar_path=$(find "$SERVER_DIR" -name "folia-bundler-*.jar" | head -n 1)
        if [ -f "$folia_jar_path" ]; then
            echo "Folia jar found: $folia_jar_path"

            # Remove the existing Paper jar
            paper_jar_path="$SERVER_DIR/paper-1.21.4.jar"
            if [ -f "$paper_jar_path" ]; then
                echo "Removing Paper jar: $paper_jar_path"
                rm "$paper_jar_path"
            else
                echo "Warning: Paper jar not found at $paper_jar_path"
            fi

            # Move and rename the Folia jar
            mv "$folia_jar_path" "$SERVER_DIR/folia-1.21.4.jar"
            echo "Folia jar successfully moved and renamed to folia-1.21.4.jar."

            # Update start.sh to use the Folia jar
            echo "#!/bin/bash
java -Xms1G -Xmx$RAM_ALLOCATION -jar $FOLIA_JAR nogui" > "$SERVER_DIR/start.sh"
            chmod +x "$SERVER_DIR/start.sh"
            echo "start.sh updated to use Folia jar."

            # Remove the folia_build folder to free up space
            echo "Cleaning up: Removing folia_build folder..."
            cd "$SERVER_DIR" || exit 1
            sudo rm -rf folia_build
            echo "folia_build folder removed successfully."
        else
            echo "Error: Folia jar not found in the created folder: $SERVER_DIR."
            echo "Debug: Contents of $SERVER_DIR:"
            ls -R "$SERVER_DIR"
            exit 1
        fi
    else
        echo "Folia build failed. Check the build logs for details."
        exit 1
    fi
}

# Main script flow
# Attempt to switch to Java 21 first
switch_to_java21

# Now check if Java 21 is installed after switching
if check_java_version; then
    echo "Java 21 is already installed."
    download_server
    build_folia
else
    install_java_21
    if check_java_version; then
        echo "Java 21 installed successfully."
        download_server
        build_folia
    else
        echo "There was a problem installing Java 21."
        exit 1
    fi
fi