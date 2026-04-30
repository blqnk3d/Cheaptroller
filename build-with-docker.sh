#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/build-output"

mkdir -p "${OUTPUT_DIR}"

usage() {
    echo "Usage: $0 [android|linux|all]"
    echo ""
    echo "Build Cheaptroller binaries using Docker"
    echo "  android - Build Android APK"
    echo "  linux   - Build Linux binaries (backend + Flutter desktop)"
    echo "  all     - Build both"
    exit 1
}

build_android() {
    echo "=== Building Android APK ==="
    docker build -f "${SCRIPT_DIR}/Dockerfile.android" -t cheaptroller-android "${SCRIPT_DIR}"
    
    echo "=== Extracting APK ==="
    CONTAINER_ID=$(docker create cheaptroller-android)
    docker cp "${CONTAINER_ID}:/app/build/app/outputs/flutter-apk/app-release.apk" "${OUTPUT_DIR}/"
    docker rm "${CONTAINER_ID}"
    
    echo "Android APK: ${OUTPUT_DIR}/app-release.apk"
}

build_linux() {
    echo "=== Building Linux binaries ==="
    docker build -f "${SCRIPT_DIR}/Dockerfile.linux" -t cheaptroller-linux "${SCRIPT_DIR}"
    
    echo "=== Extracting Linux binaries ==="
    CONTAINER_ID=$(docker create cheaptroller-linux)
    
    # Extract backend binary
    docker cp "${CONTAINER_ID}:/app/dist/cheaptroller-backend" "${OUTPUT_DIR}/" 2>/dev/null || true
    
    # Extract Flutter Linux app
    docker cp "${CONTAINER_ID}:/app/dist/game_controler_linux" "${OUTPUT_DIR}/" 2>/dev/null || true
    
    docker rm "${CONTAINER_ID}"
    
    echo "Linux binaries in: ${OUTPUT_DIR}/"
    ls -la "${OUTPUT_DIR}/"
}

if [ $# -eq 0 ]; then
    usage
fi

for arg in "$@"; do
    case $arg in
        android)
            build_android
            ;;
        linux)
            build_linux
            ;;
        all)
            build_android
            build_linux
            ;;
        *)
            usage
            ;;
    esac
done

echo ""
echo "=== Build complete ==="
echo "Output directory: ${OUTPUT_DIR}"
