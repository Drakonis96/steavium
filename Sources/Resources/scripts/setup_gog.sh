#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
GOG_PREFIX="$STEAVIUM_HOME/prefixes/gog"
GOG_CACHE="$STEAVIUM_HOME/cache"
GOG_LOGS="$STEAVIUM_HOME/logs"
GOG_INSTALLER="$GOG_CACHE/setup_galaxy.exe"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_GOG:-steavium-gog}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_GOG_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"

GOG_EXE_PREFIX="$GOG_PREFIX/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"

INSTALLER_URL="https://webinstallers.gog-statics.com/download/GOG_Galaxy_2.0.exe"

ensure_gog_dirs() {
  mkdir -p "$STEAVIUM_HOME" "$GOG_PREFIX" "$GOG_CACHE" "$GOG_LOGS"
}

ensure_gog_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if is_crossover_mode; then
  echo "[1/5] Preparing CrossOver bottle for GOG Galaxy..."

  CROSSOVER_BOTTLE_TEMPLATE="${STEAVIUM_CROSSOVER_TEMPLATE:-win10_64}"
  CROSSOVER_BOTTLE_TOOL="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle"
  CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

  if [[ ! -d "$CROSSOVER_BOTTLE_DIR" ]]; then
    "$CROSSOVER_BOTTLE_TOOL" --bottle "$CROSSOVER_BOTTLE_NAME" \
      --create --template "$CROSSOVER_BOTTLE_TEMPLATE"
  fi

  if [[ ! -f "$GOG_INSTALLER" ]]; then
    echo "[2/5] Downloading GOG Galaxy installer..."
    curl -fL --retry 3 --connect-timeout 15 \
      "$INSTALLER_URL" \
      -o "$GOG_INSTALLER"
  else
    echo "[2/5] Reusing existing installer: $GOG_INSTALLER"
  fi

  echo "[3/5] Running GOG Galaxy installer (CrossOver)..."
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$GOG_INSTALLER" /VERYSILENT /NORESTART \
    || "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$GOG_INSTALLER"

  echo "[4/5] Waiting for installer to complete..."
  sleep 5

  echo "[5/5] Verifying installation..."
  if [[ ! -f "$CROSSOVER_GOG_EXE" ]]; then
    ALT_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"
    if [[ ! -f "$ALT_EXE" ]]; then
      echo "GOG Galaxy executable not found after installation in CrossOver."
      echo "The installer may run in the background. Try launching after a few moments."
      exit 0
    fi
  fi
  echo "GOG Galaxy installed successfully in CrossOver bottle: $CROSSOVER_BOTTLE_NAME"
  exit 0
fi

WINE_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE_BIN:-}" ]]; then
  echo "No compatible Wine runtime detected. Run Install Runtime first."
  exit 1
fi

export WINEPREFIX="$GOG_PREFIX"
export WINEARCH=win64
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

echo "[1/5] Initializing GOG Galaxy Wine prefix..."
"$WINE_BIN" wineboot -u

echo "[2/5] Skipping winetricks in fallback mode."

if [[ ! -f "$GOG_INSTALLER" ]]; then
  echo "[3/5] Downloading GOG Galaxy installer..."
  curl -fL --retry 3 --connect-timeout 15 \
    "$INSTALLER_URL" \
    -o "$GOG_INSTALLER"
else
  echo "[3/5] Reusing existing installer: $GOG_INSTALLER"
fi

echo "[4/5] Running GOG Galaxy installer..."
"$WINE_BIN" "$GOG_INSTALLER" /VERYSILENT /NORESTART \
  || "$WINE_BIN" "$GOG_INSTALLER"

echo "[5/5] Waiting for installer and verifying..."
sleep 5

if [[ ! -f "$GOG_EXE_PREFIX" ]]; then
  ALT_EXE="$GOG_PREFIX/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"
  if [[ ! -f "$ALT_EXE" ]]; then
    echo "GOG Galaxy executable not found inside prefix after installation."
    echo "The installer may run in the background. Try launching after a few moments."
    exit 0
  fi
fi

echo "GOG Galaxy installed successfully in: $GOG_PREFIX"
