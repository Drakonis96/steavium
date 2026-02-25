#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
GOG_PREFIX="$STEAVIUM_HOME/prefixes/gog"
GOG_LOGS="$STEAVIUM_HOME/logs"
GOG_LIVE_LOG="$GOG_LOGS/gog-live.log"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_GOG:-steavium-gog}"
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

mkdir -p "$GOG_LOGS"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

resolve_gog_exe() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"
    "$GOG_PREFIX/drive_c/Program Files (x86)/GOG Galaxy/GalaxyClient.exe"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

GOG_EXE="$(resolve_gog_exe || true)"
if [[ -z "${GOG_EXE:-}" ]]; then
  echo "GOG Galaxy is not installed in the current environment."
  exit 1
fi

is_gog_running() {
  pgrep -f "GalaxyClient" >/dev/null 2>&1
}

# Handle running policy
if is_gog_running; then
  case "$IF_RUNNING" in
    reuse)
      echo "[GOG] GOG Galaxy is already running. Reusing existing session."
      exit 0
      ;;
    restart)
      echo "[GOG] Restarting GOG Galaxy..."
      pkill -f "GalaxyClient" >/dev/null 2>&1 || true
      pkill -f "GalaxyCommunication" >/dev/null 2>&1 || true
      sleep 3
      ;;
    *)
      echo "[GOG] GOG Galaxy is already running."
      exit 0
      ;;
  esac
fi

# Determine chip and hardware info from environment
DEVICE_CHIP_FAMILY="${STEAVIUM_DEVICE_CHIP_FAMILY:-unknown}"
DEVICE_RAM_GB="${STEAVIUM_DEVICE_RAM_GB:-0}"
PERFORMANCE_TIER="${STEAVIUM_PERFORMANCE_TIER:-balanced}"

echo "[hardware] Chip family: $DEVICE_CHIP_FAMILY | RAM: ${DEVICE_RAM_GB}GB | Tier: $PERFORMANCE_TIER" | tee -a "$GOG_LIVE_LOG"
echo "[GOG] Graphics backend: $GRAPHICS_BACKEND" | tee -a "$GOG_LIVE_LOG"

# Configure backend environment variables
case "$GRAPHICS_BACKEND" in
  d3dmetal)
    export ENABLE_D3DMETAL=1
    export DXVK_STATE_CACHE=0
    echo "[GOG] Using D3DMetal backend" | tee -a "$GOG_LIVE_LOG"
    ;;
  dxvk)
    unset ENABLE_D3DMETAL 2>/dev/null || true
    export DXVK_STATE_CACHE=1
    export DXVK_LOG_LEVEL=none
    echo "[GOG] Using DXVK backend" | tee -a "$GOG_LIVE_LOG"
    ;;
  auto|*)
    echo "[GOG] Using auto backend selection" | tee -a "$GOG_LIVE_LOG"
    ;;
esac

echo "[GOG] Launching GOG Galaxy..." | tee -a "$GOG_LIVE_LOG"

if is_crossover_mode && [[ "$GOG_EXE" == *"CrossOver"* ]]; then
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$GOG_EXE" "${EXTRA_ARGS[@]}" >> "$GOG_LIVE_LOG" 2>&1 &
else
  WINE_BIN="$(detect_wine64 || true)"
  if [[ -z "${WINE_BIN:-}" ]]; then
    echo "No compatible Wine runtime detected."
    exit 1
  fi

  export WINEPREFIX="$GOG_PREFIX"
  export WINEARCH=win64
  export WINEESYNC="${WINEESYNC:-1}"
  export WINEFSYNC="${WINEFSYNC:-1}"
  export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

  "$WINE_BIN" "$GOG_EXE" "${EXTRA_ARGS[@]}" >> "$GOG_LIVE_LOG" 2>&1 &
fi

WINE_PID=$!
echo "[GOG] GOG Galaxy started (PID: $WINE_PID)" | tee -a "$GOG_LIVE_LOG"
echo "GOG Galaxy launched successfully."
