#!/bin/bash

SERVER_DIR="$1"
FOLIA_VERSION="26.1.2"
FOLIA_JAR="folia-26.1.2.jar"
FOLIA_URL="https://fill-data.papermc.io/v1/objects/607afd1c3320008e1ffd2eaee6780ace4419d5f8c527b75e79f259be79ebf57b/folia-26.1.2-8.jar"
RAM_ALLOCATION="6G"

if [ -z "$SERVER_DIR" ]; then
    echo "Error: You must specify a server directory name as the first argument."
    echo "Usage: $0 <server_directory_name>"
    exit 1
fi

setup_java_25() {
    if [ -f /opt/jdk-25/bin/java ]; then
        sudo update-alternatives --set java /opt/jdk-25/bin/java 2>/dev/null || true
        sudo update-alternatives --set javac /opt/jdk-25/bin/javac 2>/dev/null || true
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

install_java_25() {
    echo "Installing Java 25 manually..."
    cd ~
    wget https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz
    tar -xvf OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz
    sudo mv jdk-25.0.3+9 /opt/jdk-25
    echo "export JAVA_HOME=/opt/jdk-25" | sudo tee /etc/profile.d/jdk25.sh
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" | sudo tee -a /etc/profile.d/jdk25.sh
    source /etc/profile.d/jdk25.sh
    sudo update-alternatives --install /usr/bin/java java /opt/jdk-25/bin/java 3
    sudo update-alternatives --install /usr/bin/javac javac /opt/jdk-25/bin/javac 3
    rm -f ~/OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.3_9.tar.gz
    echo "Java 25 installation completed."
}

download_server() {
    SERVER_DIR="$(realpath "$SERVER_DIR")"
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || { echo "Error: Failed to navigate to $SERVER_DIR"; exit 1; }

    echo "Downloading Folia $FOLIA_VERSION..."
    curl -o "$FOLIA_JAR" "$FOLIA_URL"
    if [ ! -f "$FOLIA_JAR" ]; then
        echo "Download failed. Check the URL and try again."
        exit 1
    fi

    echo "eula=true" > eula.txt

    printf '#!/bin/bash\njava -Xms1G -Xmx%s -jar %s nogui\n' "$RAM_ALLOCATION" "$FOLIA_JAR" > start.sh
    chmod +x start.sh

    echo "Folia $FOLIA_VERSION server setup complete!"
}

setup_java_25

if check_java_version; then
    echo "Java 25 found."
    download_server
else
    install_java_25
    setup_java_25
    if check_java_version; then
        echo "Java 25 installed successfully."
        download_server
    else
        echo "Failed to install Java 25."
        exit 1
    fi
fi
