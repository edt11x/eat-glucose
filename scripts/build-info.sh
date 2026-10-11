#!/bin/bash
# build-info.sh — Xcode "Build Info" Run Script phase for the edt-glucose target.
#
# - On device builds (PLATFORM_NAME == iphoneos) increments the counter in
#   build-number.txt, so every build pushed to the phone gets a new number.
#   Simulator builds reuse the current number.
# - Writes BuildInfo.plist (BuildNumber + BuildDate) into the app bundle;
#   ContentView shows it under the "Blood Glucose" title.
#
# The pre-commit hook (scripts/githooks/pre-commit) bumps the same counter on
# commits that don't already include a device-build bump.

set -euo pipefail

COUNTER_FILE="${SRCROOT}/build-number.txt"
OUTPUT_PLIST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/BuildInfo.plist"

BUILD_NUMBER=$(tr -cd '0-9' < "$COUNTER_FILE")
BUILD_NUMBER=${BUILD_NUMBER:-0}

if [ "${PLATFORM_NAME:-}" = "iphoneos" ]; then
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    echo "$BUILD_NUMBER" > "$COUNTER_FILE"
fi

BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$OUTPUT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BuildNumber</key>
    <integer>${BUILD_NUMBER}</integer>
    <key>BuildDate</key>
    <date>${BUILD_DATE}</date>
</dict>
</plist>
EOF

echo "Build Info: build ${BUILD_NUMBER}, ${BUILD_DATE}"
