#!/bin/bash
#
# Runs SwiftLint.
#
# SwiftLint looks for sourcekitd under the active developer directory. With
# Command Line Tools only, TOOLCHAIN_DIR has to point at the CLT explicitly or
# it crashes trying to load sourcekitdInProc.

set -euo pipefail

cd "$(dirname "$0")"

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: swiftlint not installed. Run: brew install swiftlint" >&2
    exit 1
fi

export TOOLCHAIN_DIR="${TOOLCHAIN_DIR:-/Library/Developer/CommandLineTools}"

exec swiftlint lint --quiet "$@"
