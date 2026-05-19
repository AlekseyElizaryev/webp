#!/usr/bin/env bash
set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

CONF="${1:-release}"

echo "==> swift build ($CONF, universal)"
"$SWIFT" build -c "$CONF" --arch arm64 --arch x86_64

BIN_DIR=$("$SWIFT" build -c "$CONF" --arch arm64 --arch x86_64 --show-bin-path)
BIN="$BIN_DIR/WebPViewer"

if [[ ! -f "$BIN" ]]; then
    echo "ERROR: binary not found at $BIN" >&2
    exit 1
fi

if [[ ! -f Resources/icon.icns ]]; then
    echo "==> generating icon (Resources/icon.icns missing)"
    tools/generate_icon.sh
fi

APP="$PROJECT_ROOT/WebPViewer.app"
echo "==> packaging $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WebPViewer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/icon.icns "$APP/Contents/Resources/icon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> ad-hoc codesigning with sandbox entitlements"
codesign --force --deep \
    --sign - \
    --entitlements Resources/WebPViewer.entitlements \
    --options runtime \
    "$APP"

echo ""
echo "Built: $APP"
file "$APP/Contents/MacOS/WebPViewer"
echo ""
codesign --display --verbose --entitlements - "$APP" 2>&1 | grep -E '(Signature|Authority|TeamIdentifier|entitlement|com.apple.security)' | head -20 || true
