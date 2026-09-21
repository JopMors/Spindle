#!/bin/bash
#
# Builds Spindle.app into dist/.
#
# There is no full Xcode on this machine (Command Line Tools only), so the
# bundle is assembled by hand around the SwiftPM binary rather than by
# xcodebuild. Run ./build.sh, then open dist/Spindle.app.

set -euo pipefail

cd "$(dirname "$0")"

CONFIGURATION="${CONFIGURATION:-release}"
APP_NAME="Spindle"
BUNDLE="dist/${APP_NAME}.app"
ADAPTER_DIR=".build/adapter"
ADAPTER="${ADAPTER_DIR}/MediaRemoteAdapter.dylib"

# Local builds stay native for speed; releases go universal so the download
# runs on Intel Macs too. Set UNIVERSAL=1 to force it either way.
ARCH_FLAGS=()
SWIFT_ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(-arch arm64 -arch x86_64)
    SWIFT_ARCH_FLAGS=(--arch arm64 --arch x86_64)
    echo "==> Universal build (arm64 + x86_64)"
fi

echo "==> Building adapter dylib"
mkdir -p "$ADAPTER_DIR"
# The `[@]+` form expands to nothing when the array is empty. macOS ships bash
# 3.2, where a plain "${array[@]}" under `set -u` is an unbound-variable error.
clang -dynamiclib -fobjc-arc -O2 \
    ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} \
    -mmacosx-version-min=14.0 \
    -framework Foundation \
    -o "$ADAPTER" \
    Sources/MediaRemoteAdapter/adapter.m

echo "==> Building Swift package (${CONFIGURATION})"
SWIFT_ARCHS=(${SWIFT_ARCH_FLAGS[@]+"${SWIFT_ARCH_FLAGS[@]}"})
swift build -c "$CONFIGURATION" ${SWIFT_ARCHS[@]+"${SWIFT_ARCHS[@]}"}
BINARY="$(swift build -c "$CONFIGURATION" ${SWIFT_ARCHS[@]+"${SWIFT_ARCHS[@]}"} --show-bin-path)/Spindle"

echo "==> Assembling ${BUNDLE}"
rm -rf "$BUNDLE"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

cp "$BINARY" "${BUNDLE}/Contents/MacOS/Spindle"
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
cp "$ADAPTER" "${BUNDLE}/Contents/Resources/MediaRemoteAdapter.dylib"
cp Sources/MediaRemoteAdapter/stream.pl "${BUNDLE}/Contents/Resources/stream.pl"
printf 'APPL????' > "${BUNDLE}/Contents/PkgInfo"

# Releases stamp their tag in; a plain ./build.sh keeps whatever Info.plist says.
if [[ -n "${APP_VERSION:-}" ]]; then
    PLIST="${BUNDLE}/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${APP_VERSION}" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${APP_VERSION}" "$PLIST"
    echo "==> Stamped version ${APP_VERSION}"
fi

# An ad-hoc signature keeps the app's identity stable, so the Automation
# permission granted in System Settings survives rebuilds.
echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$BUNDLE"

echo
echo "Built ${BUNDLE}"
echo "Run it with:  open '${BUNDLE}'"
