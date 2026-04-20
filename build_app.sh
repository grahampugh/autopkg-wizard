#!/bin/bash
# build_app.sh – Build AutoPkgWizard.app bundle from Swift Package Manager output.
#
# Usage:
#   ./build_app.sh           # Debug build
#   ./build_app.sh release   # Release (optimised) build

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AutoPkgWizard"
BUNDLE_NAME="${APP_NAME}.app"
INFO_PLIST="${SCRIPT_DIR}/SupportingFiles/Info.plist"

# Determine build configuration
CONFIG="${1:-debug}"
if [[ "${CONFIG}" == "release" ]]; then
    SWIFT_FLAGS="-c release"
    BUILD_SUBDIR="release"
else
    SWIFT_FLAGS=""
    BUILD_SUBDIR="debug"
fi

echo "==> Building ${APP_NAME} (${CONFIG})…"
cd "${SCRIPT_DIR}"
swift build ${SWIFT_FLAGS}

BUILD_DIR="${SCRIPT_DIR}/.build/${BUILD_SUBDIR}"
EXECUTABLE="${BUILD_DIR}/${APP_NAME}"

if [[ ! -f "${EXECUTABLE}" ]]; then
    echo "ERROR: Executable not found at ${EXECUTABLE}" >&2
    exit 1
fi

# Assemble the .app bundle next to the executable
BUNDLE_DIR="${BUILD_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Assembling ${BUNDLE_NAME}…"

# Clean any previous bundle
rm -rf "${BUNDLE_DIR}"

# Create directory structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RES_DIR}"

# Copy executable
cp "${EXECUTABLE}" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
if [[ -f "${INFO_PLIST}" ]]; then
    cp "${INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
else
    echo "WARNING: Info.plist not found at ${INFO_PLIST}" >&2
fi

# Copy entitlements (for reference, not embedded in binary)
ENTITLEMENTS_FILE="${SCRIPT_DIR}/SupportingFiles/${APP_NAME}.entitlements"
if [[ -f "${ENTITLEMENTS_FILE}" ]]; then
    cp "${ENTITLEMENTS_FILE}" "${RES_DIR}/"
fi

# Copy app icon
ICON_FILE="${SCRIPT_DIR}/SupportingFiles/${APP_NAME}.icns"
if [[ -f "${ICON_FILE}" ]]; then
    cp "${ICON_FILE}" "${RES_DIR}/${APP_NAME}.icns"
else
    echo "WARNING: Icon file not found at ${ICON_FILE}" >&2
fi

# Copy app logo image
LOGO_FILE="${SCRIPT_DIR}/SupportingFiles/autopkg_logo.png"
if [[ -f "${LOGO_FILE}" ]]; then
    cp "${LOGO_FILE}" "${RES_DIR}/autopkg_logo.png"
fi

# Copy third-party SPM resource bundles (e.g. Highlightr).
# SPM's generated Bundle.module accessor looks for bundles at
# Bundle.main.bundleURL/<name>.bundle (the .app root for macOS apps).
# This is an SPM limitation — it doesn't account for .app bundle layout.
for RESOURCE_BUNDLE in "${BUILD_DIR}"/*.bundle; do
    if [[ -d "${RESOURCE_BUNDLE}" ]]; then
        BUNDLE_BASENAME="$(basename "${RESOURCE_BUNDLE}")"
        # Skip our own resource bundle (no longer generated)
        if [[ "${BUNDLE_BASENAME}" == "${APP_NAME}_${APP_NAME}.bundle" ]]; then
            continue
        fi
        cp -R "${RESOURCE_BUNDLE}" "${BUNDLE_DIR}/${BUNDLE_BASENAME}"
    fi
done

echo "==> Built: ${BUNDLE_DIR}"
echo ""
echo "To launch:"
echo "  open \"${BUNDLE_DIR}\""
