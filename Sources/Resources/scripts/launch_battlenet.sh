#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
BATTLENET_PREFIX="$STEAVIUM_HOME/prefixes/battlenet"
BATTLENET_LOGS="$STEAVIUM_HOME/logs"
BATTLENET_LIVE_LOG="$BATTLENET_LOGS/battlenet-live.log"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_BATTLENET:-steavium-battlenet}"
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

mkdir -p "$BATTLENET_LOGS"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

resolve_battlenet_exe() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
    "$BATTLENET_PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
    "$BATTLENET_PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

BATTLENET_EXE="$(resolve_battlenet_exe || true)"
if [[ -z "${BATTLENET_EXE:-}" ]]; then
  echo "Battle.net is not installed in the current environment."
  exit 1
fi

is_battlenet_running() {
  pgrep -f "Battle.net" >/dev/null 2>&1
}

# Handle running policy
if is_battlenet_running; then
  case "$IF_RUNNING" in
    reuse)
      echo "[Battle.net] Battle.net is already running. Reusing existing session."
      exit 0
      ;;
    restart)
      echo "[Battle.net] Restarting Battle.net..."
      pkill -f "Battle.net" >/dev/null 2>&1 || true
      sleep 3
      ;;
    *)
      echo "[Battle.net] Battle.net is already running."
      exit 0
      ;;
  esac
fi

# Determine chip and hardware info from environment
DEVICE_CHIP_FAMILY="${STEAVIUM_DEVICE_CHIP_FAMILY:-unknown}"
DEVICE_RAM_GB="${STEAVIUM_DEVICE_RAM_GB:-0}"
PERFORMANCE_TIER="${STEAVIUM_PERFORMANCE_TIER:-balanced}"

echo "[hardware] Chip family: $DEVICE_CHIP_FAMILY | RAM: ${DEVICE_RAM_GB}GB | Tier: $PERFORMANCE_TIER" | tee -a "$BATTLENET_LIVE_LOG"
echo "[Battle.net] Graphics backend: $GRAPHICS_BACKEND" | tee -a "$BATTLENET_LIVE_LOG"

# Configure backend environment variables
case "$GRAPHICS_BACKEND" in
  d3dmetal)
    export ENABLE_D3DMETAL=1
    export DXVK_STATE_CACHE=0
    echo "[Battle.net] Using D3DMetal backend" | tee -a "$BATTLENET_LIVE_LOG"
    ;;
  dxvk)
    unset ENABLE_D3DMETAL 2>/dev/null || true
    export DXVK_STATE_CACHE=1
    export DXVK_LOG_LEVEL=none
    echo "[Battle.net] Using DXVK backend" | tee -a "$BATTLENET_LIVE_LOG"
    ;;
  auto|*)
    # Let the system decide
    echo "[Battle.net] Using auto backend selection" | tee -a "$BATTLENET_LIVE_LOG"
    ;;
esac

echo "[Battle.net] Launching Battle.net..." | tee -a "$BATTLENET_LIVE_LOG"

if is_crossover_mode && [[ "$BATTLENET_EXE" == *"CrossOver"* ]]; then
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$BATTLENET_EXE" "${EXTRA_ARGS[@]}" >> "$BATTLENET_LIVE_LOG" 2>&1 &
else
  WINE_BIN="$(detect_wine64 || true)"
  if [[ -z "${WINE_BIN:-}" ]]; then
    echo "No compatible Wine runtime detected."
    exit 1
  fi

  export WINEPREFIX="$BATTLENET_PREFIX"
  export WINEARCH=win64
  export WINEESYNC="${WINEESYNC:-1}"
  export WINEFSYNC="${WINEFSYNC:-1}"
  export WINEMSYNC="${WINEMSYNC:-1}"
  export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

  "$WINE_BIN" "$BATTLENET_EXE" "${EXTRA_ARGS[@]}" >> "$BATTLENET_LIVE_LOG" 2>&1 &
fi

echo "[Battle.net] Battle.net launched. Log: $BATTLENET_LIVE_LOG" | tee -a "$BATTLENET_LIVE_LOG"
