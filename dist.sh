#!/usr/bin/env bash
# Production build for Mac App Store submission.
#
# Prerequisites (one-time, manual at developer.apple.com):
#   1. Register App ID "llc.infokom.WebPViewer" under Identifiers
#   2. Create a "Mac App Store" provisioning profile for that App ID
#      signed with "Apple Distribution: INFOKOM, LLC (KJHKLWA456)".
#   3. Download the .provisionprofile file and save it as:
#        ./embedded.provisionprofile
#
# Required signing identities in your login keychain (already installed):
#   - Apple Distribution: INFOKOM, LLC (KJHKLWA456)
#   - 3rd Party Mac Developer Installer: INFOKOM, LLC (KJHKLWA456)
#
# Output:
#   ./WebPViewer.app   — signed bundle (Apple Distribution)
#   ./WebPViewer.pkg   — installer (signed with 3rd Party Mac Installer)
#
# Upload to App Store Connect:
#   xcrun altool --upload-app -f WebPViewer.pkg -t macos \
#       --apple-id <your-apple-id> --password <app-specific-password>
# or open WebPViewer.pkg in Transporter.app.

set -euo pipefail

export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SWIFT="$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"

cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

APP_SIGN="Apple Distribution: INFOKOM, LLC (KJHKLWA456)"
PKG_SIGN="3rd Party Mac Developer Installer: INFOKOM, LLC (KJHKLWA456)"

# Pick up any provisioning profile in the project root.
PROFILE=$(ls -1 *.provisionprofile 2>/dev/null | head -1)
if [[ -z "$PROFILE" ]]; then
    echo "ERROR: no *.provisionprofile found in $PROJECT_ROOT" >&2
    echo "Download from https://developer.apple.com/account/resources/profiles" >&2
    exit 1
fi
echo "==> using provisioning profile: $PROFILE"

echo "==> verifying signing identities"
security find-identity -p codesigning -v | grep -q "$APP_SIGN" \
    || { echo "ERROR: '$APP_SIGN' not in keychain" >&2; exit 1; }
security find-identity -p basic -v | grep -q "$PKG_SIGN" \
    || { echo "ERROR: '$PKG_SIGN' not in keychain" >&2; exit 1; }

echo "==> swift build (release, universal)"
"$SWIFT" build -c release --arch arm64 --arch x86_64
BIN=$("$SWIFT" build -c release --arch arm64 --arch x86_64 --show-bin-path)/WebPViewer

if [[ ! -f Resources/icon.icns ]]; then
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
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "==> stripping extended attributes (quarantine, etc.) from bundle"
# Apple rejects packages where any embedded file carries xattrs like
# com.apple.quarantine (browsers tag downloaded files with it).
xattr -cr "$APP"

echo "==> merging app-identifier from profile into entitlements"
PROFILE_PLIST=$(mktemp /tmp/profile.XXXXXX.plist)
DIST_ENTITLEMENTS=$(mktemp /tmp/entitlements.XXXXXX.plist)
trap 'rm -f "$PROFILE_PLIST" "$DIST_ENTITLEMENTS"' EXIT
security cms -D -i "$PROFILE" -o "$PROFILE_PLIST"
APP_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.application-identifier" "$PROFILE_PLIST")
TEAM_IDENTIFIER=$(/usr/libexec/PlistBuddy -c "Print :Entitlements:com.apple.developer.team-identifier" "$PROFILE_PLIST")
cp Resources/WebPViewer.entitlements "$DIST_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APP_IDENTIFIER" "$DIST_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_IDENTIFIER" "$DIST_ENTITLEMENTS"
echo "    application-identifier = $APP_IDENTIFIER"
echo "    team-identifier        = $TEAM_IDENTIFIER"

echo "==> codesigning with Apple Distribution"
codesign --force \
    --sign "$APP_SIGN" \
    --entitlements "$DIST_ENTITLEMENTS" \
    --generate-entitlement-der \
    --options runtime \
    --timestamp \
    "$APP"

echo "==> verifying signature"
codesign --verify --strict --verbose=2 "$APP"

echo "==> building installer .pkg"
PKG="$PROJECT_ROOT/WebPViewer.pkg"
rm -f "$PKG"
productbuild \
    --component "$APP" /Applications \
    --sign "$PKG_SIGN" \
    "$PKG"

echo ""
echo "==> Done."
ls -la "$APP" "$PKG"
echo ""
echo "Upload with:"
echo "  xcrun altool --upload-app -f $PKG -t macos --apple-id YOUR_APPLE_ID --password APP_SPECIFIC_PASSWORD"
echo "or open $PKG in Transporter.app."
