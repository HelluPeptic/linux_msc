#!/bin/bash

# Get the server directory name from the first argument
SERVER_DIR="$1"
PAPER_VERSION="1.21.4"
PAPER_API_URL="https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/66/downloads/paper-1.21.4-66.jar"
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
install_java_21() {
    echo "Installing Java 21..."
    sudo apt update
    sudo apt install -y default-jdk
    sudo apt install -y openjdk-21-jdk
}

# Function to download the Minecraft server .jar file
download_server() {
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit 1

    echo "Downloading Folia server version $PAPER_VERSION..."
    curl -o "$PAPER_JAR" "$PAPER_API_URL"
    if [ ! -f "$PAPER_JAR" ]; then
        echo "Download failed. Check the version and build number and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt
    echo "#!/bin/bash
    java -Xms1G -Xmx$RAM_ALLOCATION -jar $PAPER_JAR nogui" > start.sh
    chmod +x start.sh
    echo "Folia server setup complete!"
}

# Function to retry the Folia build process
retry_build_folia() {
    local retries=3
    local count=0

    while [ $count -lt $retries ]; do
        echo "Attempting to build Folia (Attempt $((count + 1)) of $retries)..."
        ./gradlew applyPatches && ./gradlew createMojmapBundlerJar

        if [ $? -eq 0 ]; then
            echo "Folia build succeeded on attempt $((count + 1))."
            return 0
        fi

        echo "Folia build failed. Retrying..."
        count=$((count + 1))
        sleep 5  # Wait before retrying
    done

    echo "Folia build failed after $retries attempts. Check the build logs for details."
    return 1
}

# Function to configure Git user identity
configure_git_identity() {
    echo "Configuring Git user identity..."
    git config user.email "you@example.com"
    git config user.name "Your Name"
}

# Update the build_folia function to configure Git identity before building
build_folia() {
    echo "Cloning Folia repository..."
    git clone https://github.com/PaperMC/Folia.git folia_build
    cd folia_build || exit 1

    # Configure Git user identity
    configure_git_identity

    echo "Building Folia..."
    if ! retry_build_folia; then
        exit 1
    fi

    if [ -d "paper-server/build/libs" ]; then
        echo "Folia build complete! The output is located in paper-server/build/libs."
    else
        echo "Folia build failed. Check the build logs for details."
        exit 1
    fi
}

# Function to replace Paper jar with Folia jar
replace_with_folia() {
    echo "Replacing Paper jar with Folia jar..."
    local folia_jar="folia-1.21.4.jar"

    # Locate the Folia jar in the build output
    if [ -f "paper-server/build/libs/$folia_jar" ]; then
        mv "paper-server/build/libs/$folia_jar" "$SERVER_DIR/$folia_jar"
        rm "$SERVER_DIR/$PAPER_JAR"

        # Update start.sh to use the Folia jar
        echo "#!/bin/bash
        java -Xms1G -Xmx$RAM_ALLOCATION -jar $folia_jar nogui" > "$SERVER_DIR/start.sh"
        chmod +x "$SERVER_DIR/start.sh"
        echo "Folia jar successfully replaced and start.sh updated!"
    else
        echo "Error: Folia jar not found in the build output."
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
    replace_with_folia
else
    install_java_21
    if check_java_version; then
        echo "Java 21 installed successfully."
        download_server
        build_folia
        replace_with_folia
    else
        echo "There was a problem installing Java 21."
        exit 1
    fi
fi