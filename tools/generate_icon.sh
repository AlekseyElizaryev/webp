#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SWIFT=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift
"$SWIFT" tools/generate_icon.swift Resources
iconutil -c icns Resources/WebPViewer.iconset -o Resources/icon.icns
rm -rf Resources/WebPViewer.iconset
echo "Wrote Resources/icon.icns ($(stat -f%z Resources/icon.icns) bytes)"
