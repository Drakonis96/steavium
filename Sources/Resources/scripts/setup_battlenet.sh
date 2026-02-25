#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
BATTLENET_PREFIX="$STEAVIUM_HOME/prefixes/battlenet"
BATTLENET_CACHE="$STEAVIUM_HOME/cache"
BATTLENET_LOGS="$STEAVIUM_HOME/logs"
BATTLENET_INSTALLER="$BATTLENET_CACHE/Battle.net-Setup.exe"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_BATTLENET:-steavium-battlenet}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_BATTLENET_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"

BATTLENET_EXE_PREFIX="$BATTLENET_PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"

INSTALLER_URL="https://downloader.battle.net/download/getInstallerForGame?os=win&gameProgram=BATTLENET_APP&version=LIVE"

ensure_battlenet_dirs() {
  mkdir -p "$STEAVIUM_HOME" "$BATTLENET_PREFIX" "$BATTLENET_CACHE" "$BATTLENET_LOGS"
}

ensure_battlenet_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if is_crossover_mode; then
  echo "[1/5] Preparing CrossOver bottle for Battle.net..."

  # Create a Battle.net-specific bottle
  CROSSOVER_BOTTLE_TEMPLATE="${STEAVIUM_CROSSOVER_TEMPLATE:-win10_64}"
  CROSSOVER_BOTTLE_TOOL="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle"
  CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

  if [[ ! -d "$CROSSOVER_BOTTLE_DIR" ]]; then
    "$CROSSOVER_BOTTLE_TOOL" --bottle "$CROSSOVER_BOTTLE_NAME" \
      --create --template "$CROSSOVER_BOTTLE_TEMPLATE"
  fi

  if [[ ! -f "$BATTLENET_INSTALLER" ]]; then
    echo "[2/5] Downloading Battle.net installer..."
    curl -fL --retry 3 --connect-timeout 15 \
      "$INSTALLER_URL" \
      -o "$BATTLENET_INSTALLER"
  else
    echo "[2/5] Reusing existing installer: $BATTLENET_INSTALLER"
  fi

  echo "[3/5] Running Battle.net installer (CrossOver)..."
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$BATTLENET_INSTALLER" --lang=enUS --installpath="C:\\Program Files (x86)\\Battle.net" \
    || "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$BATTLENET_INSTALLER"

  echo "[4/5] Waiting for installer to complete..."
  sleep 5

  echo "[5/5] Verifying installation..."
  if [[ ! -f "$CROSSOVER_BATTLENET_EXE" ]]; then
    # Try alternate path
    ALT_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
    if [[ ! -f "$ALT_EXE" ]]; then
      echo "Battle.net executable not found after installation in CrossOver."
      echo "The installer may run in the background. Try launching Battle.net after a few moments."
      exit 0
    fi
  fi
  echo "Battle.net installed successfully in CrossOver bottle: $CROSSOVER_BOTTLE_NAME"
  exit 0
fi

WINE_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE_BIN:-}" ]]; then
  echo "No compatible Wine runtime detected. Run Install Runtime first."
  exit 1
fi

export WINEPREFIX="$BATTLENET_PREFIX"
export WINEARCH=win64
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

echo "[1/5] Initializing Battle.net Wine prefix..."
"$WINE_BIN" wineboot -u

echo "[2/5] Skipping winetricks in fallback mode."

if [[ ! -f "$BATTLENET_INSTALLER" ]]; then
  echo "[3/5] Downloading Battle.net installer..."
  curl -fL --retry 3 --connect-timeout 15 \
    "$INSTALLER_URL" \
    -o "$BATTLENET_INSTALLER"
else
  echo "[3/5] Reusing existing installer: $BATTLENET_INSTALLER"
fi

echo "[4/5] Running Battle.net installer..."
"$WINE_BIN" "$BATTLENET_INSTALLER" --lang=enUS --installpath="C:\\Program Files (x86)\\Battle.net" \
  || "$WINE_BIN" "$BATTLENET_INSTALLER"

echo "[5/5] Waiting for installer and verifying..."
sleep 5

if [[ ! -f "$BATTLENET_EXE_PREFIX" ]]; then
  ALT_EXE="$BATTLENET_PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
  if [[ ! -f "$ALT_EXE" ]]; then
    echo "Battle.net executable not found inside prefix after installation."
    echo "The installer may run in the background. Try launching Battle.net after a few moments."
    exit 0
  fi
fi

echo "Battle.net installed successfully in: $BATTLENET_PREFIX"
