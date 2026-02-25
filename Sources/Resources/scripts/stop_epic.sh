#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
EPIC_PREFIX="$STEAVIUM_HOME/prefixes/epic"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_EPIC:-steavium-epic}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

is_epic_running() {
  pgrep -f "EpicGamesLauncher" >/dev/null 2>&1
}

wait_for_shutdown() {
  local max_seconds="${1:-10}"
  local elapsed=0
  while (( elapsed < max_seconds )); do
    if ! is_epic_running; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

force_kill_epic() {
  pkill -f "EpicGamesLauncher" >/dev/null 2>&1 || true
  pkill -f "EpicWebHelper" >/dev/null 2>&1 || true
  pkill -f "EpicGames" >/dev/null 2>&1 || true
  pkill -f "UnrealEngineLauncher" >/dev/null 2>&1 || true
}

if is_epic_running; then
  echo "[Epic] Closing Epic Games Launcher..."

  # Try graceful shutdown via Wine
  if is_crossover_mode; then
    "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" wineboot -e >/dev/null 2>&1 || true
  else
    WINE_BIN="$(detect_wine64 || true)"
    if [[ -n "${WINE_BIN:-}" ]]; then
      WINEPREFIX="$EPIC_PREFIX" WINEARCH=win64 "$WINE_BIN" wineboot -e >/dev/null 2>&1 || true
    fi
  fi

  if ! wait_for_shutdown 10; then
    echo "[Epic] Epic Games Launcher still active after graceful shutdown. Forcing termination."
  fi
else
  echo "[Epic] Epic Games Launcher was not running. Cleaning up residual processes."
fi

force_kill_epic

if is_epic_running; then
  echo "[Epic] Could not close all Epic Games processes."
  exit 1
fi

echo "[Epic] Epic Games Launcher closed completely."
