#!/usr/bin/env bash
#
# Build a distributable Vista.app .zip.
#
# Usage:
#   scripts/package.sh [VERSION]
#
# Environment variables (all optional):
#   DEV_ID          Developer ID Application identity, e.g. "Developer ID Application: Foo (TEAMID)"
#                   If unset, falls back to ad-hoc signing (codesign -s -).
#   NOTARY_PROFILE  notarytool keychain profile name (requires DEV_ID set).
#                   If both set, the resulting zip is uploaded and the .app is stapled.
#   YABAI_VERSION   yabai version to bundle (default 7.1.16).
#
# Output:
#   build/Vista-<VERSION>-arm64.zip  (plus SHA-256)

set -euo pipefail

VERSION="${1:-}"
YABAI_VERSION="${YABAI_VERSION:-7.1.16}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VISTA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$VISTA_DIR"

if [[ -z "$VERSION" ]]; then
    VERSION="$(grep 'MARKETING_VERSION' project.yml | awk '{print $2}' | tr -d '"' | head -1)"
fi

BUILD_DIR="$VISTA_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Vista.xcarchive"
APP_DIR="$BUILD_DIR/Vista.app"
ZIP_PATH="$BUILD_DIR/Vista-${VERSION}-arm64.zip"

info() { echo -e "\033[36m[package]\033[0m $*"; }
err()  { echo -e "\033[31m[package ERROR]\033[0m $*"; exit 1; }

# -- Step 1: fetch bundled yabai ---------------------------------------------
info "Step 1/7  Fetching yabai v${YABAI_VERSION}"
"$SCRIPT_DIR/fetch-yabai.sh" "$YABAI_VERSION"

# -- Step 2: regenerate xcodeproj --------------------------------------------
info "Step 2/7  Regenerating Xcode project"
if ! command -v xcodegen >/dev/null; then
    err "xcodegen not found. Install via 'brew install xcodegen'."
fi
xcodegen generate >/dev/null

# -- Step 3: clean build directory -------------------------------------------
info "Step 3/7  Cleaning previous build artifacts"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# -- Step 4: archive ---------------------------------------------------------
info "Step 4/7  Building Release archive"
xcodebuild \
    -project Vista.xcodeproj \
    -scheme Vista \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -destination 'generic/platform=macOS' \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS=arm64 \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    archive \
    > "$BUILD_DIR/xcodebuild.log" 2>&1 \
    || { tail -30 "$BUILD_DIR/xcodebuild.log"; err "xcodebuild archive failed. Full log: $BUILD_DIR/xcodebuild.log"; }

cp -R "$ARCHIVE_PATH/Products/Applications/Vista.app" "$APP_DIR"

# -- Step 5: verify bundled yabai --------------------------------------------
BUNDLED_YABAI="$APP_DIR/Contents/Resources/yabai/bin/yabai"
if [[ ! -x "$BUNDLED_YABAI" ]]; then
    err "yabai binary not found in bundle: $BUNDLED_YABAI"
fi
chmod +x "$BUNDLED_YABAI"

# -- Step 6: sign ------------------------------------------------------------
if [[ -n "${DEV_ID:-}" ]]; then
    info "Step 5/7  Signing with Developer ID: $DEV_ID"
    # Sign bundled yabai first (inside-out).
    codesign --force --options runtime --timestamp \
        --sign "$DEV_ID" \
        "$BUNDLED_YABAI"
    codesign --force --options runtime --timestamp \
        --sign "$DEV_ID" --deep \
        "$APP_DIR"
else
    info "Step 5/7  Ad-hoc signing (no DEV_ID set)"
    codesign --force --sign - "$BUNDLED_YABAI"
    codesign --force --deep --sign - "$APP_DIR"
fi

codesign --verify --deep --strict "$APP_DIR" || err "codesign verification failed"

# -- Step 7: zip + optional notarization --------------------------------------
info "Step 6/7  Creating .zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

if [[ -n "${DEV_ID:-}" ]] && [[ -n "${NOTARY_PROFILE:-}" ]]; then
    info "Step 7/7  Notarizing via keychain profile '$NOTARY_PROFILE'"
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait \
        --timeout 30m
    info "Stapling ticket to .app"
    xcrun stapler staple "$APP_DIR"
    # Recreate zip after stapling
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
else
    info "Step 7/7  Skipping notarization (set DEV_ID + NOTARY_PROFILE to enable)"
fi

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
SIZE="$(ls -lh "$ZIP_PATH" | awk '{print $5}')"

cat <<EOF

================================================================
  Vista ${VERSION} arm64 build complete
================================================================
  App    : $APP_DIR
  Zip    : $ZIP_PATH
  Size   : $SIZE
  SHA256 : $SHA256
EOF

if [[ -z "${DEV_ID:-}" ]]; then
    cat <<EOF

  Note: ad-hoc signed. First-time users must right-click the app
        and choose "Open" once to bypass Gatekeeper.
EOF
fi

echo "================================================================"
