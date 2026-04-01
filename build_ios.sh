#!/bin/bash
# build_ios.sh - Build Minecraft LCE for iOS
# Usage: ./build_ios.sh [debug|release] [device|simulator]
# Requires: Xcode (full installation)
# Output: .app or .ipa file for sideloading

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TYPE="${1:-release}"
TARGET_DEVICE="${2:-device}"
PRESET="ios"

if [ "$TARGET_DEVICE" = "simulator" ]; then
    PRESET="ios-simulator"
fi

echo "============================================"
echo " Minecraft LCE - iOS Build"
echo " Configuration: ${BUILD_TYPE}"
echo " Target: ${TARGET_DEVICE}"
echo " Preset: ${PRESET}"
echo "============================================"

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "ERROR: Xcode not found. Full Xcode installation required for iOS builds."
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "ERROR: CMake not found. Install with: brew install cmake"
    exit 1
fi

echo ""
echo "[1/4] Configuring CMake..."
echo "----------------------------------------------"
cmake --preset "${PRESET}" \
    2>&1 | tee "${SCRIPT_DIR}/build/${PRESET}/configure.log"

echo ""
echo "[2/4] Building..."
echo "----------------------------------------------"
BUILD_CONFIG="Release"
if [ "$BUILD_TYPE" = "debug" ]; then
    BUILD_CONFIG="Debug"
fi

cmake --build --preset "${PRESET}-${BUILD_TYPE}" \
    --target Minecraft.Client \
    -- -allowProvisioningUpdates \
       CODE_SIGN_IDENTITY="-" \
       CODE_SIGNING_ALLOWED="NO" \
    2>&1 | tee "${SCRIPT_DIR}/build/${PRESET}/build.log"

echo ""
echo "[3/4] Creating .app bundle with assets..."
echo "----------------------------------------------"

APP_PATH="${SCRIPT_DIR}/build/${PRESET}/${BUILD_CONFIG}-iphoneos/Minecraft.Client.app"
if [ "$TARGET_DEVICE" = "simulator" ]; then
    APP_PATH="${SCRIPT_DIR}/build/${PRESET}/${BUILD_CONFIG}-iphonesimulator/Minecraft.Client.app"
fi

# Try alternate Xcode output paths
if [ ! -d "$APP_PATH" ]; then
    APP_PATH=$(find "${SCRIPT_DIR}/build/${PRESET}" -name "Minecraft.Client.app" -type d 2>/dev/null | head -1)
fi

if [ -d "$APP_PATH" ]; then
    # Copy game assets into the app bundle
    for dir in music Common/Media Common/res Common/Trial Common/Tutorial; do
        if [ -d "${SCRIPT_DIR}/Minecraft.Client/${dir}" ]; then
            mkdir -p "${APP_PATH}/${dir}"
            rsync -a --exclude='*.cpp' --exclude='*.h' --exclude='*.swf' \
                "${SCRIPT_DIR}/Minecraft.Client/${dir}/" "${APP_PATH}/${dir}/"
        fi
    done

    if [ -d "${SCRIPT_DIR}/Minecraft.Client/Windows64Media" ]; then
        mkdir -p "${APP_PATH}/Windows64Media"
        rsync -a "${SCRIPT_DIR}/Minecraft.Client/Windows64Media/" "${APP_PATH}/Windows64Media/"
    fi

    echo ""
    echo "[4/4] Creating .ipa for sideloading..."
    echo "----------------------------------------------"

    if [ "$TARGET_DEVICE" = "device" ]; then
        IPA_DIR="${SCRIPT_DIR}/build/${PRESET}/ipa"
        mkdir -p "${IPA_DIR}/Payload"
        cp -r "$APP_PATH" "${IPA_DIR}/Payload/"
        cd "${IPA_DIR}"
        zip -r -q "${SCRIPT_DIR}/build/MinecraftLCE-iOS.ipa" Payload/
        cd "${SCRIPT_DIR}"
        rm -rf "${IPA_DIR}"

        echo ""
        echo "============================================"
        echo " BUILD SUCCESSFUL"
        echo " .app: ${APP_PATH}"
        echo " .ipa: ${SCRIPT_DIR}/build/MinecraftLCE-iOS.ipa"
        echo "============================================"
        echo ""
        echo "To sideload the .ipa:"
        echo "  - Use AltStore, Sideloadly, or Apple Configurator"
        echo "  - Or install via: ios-deploy --bundle \"${APP_PATH}\""
    else
        echo ""
        echo "============================================"
        echo " BUILD SUCCESSFUL (Simulator)"
        echo " .app: ${APP_PATH}"
        echo "============================================"
        echo ""
        echo "To install on simulator:"
        echo "  xcrun simctl install booted \"${APP_PATH}\""
        echo "  xcrun simctl launch booted com.lce.minecraft-console"
    fi
else
    echo ""
    echo "ERROR: .app bundle not found."
    echo "Check build logs for errors."
    find "${SCRIPT_DIR}/build/${PRESET}" -name "*.app" -type d 2>/dev/null || echo "No .app found"
fi
