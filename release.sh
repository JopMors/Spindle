#!/bin/bash
#
# Packages a downloadable build: dist/Spindle-<version>.zip
#
# The zip is made with ditto rather than `zip`, because ditto preserves the
# bundle's symlinks, resource forks and code signature. A zip built with
# `zip -r` can arrive on the other end with a broken signature, which makes
# macOS refuse to open it at all rather than merely warning about it.
#
#   ./release.sh 1.0.0
#
# Then attach the zip to a GitHub release. Tagging v1.0.0 and pushing the tag
# does the same thing on CI; see .github/workflows/release.yml.

set -euo pipefail

cd "$(dirname "$0")"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
    echo "usage: ./release.sh <version>   e.g. ./release.sh 1.0.0" >&2
    exit 1
fi

# Accept the tag form too, so `./release.sh v1.0.0` does the expected thing.
VERSION="${VERSION#v}"

APP_NAME="Spindle"
BUNDLE="dist/${APP_NAME}.app"
ZIP="dist/Spindle-${VERSION}.zip"

APP_VERSION="$VERSION" UNIVERSAL=1 ./build.sh

echo "==> Verifying the bundle"
codesign --verify --strict "$BUNDLE"
for slice in arm64 x86_64; do
    lipo -info "${BUNDLE}/Contents/MacOS/Spindle" | grep -q "$slice" \
        || { echo "error: binary is missing the ${slice} slice" >&2; exit 1; }
done
test -x "${BUNDLE}/Contents/MacOS/Spindle"
test -f "${BUNDLE}/Contents/Resources/MediaRemoteAdapter.dylib"
test -f "${BUNDLE}/Contents/Resources/stream.pl"
test -f "${BUNDLE}/Contents/Resources/AppIcon.icns"

echo "==> Packaging ${ZIP}"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE" "$ZIP"

echo
echo "Built ${ZIP}  ($(du -h "$ZIP" | cut -f1))"
echo "SHA256: $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo
echo "Attach it to a GitHub release — either drag it onto the release page,"
echo "or, with the GitHub CLI installed:"
echo "  gh release create v${VERSION} '${ZIP}' --title 'Spindle ${VERSION}' --generate-notes"
