#!/usr/bin/env bash
# ============================================================================
# uninstall_steavium.sh — Completely removes Steavium from the system
# ============================================================================
set -euo pipefail

APP_PATH="/Applications/Steavium.app"
APP_SUPPORT="$HOME/Library/Application Support/Steavium"
USER_DEFAULTS_DOMAIN="com.steavium.app"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║            Steavium Uninstaller                         ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Check what exists ────────────────────────────────────────────────────────
FOUND_SOMETHING=0

if [[ -d "$APP_PATH" ]]; then
  FOUND_SOMETHING=1
  echo "  [✓] Found: $APP_PATH"
fi

if [[ -d "$APP_SUPPORT" ]]; then
  FOUND_SOMETHING=1
  echo "  [✓] Found: $APP_SUPPORT"
fi

# Check for UserDefaults
if defaults read "$USER_DEFAULTS_DOMAIN" >/dev/null 2>&1; then
  FOUND_SOMETHING=1
  echo "  [✓] Found: UserDefaults ($USER_DEFAULTS_DOMAIN)"
fi

if [[ "$FOUND_SOMETHING" -eq 0 ]]; then
  echo "  Steavium is not installed on this system."
  echo ""
  exit 0
fi

echo ""
echo "  This will remove:"
echo "    • Steavium.app from /Applications"
echo "    • App data from ~/Library/Application Support/Steavium"
echo "    • User preferences"
echo ""
echo "  NOTE: Your game library folder (if you set a custom path)"
echo "  will NOT be deleted. Your games are safe."
echo ""

read -rp "  Proceed with uninstallation? [y/N] " confirm
if [[ "${confirm,,}" != "y" && "${confirm,,}" != "yes" ]]; then
  echo ""
  echo "  Uninstallation canceled."
  echo ""
  exit 0
fi

echo ""

# ── Remove the app ───────────────────────────────────────────────────────────
if [[ -d "$APP_PATH" ]]; then
  echo "  Removing $APP_PATH..."
  rm -rf "$APP_PATH"
  echo "    Done."
fi

# ── Remove app support data ─────────────────────────────────────────────────
if [[ -d "$APP_SUPPORT" ]]; then
  echo "  Removing $APP_SUPPORT..."

  # Before removing, show what game library path was configured (if any)
  GAME_LIB_PATH=""
  GAME_LIB_PATH="$(defaults read "$USER_DEFAULTS_DOMAIN" "steavium.game_library_path" 2>/dev/null || true)"
  if [[ -n "$GAME_LIB_PATH" ]]; then
    echo ""
    echo "  Your custom game library was at:"
    echo "    $GAME_LIB_PATH"
    echo "  This folder has NOT been deleted."
    echo ""
  fi

  rm -rf "$APP_SUPPORT"
  echo "    Done."
fi

# ── Remove UserDefaults ─────────────────────────────────────────────────────
if defaults read "$USER_DEFAULTS_DOMAIN" >/dev/null 2>&1; then
  echo "  Removing user preferences..."
  defaults delete "$USER_DEFAULTS_DOMAIN" 2>/dev/null || true
  echo "    Done."
fi

# ── Remove saved state ──────────────────────────────────────────────────────
SAVED_STATE="$HOME/Library/Saved Application State/com.steavium.app.savedState"
if [[ -d "$SAVED_STATE" ]]; then
  echo "  Removing saved application state..."
  rm -rf "$SAVED_STATE"
  echo "    Done."
fi

# ── Remove caches ────────────────────────────────────────────────────────────
CACHES_DIR="$HOME/Library/Caches/com.steavium.app"
if [[ -d "$CACHES_DIR" ]]; then
  echo "  Removing caches..."
  rm -rf "$CACHES_DIR"
  echo "    Done."
fi

echo ""
echo "  Steavium has been completely uninstalled."
echo ""
echo "  If you had a CrossOver bottle for Steam, it remains at:"
echo "    ~/Library/Application Support/CrossOver/Bottles/steavium-steam"
echo "  Remove it manually if you no longer need it."
echo ""
