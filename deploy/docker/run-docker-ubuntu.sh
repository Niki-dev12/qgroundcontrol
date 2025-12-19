#!/usr/bin/env bash
set -e

# Define variables for better maintainability
DOCKERFILE_PATH="./deploy/docker/Dockerfile-build-ubuntu"
IMAGE_NAME="qgc-ubuntu-docker"
SOURCE_DIR="$(pwd)"
BUILD_DIR="${SOURCE_DIR}/build"

# Build the Docker image
docker build --file "${DOCKERFILE_PATH}" -t "${IMAGE_NAME}" "${SOURCE_DIR}"

# Run the Docker container with necessary permissions and volume mounts
docker run \
  --rm \
  --cap-add SYS_ADMIN \
  --device /dev/fuse \
  --security-opt apparmor:unconfined \
  -v "${SOURCE_DIR}:/project/source" \
  -v "${BUILD_DIR}:/project/build" \
  "${IMAGE_NAME}"

APPIMAGE_PATH=$(ls -t "${BUILD_DIR}"/*.AppImage 2>/dev/null | head -n 1)

if [ -z "$APPIMAGE_PATH" ]; then
    echo "ERROR: No AppImage found in ${BUILD_DIR}"
    exit 1
fi

DIR=$(dirname "$APPIMAGE_PATH")
STRIBOG_BASE="av3_1_2"
GIT_HASH=$(git -C "${SOURCE_DIR}" rev-parse --short=7 HEAD 2>/dev/null || echo "nogit")
NEW_NAME="QGroundControl-${STRIBOG_BASE}-${GIT_HASH}.AppImage"
mv -f "$APPIMAGE_PATH" "${DIR}/${NEW_NAME}"

echo "✓ AppImage renamed to:"
echo "   ${DIR}/${NEW_NAME}"