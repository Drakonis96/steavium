#!/usr/bin/env bash
# ============================================================================
# create_dmg.sh — Creates a distributable DMG installer for Steavium
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build"
APP_BUNDLE="$BUILD_DIR/Steavium.app"
DMG_NAME="Steavium-Installer"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"
VOLUME_NAME="Steavium"

echo "=== Steavium DMG Installer Creator ==="
echo ""

# ── 1. Check that the .app exists ───────────────────────────────────────────
if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found at: $APP_BUNDLE"
  echo "Run 'bash Installer/build_app.sh' first."
  exit 1
fi

# ── 2. Create staging directory ──────────────────────────────────────────────
echo "[1/4] Preparing DMG contents..."
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy the app
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create a symlink to /Applications for drag-to-install
ln -s /Applications "$DMG_STAGING/Applications"

# Copy the uninstaller
cp "$SCRIPT_DIR/uninstall_steavium.sh" "$DMG_STAGING/Uninstall Steavium.command"
chmod +x "$DMG_STAGING/Uninstall Steavium.command"

# ── 3. Create the DMG ───────────────────────────────────────────────────────
echo "[2/4] Creating DMG image..."
rm -f "$DMG_PATH"

# Create a temporary writable DMG
TEMP_DMG="$BUILD_DIR/temp-steavium.dmg"
hdiutil create \
  -srcfolder "$DMG_STAGING" \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -fsargs "-c c=64,a=16,e=16" \
  -format UDRW \
  -size 200m \
  "$TEMP_DMG" \
  -quiet

# ── 4. Configure DMG appearance ─────────────────────────────────────────────
echo "[3/4] Configuring DMG appearance..."
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Detach if already mounted
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_POINT" -quiet

# Apply Finder view settings via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 640, 440}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set position of item "Steavium.app" of container window to {130, 160}
    set position of item "Applications" of container window to {410, 160}
    close
    open
    update without registering applications
  end tell
end tell
APPLESCRIPT

# Set volume icon if .icns exists
ICNS_SOURCE="$APP_BUNDLE/Contents/Resources/AppIcon.icns"
if [[ -f "$ICNS_SOURCE" ]]; then
  cp "$ICNS_SOURCE" "$MOUNT_POINT/.VolumeIcon.icns"
  SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
  SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
fi

# Give Finder time to finish
sync
sleep 2

hdiutil detach "$MOUNT_POINT" -quiet

# ── 5. Convert to compressed final DMG ──────────────────────────────────────
echo "[4/4] Compressing final DMG..."
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" -quiet
rm -f "$TEMP_DMG"
rm -rf "$DMG_STAGING"

# ── 6. Sign the DMG (if Developer ID is available) ──────────────────────────
if security find-identity -v -p codesigning | grep -q '"Developer ID Application'; then
  echo "[5/5] Signing DMG with Developer ID..."
  codesign --force --sign "Developer ID Application" --timestamp "$DMG_PATH"
  echo "    DMG signed."
else
  echo ""
  echo "NOTE: No Developer ID found — DMG is unsigned."
  echo "      Users who download this DMG may need to run:"
  echo "        xattr -cr /Applications/Steavium.app"
fi

echo ""
echo "DMG installer created: $DMG_PATH"
echo "Size: $(du -sh "$DMG_PATH" | cut -f1)"
echo ""
echo "Users can install by:"
echo "  1. Opening the DMG"
echo "  2. Dragging Steavium.app to the Applications folder"
echo ""
echo "To uninstall, users can:"
echo "  1. Run 'Uninstall Steavium.command' from the DMG, or"
echo "  2. Use the in-app uninstaller from Steavium menu"
