#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
GOG_PREFIX="$STEAVIUM_HOME/prefixes/gog"

CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE_GOG:-steavium-gog}"
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

# Kill any running GOG processes first
pkill -f "GalaxyClient" >/dev/null 2>&1 || true
pkill -f "GalaxyCommunication" >/dev/null 2>&1 || true
sleep 2

# Determine the drive_c root
resolve_gog_root() {
  local candidates=(
    "$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/GOG Galaxy"
    "$GOG_PREFIX/drive_c/Program Files (x86)/GOG Galaxy"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

GOG_ROOT="$(resolve_gog_root || true)"
if [[ -z "${GOG_ROOT:-}" ]]; then
  echo "No GOG Galaxy installation found to wipe data."
  exit 1
fi

DRIVE_C_ROOT="${GOG_ROOT%%/Program Files*}"

if [[ "$CLEAR_ACCOUNT" -eq 1 ]]; then
  echo "[1/2] Removing GOG Galaxy account data..."

  # Remove GOG app data and caches
  if [[ -d "$DRIVE_C_ROOT/users" ]]; then
    while IFS= read -r -d '' user_dir; do
      rm -rf "$user_dir/AppData/Local/GOG.com" || true
      rm -rf "$user_dir/AppData/Local/GOG Galaxy" || true
      rm -rf "$user_dir/AppData/Roaming/GOG.com" || true
    done < <(find "$DRIVE_C_ROOT/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  # Remove GOG Galaxy config/cache
  rm -rf "$GOG_ROOT/webcache" || true
  rm -rf "$GOG_ROOT/logs" || true
  rm -rf "$GOG_ROOT/Storage" || true
fi

if [[ "$CLEAR_LIBRARY" -eq 1 ]]; then
  echo "[2/2] Removing game library and local game data..."

  # Remove common GOG game installation directories
  rm -rf "$DRIVE_C_ROOT/GOG Games" || true
  rm -rf "$DRIVE_C_ROOT/Program Files/GOG.com" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/GOG.com" || true
  rm -rf "$DRIVE_C_ROOT/Program Files/GOG Games" || true
  rm -rf "$DRIVE_C_ROOT/Program Files (x86)/GOG Games" || true
fi

echo "GOG Galaxy data cleanup completed."
