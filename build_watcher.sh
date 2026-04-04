#!/bin/bash
# build_watcher.sh - Run this on the build machine (Tomer's Mac)
# Watches for a trigger file and auto-runs builds
# Usage: ./build_watcher.sh

WATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
TRIGGER_FILE="${WATCH_DIR}/build/build_trigger"
RESULT_FILE="${WATCH_DIR}/build/build_result"

echo "Build watcher started. Watching for: ${TRIGGER_FILE}"
echo "Press Ctrl+C to stop."

while true; do
    if [ -f "${TRIGGER_FILE}" ]; then
        echo ""
        echo "=== Build triggered ==="
        echo "BUILDING" > "${RESULT_FILE}"
        rm -f "${TRIGGER_FILE}"

        # Run the actual build
        cd "${WATCH_DIR}"
        ./build_macos.sh release arm64 2>&1
        BUILD_EXIT=$?

        if [ $BUILD_EXIT -eq 0 ]; then
            echo "SUCCESS" > "${RESULT_FILE}"
            echo "=== Build SUCCEEDED ==="
        else
            echo "FAILED" > "${RESULT_FILE}"
            echo "=== Build FAILED - check build_errors.log ==="
        fi
    fi
    sleep 2
done
