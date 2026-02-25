#!/usr/bin/env bash
# ============================================================================
# build_app.sh — Builds Steavium.app bundle for macOS (Apple Silicon)
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/Steavium.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "=== Steavium Build Script ==="
echo ""

# ── 1. Clean previous build ─────────────────────────────────────────────────
echo "[1/7] Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── 2. Build with Swift Package Manager (Release) ───────────────────────────
echo "[2/7] Building Steavium (Release, arm64)..."
cd "$PROJECT_ROOT"
swift build -c release --arch arm64 2>&1

BINARY_PATH="$(swift build -c release --arch arm64 --show-bin-path)/Steavium"
if [[ ! -f "$BINARY_PATH" ]]; then
  echo "ERROR: Binary not found at $BINARY_PATH"
  exit 1
fi
echo "    Binary: $BINARY_PATH"

# ── 3. Create .app bundle structure ─────────────────────────────────────────
echo "[3/7] Creating .app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/Steavium"
chmod +x "$MACOS_DIR/Steavium"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"

# ── 4. Generate .icns from logo.png ─────────────────────────────────────────
echo "[4/7] Generating app icon (AppIcon.icns)..."
LOGO_SOURCE="$PROJECT_ROOT/Sources/Resources/logo.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

if [[ ! -f "$LOGO_SOURCE" ]]; then
  echo "WARNING: logo.png not found at $LOGO_SOURCE — skipping icon."
else
  mkdir -p "$ICONSET_DIR"

  # Generate all required sizes for macOS .icns
  sips -z 16 16     "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_16x16.png"      >/dev/null
  sips -z 32 32     "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png"   >/dev/null
  sips -z 32 32     "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_32x32.png"      >/dev/null
  sips -z 64 64     "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png"   >/dev/null
  sips -z 128 128   "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_128x128.png"    >/dev/null
  sips -z 256 256   "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_256x256.png"    >/dev/null
  sips -z 512 512   "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_512x512.png"    >/dev/null
  # For 512@2x we use the original (696x696) padded/resized to 1024
  sips -z 1024 1024 "$LOGO_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1 \
    || cp "$LOGO_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"

  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
  rm -rf "$ICONSET_DIR"
  echo "    Icon generated successfully."
fi

# ── 5. Copy bundled resources ────────────────────────────────────────────────
echo "[5/7] Copying bundled resources..."

# SPM puts resources in Steavium_Steavium.bundle inside the binary directory
BUNDLE_RESOURCE_DIR="$(dirname "$BINARY_PATH")/Steavium_Steavium.bundle"
if [[ -d "$BUNDLE_RESOURCE_DIR" ]]; then
  cp -R "$BUNDLE_RESOURCE_DIR" "$RESOURCES_DIR/"
  echo "    Copied resource bundle."
else
  echo "    WARNING: Resource bundle not found at $BUNDLE_RESOURCE_DIR"
  echo "    The app may not find its scripts and logo at runtime."
fi

# ── 6. Code-sign the .app bundle ─────────────────────────────────────────────
echo "[6/7] Code-signing the app bundle..."

# Use a Developer ID identity if available; otherwise fall back to ad-hoc.
if security find-identity -v -p codesigning | grep -q '"Developer ID Application'; then
  IDENTITY="Developer ID Application"
  echo "    Signing with: $IDENTITY"
else
  IDENTITY="-"   # ad-hoc signature
  echo "    No Developer ID found — using ad-hoc signature."
  echo "    (Users who download this app may need to run:"
  echo "      xattr -cr /Applications/Steavium.app )"
fi

# Sign embedded frameworks / bundles first (inside-out)
find "$APP_BUNDLE" -type d -name '*.bundle' -o -name '*.framework' | while read -r item; do
  codesign --force --sign "$IDENTITY" --timestamp "$item" 2>/dev/null || true
done

# Sign the main bundle (deep as a safety net)
codesign --force --deep --sign "$IDENTITY" --timestamp --options runtime "$APP_BUNDLE"
echo "    Code-signing complete."

# ── 7. Done ──────────────────────────────────────────────────────────────────
echo ""
echo "    App bundle: $APP_BUNDLE"
echo "    Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
if [[ "$IDENTITY" == "-" ]]; then
  echo "NOTE: The app is ad-hoc signed.  Distributed copies will trigger"
  echo "      Gatekeeper.  Users must run:  xattr -cr /Applications/Steavium.app"
  echo ""
fi
echo "You can now run:  open \"$APP_BUNDLE\""
echo "Or create a DMG:  bash Installer/create_dmg.sh"
