#!/usr/bin/env bash
#
# Fetch yabai arm64 binary and place it under vista/Resources/yabai/.
# Idempotent: skips download if the expected version is already present.
#
# Usage: scripts/fetch-yabai.sh [VERSION]
#   Default VERSION: 7.1.16

set -euo pipefail

YABAI_VERSION="${1:-7.1.16}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VISTA_DIR="$(dirname "$SCRIPT_DIR")"
RES_DIR="$VISTA_DIR/Resources/yabai"
BIN_PATH="$RES_DIR/bin/yabai"

mkdir -p "$RES_DIR/bin"

if [[ -x "$BIN_PATH" ]]; then
    CURRENT_VERSION="$("$BIN_PATH" --version 2>/dev/null | sed 's/yabai-v//' || true)"
    if [[ "$CURRENT_VERSION" == "$YABAI_VERSION" ]]; then
        echo "[fetch-yabai] Already at v${YABAI_VERSION}, skipping."
        exit 0
    fi
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

URL="https://github.com/koekeishiya/yabai/releases/download/v${YABAI_VERSION}/yabai-v${YABAI_VERSION}.tar.gz"
echo "[fetch-yabai] Downloading $URL"
curl -fL --progress-bar -o "$TMPDIR/yabai.tar.gz" "$URL"

echo "[fetch-yabai] Extracting"
tar xzf "$TMPDIR/yabai.tar.gz" -C "$TMPDIR"

SRC_BIN="$TMPDIR/archive/bin/yabai"
if [[ ! -f "$SRC_BIN" ]]; then
    echo "[fetch-yabai] ERROR: yabai binary not found in archive"
    exit 1
fi

echo "[fetch-yabai] Thinning to arm64"
lipo -thin arm64 "$SRC_BIN" -output "$BIN_PATH"
chmod +x "$BIN_PATH"

if [[ -f "$TMPDIR/archive/LICENSE.txt" ]]; then
    cp "$TMPDIR/archive/LICENSE.txt" "$RES_DIR/LICENSE.txt"
fi

echo "[fetch-yabai] Installed: $($BIN_PATH --version)"
echo "[fetch-yabai] Path:      $BIN_PATH"
echo "[fetch-yabai] Size:      $(ls -lh "$BIN_PATH" | awk '{print $5}')"
