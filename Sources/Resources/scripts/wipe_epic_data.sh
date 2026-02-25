#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
EPIC_PREFIX="$STEAVIUM_HOME/prefixes/epic"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_EPIC:-steavium-epic}"
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

# Kill any running Epic processes first
pkill -f "EpicGamesLauncher" >/dev/null 2>&1 || true
pkill -f "EpicWebHelper" >/dev/null 2>&1 || true
sleep 2

# Determine the drive_c root
resolve_epic_root() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Epic Games"
    "$EPIC_PREFIX/drive_c/Program Files (x86)/Epic Games"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

EPIC_ROOT="$(resolve_epic_root || true)"
if [[ -z "${EPIC_ROOT:-}" ]]; then
  echo "No Epic Games installation found to wipe data."
  exit 1
fi

DRIVE_C_ROOT="${EPIC_ROOT%%/Program Files*}"

if [[ "$CLEAR_ACCOUNT" -eq 1 ]]; then
  echo "[1/2] Removing Epic Games account data..."

  # Remove Epic launcher app data and caches
  if [[ -d "$DRIVE_C_ROOT/users" ]]; then
    while IFS= read -r -d '' user_dir; do
      rm -rf "$user_dir/AppData/Local/EpicGamesLauncher" || true
      rm -rf "$user_dir/AppData/Local/Epic Games" || true
      rm -rf "$user_dir/AppData/Local/UnrealEngine" || true
      rm -rf "$user_dir/AppData/Local/UnrealEngineLauncher" || true
      rm -rf "$user_dir/AppData/Roaming/Epic" || true
    done < <(find "$DRIVE_C_ROOT/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  # Remove launcher caches
  rm -rf "$EPIC_ROOT/Launcher/Portal/Saved" || true
  rm -rf "$EPIC_ROOT/Launcher/Portal/Intermediate" || true
fi

if [[ "$CLEAR_LIBRARY" -eq 1 ]]; then
  echo "[2/2] Removing game library and local game data..."

  # Remove common Epic game install locations (games are typically under Epic Games/)
  # Keep the Launcher itself but remove game directories
  if [[ -d "$EPIC_ROOT" ]]; then
    find "$EPIC_ROOT" -mindepth 1 -maxdepth 1 -type d ! -name "Launcher" -exec rm -rf {} + 2>/dev/null || true
  fi

  # Remove games from Program Files if installed there
  rm -rf "$DRIVE_C_ROOT/Program Files/Epic Games" || true
fi

echo "Epic Games data cleanup completed."
