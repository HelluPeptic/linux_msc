#!/bin/bash
# Shared helpers for the dynamic server creation scripts.
# Every msc_<loader>.sh sources this file instead of duplicating
# Java-install and Minecraft-manifest logic per version.

# Verify a required command is on PATH, with an install hint if not.
require_cmd() {
    local cmd="$1"
    local hint="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' is required but not installed.${hint:+ ($hint)}"
        exit 1
    fi
}

# Look up a Minecraft version in Mojang's manifest and resolve the
# vanilla server.jar URL and the Java major version it requires.
# Sets: MC_SERVER_URL, JAVA_MAJOR
resolve_vanilla_manifest() {
    local version="$1"
    local manifest package_url package_json

    manifest=$(curl -fsSL "https://launchermeta.mojang.com/mc/game/version_manifest_v2.json") || {
        echo "Error: Could not reach Mojang's version manifest."
        exit 1
    }

    package_url=$(echo "$manifest" | jq -r --arg v "$version" '.versions[] | select(.id == $v) | .url')
    if [ -z "$package_url" ] || [ "$package_url" == "null" ]; then
        echo "Error: Minecraft version '$version' was not found in Mojang's version manifest."
        echo "Double-check the exact version id (e.g. 26.2, 1.21.11)."
        exit 1
    fi

    package_json=$(curl -fsSL "$package_url") || {
        echo "Error: Could not fetch version metadata for '$version'."
        exit 1
    }

    MC_SERVER_URL=$(echo "$package_json" | jq -r '.downloads.server.url // empty')
    JAVA_MAJOR=$(echo "$package_json" | jq -r '.javaVersion.majorVersion // empty')

    if [ -z "$MC_SERVER_URL" ]; then
        echo "Error: Minecraft version '$version' has no server download available."
        exit 1
    fi
    if [ -z "$JAVA_MAJOR" ]; then
        echo "Warning: Could not determine the required Java version for '$version', defaulting to 21."
        JAVA_MAJOR=21
    fi
}

# Ensure a given Java major version is installed under /opt/jdk-<major>,
# downloading it fresh from Adoptium if it isn't there yet.
# Sets: JAVA_BIN
ensure_java() {
    local major="$1"
    JAVA_BIN="/opt/jdk-${major}/bin/java"

    if [ -x "$JAVA_BIN" ]; then
        echo "Java $major is already installed."
        return 0
    fi

    echo "Java $major not found. Downloading Temurin $major (aarch64) from Adoptium..."
    local tmp_tar tmp_extract jdk_dir
    tmp_tar="$(mktemp)"
    if ! curl -fL -o "$tmp_tar" "https://api.adoptium.net/v3/binary/latest/${major}/ga/linux/aarch64/jdk/hotspot/normal/eclipse"; then
        rm -f "$tmp_tar"
        echo "Error: Failed to download Java $major from Adoptium. It may not have been released yet."
        exit 1
    fi

    tmp_extract="$(mktemp -d)"
    tar -xzf "$tmp_tar" -C "$tmp_extract"
    rm -f "$tmp_tar"

    jdk_dir="$(find "$tmp_extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    if [ -z "$jdk_dir" ]; then
        echo "Error: Could not find the extracted JDK directory."
        exit 1
    fi

    sudo rm -rf "/opt/jdk-${major}"
    sudo mv "$jdk_dir" "/opt/jdk-${major}"
    rm -rf "$tmp_extract"

    sudo update-alternatives --install /usr/bin/java java "$JAVA_BIN" "$major" 2>/dev/null || true
    sudo update-alternatives --install /usr/bin/javac javac "/opt/jdk-${major}/bin/javac" "$major" 2>/dev/null || true
    sudo update-alternatives --set java "$JAVA_BIN" 2>/dev/null || true

    if [ ! -x "$JAVA_BIN" ]; then
        echo "Error: Java $major installation failed."
        exit 1
    fi
    echo "Java $major installed to /opt/jdk-${major}."
}
