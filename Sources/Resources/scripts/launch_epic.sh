#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
EPIC_PREFIX="$STEAVIUM_HOME/prefixes/epic"
EPIC_LOGS="$STEAVIUM_HOME/logs"
EPIC_LIVE_LOG="$EPIC_LOGS/epic-live.log"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_EPIC:-steavium-epic}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

GRAPHICS_BACKEND="${STEAVIUM_GRAPHICS_BACKEND:-auto}"
IF_RUNNING="${STEAVIUM_IF_RUNNING:-reuse}"
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --backend)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for --backend (d3dmetal|dxvk|auto)"
        exit 1
      fi
      GRAPHICS_BACKEND="$2"
      shift 2
      ;;
    --if-running)
      if [[ -z "${2:-}" ]]; then
        echo "Missing value for --if-running (reuse|restart)"
        exit 1
      fi
      IF_RUNNING="$2"
      shift 2
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

mkdir -p "$EPIC_LOGS"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

resolve_epic_exe() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
    "$EPIC_PREFIX/drive_c/Program Files/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
    "$EPIC_PREFIX/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win64/EpicGamesLauncher.exe"
    "$EPIC_PREFIX/drive_c/Program Files (x86)/Epic Games/Launcher/Portal/Binaries/Win32/EpicGamesLauncher.exe"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

EPIC_EXE="$(resolve_epic_exe || true)"
if [[ -z "${EPIC_EXE:-}" ]]; then
  echo "Epic Games Launcher is not installed in the current environment."
  exit 1
fi

is_epic_running() {
  pgrep -f "EpicGamesLauncher" >/dev/null 2>&1
}

# Handle running policy
if is_epic_running; then
  case "$IF_RUNNING" in
    reuse)
      echo "[Epic] Epic Games Launcher is already running. Reusing existing session."
      exit 0
      ;;
    restart)
      echo "[Epic] Restarting Epic Games Launcher..."
      pkill -f "EpicGamesLauncher" >/dev/null 2>&1 || true
      pkill -f "EpicWebHelper" >/dev/null 2>&1 || true
      sleep 3
      ;;
    *)
      echo "[Epic] Epic Games Launcher is already running."
      exit 0
      ;;
  esac
fi

# Determine chip and hardware info from environment
DEVICE_CHIP_FAMILY="${STEAVIUM_DEVICE_CHIP_FAMILY:-unknown}"
DEVICE_RAM_GB="${STEAVIUM_DEVICE_RAM_GB:-0}"
PERFORMANCE_TIER="${STEAVIUM_PERFORMANCE_TIER:-balanced}"

echo "[hardware] Chip family: $DEVICE_CHIP_FAMILY | RAM: ${DEVICE_RAM_GB}GB | Tier: $PERFORMANCE_TIER" | tee -a "$EPIC_LIVE_LOG"
echo "[Epic] Graphics backend: $GRAPHICS_BACKEND" | tee -a "$EPIC_LIVE_LOG"

# Configure backend environment variables
case "$GRAPHICS_BACKEND" in
  d3dmetal)
    export ENABLE_D3DMETAL=1
    export DXVK_STATE_CACHE=0
    echo "[Epic] Using D3DMetal backend" | tee -a "$EPIC_LIVE_LOG"
    ;;
  dxvk)
    unset ENABLE_D3DMETAL 2>/dev/null || true
    export DXVK_STATE_CACHE=1
    export DXVK_LOG_LEVEL=none
    echo "[Epic] Using DXVK backend" | tee -a "$EPIC_LIVE_LOG"
    ;;
  auto|*)
    echo "[Epic] Using auto backend selection" | tee -a "$EPIC_LIVE_LOG"
    ;;
esac

echo "[Epic] Launching Epic Games Launcher..." | tee -a "$EPIC_LIVE_LOG"

if is_crossover_mode && [[ "$EPIC_EXE" == *"CrossOver"* ]]; then
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$EPIC_EXE" "${EXTRA_ARGS[@]}" >> "$EPIC_LIVE_LOG" 2>&1 &
else
  WINE_BIN="$(detect_wine64 || true)"
  if [[ -z "${WINE_BIN:-}" ]]; then
    echo "No compatible Wine runtime detected."
    exit 1
  fi

  export WINEPREFIX="$EPIC_PREFIX"
  export WINEARCH=win64
  export WINEESYNC="${WINEESYNC:-1}"
  export WINEFSYNC="${WINEFSYNC:-1}"
  export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

  "$WINE_BIN" "$EPIC_EXE" "${EXTRA_ARGS[@]}" >> "$EPIC_LIVE_LOG" 2>&1 &
fi

WINE_PID=$!
echo "[Epic] Epic Games Launcher started (PID: $WINE_PID)" | tee -a "$EPIC_LIVE_LOG"
echo "Epic Games Launcher launched successfully."
