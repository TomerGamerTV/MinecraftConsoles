#!/bin/bash
# build_macos.sh - Build Minecraft LCE for macOS
# Usage: ./build_macos.sh [debug|release] [arm64|universal]
# Requires: Xcode command-line tools (xcode-select --install)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TYPE="${1:-release}"
ARCH="${2:-arm64}"
PRESET="macos"

if [ "$ARCH" = "arm64" ]; then
    PRESET="macos-arm64"
fi

echo "============================================"
echo " Minecraft LCE - macOS Build"
echo " Configuration: ${BUILD_TYPE}"
echo " Architecture: ${ARCH}"
echo " Preset: ${PRESET}"
echo "============================================"

# Check for Xcode tools
if ! command -v xcrun &> /dev/null; then
    echo "ERROR: Xcode command-line tools not found."
    echo "Install with: xcode-select --install"
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Install with: brew install cmake"
    exit 1
fi

echo ""
echo "[1/3] Configuring CMake..."
echo "----------------------------------------------"
cmake --preset "${PRESET}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    2>&1 | tee "${SCRIPT_DIR}/build/${PRESET}/configure.log"

echo ""
echo "[2/3] Building..."
echo "----------------------------------------------"
BUILD_CONFIG="Release"
if [ "$BUILD_TYPE" = "debug" ]; then
    BUILD_CONFIG="Debug"
fi

BUILD_LOG="${SCRIPT_DIR}/build/${PRESET}/build.log"
ERROR_LOG="${SCRIPT_DIR}/build/${PRESET}/build_errors.log"

cmake --build --preset "${PRESET}-${BUILD_TYPE}" \
    --target Minecraft.Client \
    -- -allowProvisioningUpdates \
    2>&1 | tee "${BUILD_LOG}"

BUILD_EXIT=${PIPESTATUS[0]}

# If build failed, extract errors into a dedicated log file with hash
if [ $BUILD_EXIT -ne 0 ]; then
    # Extract only lines with "error:" and the failed commands summary
    {
        echo "=== BUILD ERRORS - $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo ""
        grep -n "error:" "${BUILD_LOG}" || true
        echo ""
        echo "=== FAILED COMMANDS ==="
        grep -A1 "The following build commands failed:" "${BUILD_LOG}" || true
        grep "CompileC.*\.o " "${BUILD_LOG}" | grep -B1 "failures\)" || true
        # Also grab the (N failures) line
        grep "failures)" "${BUILD_LOG}" || true
    } > "${ERROR_LOG}"

    # Compute hash of error content (just the error lines, not timestamps)
    ERROR_HASH=$(grep "error:" "${BUILD_LOG}" | shasum -a 256 | cut -c1-12)

    echo ""
    echo "============================================"
    echo " BUILD FAILED"
    echo " Error log: ${ERROR_LOG}"
    echo " Error hash: ${ERROR_HASH}"
    echo "============================================"
    exit 1
fi

echo ""
echo "[3/3] Packaging .app bundle..."
echo "----------------------------------------------"

APP_PATH="${SCRIPT_DIR}/build/${PRESET}/${BUILD_CONFIG}/Minecraft.Client.app"

if [ -d "$APP_PATH" ]; then
    # Copy assets into the app bundle
    RESOURCES_DIR="${APP_PATH}/Contents/Resources"
    mkdir -p "${RESOURCES_DIR}"

    # Copy game assets
    for dir in music Common/Media Common/res Common/Trial Common/Tutorial; do
        if [ -d "${SCRIPT_DIR}/Minecraft.Client/${dir}" ]; then
            mkdir -p "${RESOURCES_DIR}/${dir}"
            rsync -a --exclude='*.cpp' --exclude='*.h' --exclude='*.swf' \
                "${SCRIPT_DIR}/Minecraft.Client/${dir}/" "${RESOURCES_DIR}/${dir}/"
        fi
    done

    # Copy Windows64Media (shared arc files)
    if [ -d "${SCRIPT_DIR}/Minecraft.Client/Windows64Media" ]; then
        mkdir -p "${RESOURCES_DIR}/Windows64Media"
        rsync -a "${SCRIPT_DIR}/Minecraft.Client/Windows64Media/" "${RESOURCES_DIR}/Windows64Media/"
    fi

    # Copy Metal shader library
    METALLIB="${SCRIPT_DIR}/build/${PRESET}/${BUILD_CONFIG}/default.metallib"
    if [ -f "$METALLIB" ]; then
        cp "$METALLIB" "${RESOURCES_DIR}/default.metallib"
    fi

    echo ""
    echo "============================================"
    echo " BUILD SUCCESSFUL"
    echo " Output: ${APP_PATH}"
    echo "============================================"
    echo ""
    echo "To run: open \"${APP_PATH}\""
else
    echo ""
    echo "WARNING: .app bundle not found at expected path."
    echo "Check the build logs above for errors."
    echo "The build output is in: ${SCRIPT_DIR}/build/${PRESET}/"
    ls -la "${SCRIPT_DIR}/build/${PRESET}/${BUILD_CONFIG}/" 2>/dev/null || true
fi
