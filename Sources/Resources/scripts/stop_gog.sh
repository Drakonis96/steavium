#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
GOG_PREFIX="$STEAVIUM_HOME/prefixes/gog"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_GOG:-steavium-gog}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

is_gog_running() {
  pgrep -f "GalaxyClient" >/dev/null 2>&1
}

wait_for_shutdown() {
  local max_seconds="${1:-10}"
  local elapsed=0
  while (( elapsed < max_seconds )); do
    if ! is_gog_running; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

force_kill_gog() {
  pkill -f "GalaxyClient" >/dev/null 2>&1 || true
  pkill -f "GalaxyCommunication" >/dev/null 2>&1 || true
  pkill -f "GOG Galaxy" >/dev/null 2>&1 || true
  pkill -f "GalaxyPeer" >/dev/null 2>&1 || true
}

if is_gog_running; then
  echo "[GOG] Closing GOG Galaxy..."

  # Try graceful shutdown via Wine
  if is_crossover_mode; then
    "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" wineboot -e >/dev/null 2>&1 || true
  else
    WINE_BIN="$(detect_wine64 || true)"
    if [[ -n "${WINE_BIN:-}" ]]; then
      WINEPREFIX="$GOG_PREFIX" WINEARCH=win64 "$WINE_BIN" wineboot -e >/dev/null 2>&1 || true
    fi
  fi

  if ! wait_for_shutdown 10; then
    echo "[GOG] GOG Galaxy still active after graceful shutdown. Forcing termination."
  fi
else
  echo "[GOG] GOG Galaxy was not running. Cleaning up residual processes."
fi

force_kill_gog

if is_gog_running; then
  echo "[GOG] Could not close all GOG Galaxy processes."
  exit 1
fi

echo "[GOG] GOG Galaxy closed completely."
