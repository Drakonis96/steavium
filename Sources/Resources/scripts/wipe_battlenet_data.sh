#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
BATTLENET_PREFIX="$STEAVIUM_HOME/prefixes/battlenet"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_BATTLENET:-steavium-battlenet}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

CLEAR_ACCOUNT=0
CLEAR_LIBRARY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --account)
      CLEAR_ACCOUNT=1
      ;;
    --library)
      CLEAR_LIBRARY=1
      ;;
    *)
      echo "Unrecognized parameter: $1"
      exit 1
      ;;
  esac
  shift
done

if [[ "$CLEAR_ACCOUNT" -eq 0 && "$CLEAR_LIBRARY" -eq 0 ]]; then
  echo "You must specify at least one option: --account or --library"
  exit 1
fi

# Kill any running Battle.net processes first
pkill -f "Battle.net" >/dev/null 2>&1 || true
pkill -f "Agent.exe" >/dev/null 2>&1 || true
sleep 2

# Determine the drive_c root
resolve_battlenet_root() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Battle.net"
    "$BATTLENET_PREFIX/drive_c/Program Files (x86)/Battle.net"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

BATTLENET_ROOT="$(resolve_battlenet_root || true)"
if [[ -z "${BATTLENET_ROOT:-}" ]]; then
  echo "No Battle.net installation found to wipe data."
  exit 1
fi

DRIVE_C_ROOT="${BATTLENET_ROOT%%/Program Files*}"

if [[ "$CLEAR_ACCOUNT" -eq 1 ]]; then
  echo "[1/2] Removing Battle.net account data..."

  # Remove Battle.net app data and caches
  if [[ -d "$DRIVE_C_ROOT/users" ]]; then
    while IFS= read -r -d '' user_dir; do
      rm -rf "$user_dir/AppData/Local/Battle.net" || true
      rm -rf "$user_dir/AppData/Local/Blizzard Entertainment" || true
      rm -rf "$user_dir/AppData/Local/Blizzard" || true
      rm -rf "$user_dir/AppData/Roaming/Battle.net" || true
      rm -rf "$user_dir/AppData/Roaming/Blizzard Entertainment" || true
    done < <(find "$DRIVE_C_ROOT/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  # Remove Battle.net config
  rm -rf "$BATTLENET_ROOT/Cache" || true
  rm -rf "$BATTLENET_ROOT/Logs" || true
  rm -rf "$BATTLENET_ROOT/CachedData" || true
fi

if [[ "$CLEAR_LIBRARY" -eq 1 ]]; then
  echo "[2/2] Removing game library and local game data..."

  # Remove common Blizzard game installation directories
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/Blizzard Entertainment" || true
  rm -rf "$DRIVE_C_ROOT/Program Files/Blizzard Entertainment" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/Overwatch" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/Diablo" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/World of Warcraft" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/Hearthstone" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/StarCraft" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/Heroes of the Storm" || true

  if [[ -d "$DRIVE_C_ROOT/users" ]]; then
    while IFS= read -r -d '' user_dir; do
      rm -rf "$user_dir/AppData/Local/Blizzard Entertainment" || true
    done < <(find "$DRIVE_C_ROOT/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
fi

echo "Wipe completed successfully."
