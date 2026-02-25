#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
EPIC_PREFIX="$STEAVIUM_HOME/prefixes/epic"
EPIC_CACHE="$STEAVIUM_HOME/cache"
EPIC_LOGS="$STEAVIUM_HOME/logs"
EPIC_INSTALLER="$EPIC_CACHE/EpicInstaller.msi"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_EPIC:-steavium-epic}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_EPIC_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"

EPIC_EXE_PREFIX="$EPIC_PREFIX/drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"

INSTALLER_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncherInstaller.msi"

ensure_epic_dirs() {
  mkdir -p "$STEAVIUM_HOME" "$EPIC_PREFIX" "$EPIC_CACHE" "$EPIC_LOGS"
}

ensure_epic_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if is_crossover_mode; then
  echo "[1/5] Preparing CrossOver bottle for Epic Games Store..."

  CROSSOVER_BOTTLE_TEMPLATE="${STEAVIUM_CROSSOVER_TEMPLATE:-win10_64}"
  CROSSOVER_BOTTLE_TOOL="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle"
  CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

  if [[ ! -d "$CROSSOVER_BOTTLE_DIR" ]]; then
    "$CROSSOVER_BOTTLE_TOOL" --bottle "$CROSSOVER_BOTTLE_NAME" \
      --create --template "$CROSSOVER_BOTTLE_TEMPLATE"
  fi

  if [[ ! -f "$EPIC_INSTALLER" ]]; then
    echo "[2/5] Downloading Epic Games Launcher installer..."
    curl -fL --retry 3 --connect-timeout 15 \
      "$INSTALLER_URL" \
      -o "$EPIC_INSTALLER"
  else
    echo "[2/5] Reusing existing installer: $EPIC_INSTALLER"
  fi

  echo "[3/5] Running Epic Games installer (CrossOver)..."
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" msiexec /i "$EPIC_INSTALLER" /quiet \
    || "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" msiexec /i "$EPIC_INSTALLER"

  echo "[4/5] Waiting for installer to complete..."
  sleep 5

  echo "[5/5] Verifying installation..."
  if [[ ! -f "$CROSSOVER_EPIC_EXE" ]]; then
    ALT_EXE="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
    ALT_EXE2="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
    if [[ ! -f "$ALT_EXE" ]] && [[ ! -f "${ALT_EXE2:-}" ]]; then
      echo "Epic Games Launcher executable not found after installation in CrossOver."
      echo "The installer may run in the background. Try launching after a few moments."
      exit 0
    fi
  fi
  echo "Epic Games Launcher installed successfully in CrossOver bottle: $CROSSOVER_BOTTLE_NAME"
  exit 0
fi

WINE_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE_BIN:-}" ]]; then
  echo "No compatible Wine runtime detected. Run Install Runtime first."
  exit 1
fi

export WINEPREFIX="$EPIC_PREFIX"
export WINEARCH=win64
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

echo "[1/5] Initializing Epic Games Wine prefix..."
"$WINE_BIN" wineboot -u

echo "[2/5] Skipping winetricks in fallback mode."

if [[ ! -f "$EPIC_INSTALLER" ]]; then
  echo "[3/5] Downloading Epic Games Launcher installer..."
  curl -fL --retry 3 --connect-timeout 15 \
    "$INSTALLER_URL" \
    -o "$EPIC_INSTALLER"
else
  echo "[3/5] Reusing existing installer: $EPIC_INSTALLER"
fi

echo "[4/5] Running Epic Games Launcher installer..."
"$WINE_BIN" msiexec /i "$EPIC_INSTALLER" /quiet \
  || "$WINE_BIN" msiexec /i "$EPIC_INSTALLER"

echo "[5/5] Waiting for installer and verifying..."
sleep 5

if [[ ! -f "$EPIC_EXE_PREFIX" ]]; then
  ALT_EXE="$EPIC_PREFIX/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
  ALT_EXE2="$EPIC_PREFIX/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
  if [[ ! -f "$ALT_EXE" ]] && [[ ! -f "${ALT_EXE2:-}" ]]; then
    echo "Epic Games Launcher executable not found inside prefix after installation."
    echo "The installer may run in the background. Try launching after a few moments."
    exit 0
  fi
fi

echo "Epic Games Launcher installed successfully in: $EPIC_PREFIX"
