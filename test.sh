#!/bin/bash
#
# Runs the unit tests.
#
# Without full Xcode there is no XCTest, so the tests use swift-testing. The
# Command Line Tools ship Testing.framework but not on the default search
# paths, hence the -F and -rpath flags below.

set -euo pipefail

cd "$(dirname "$0")"

CLT="${CLT:-/Library/Developer/CommandLineTools}"
FRAMEWORKS="${CLT}/Library/Developer/Frameworks"
INTEROP_LIB="${CLT}/Library/Developer/usr/lib"

if [ ! -d "$FRAMEWORKS/Testing.framework" ]; then
    echo "error: Testing.framework not found at ${FRAMEWORKS}" >&2
    exit 1
fi

exec swift test \
    -Xswiftc -F -Xswiftc "$FRAMEWORKS" \
    -Xlinker -F -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$INTEROP_LIB" \
    "$@"
