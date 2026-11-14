#!/bin/sh
# Formatea todo el código Swift del repo. Con --lint solo comprueba (para CI).
set -eu
cd "$(dirname "$0")/.."
PATHS="StaiN StaiNUITests Packages/StainKit/Sources Packages/StainKit/Tests Packages/StainKit/Package.swift"
if [ "${1:-}" = "--lint" ]; then
    xcrun swift-format lint --strict --recursive $PATHS
else
    xcrun swift-format format --in-place --recursive $PATHS
fi
