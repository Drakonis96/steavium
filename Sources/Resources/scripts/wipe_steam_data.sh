#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_dirs
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
      echo "Parametro no reconocido: $1"
      exit 1
      ;;
  esac
  shift
done

if [[ "$CLEAR_ACCOUNT" -eq 0 && "$CLEAR_LIBRARY" -eq 0 ]]; then
  echo "Debes indicar al menos una opcion: --account o --library"
  exit 1
fi

if is_crossover_mode; then
  cleanup_crossover_steam_processes
fi

STEAM_ROOT="$(resolve_steam_root || true)"
if [[ -z "${STEAM_ROOT:-}" ]]; then
  echo "No se encontro instalacion de Steam para limpiar datos."
  exit 1
fi

DRIVE_C_ROOT="${STEAM_ROOT%%/Program Files*}"

if [[ "$CLEAR_ACCOUNT" -eq 1 ]]; then
  echo "[1/2] Borrando datos de cuenta Steam..."

  rm -f "$STEAM_ROOT/config/loginusers.vdf" || true
  rm -f "$STEAM_ROOT/config/config.vdf" || true
  rm -f "$STEAM_ROOT/config/DialogConfig.vdf" || true
  rm -f "$STEAM_ROOT/config/shortcuts.vdf" || true
  rm -rf "$STEAM_ROOT/userdata" || true
  rm -rf "$STEAM_ROOT/config/avatarcache" || true
  rm -rf "$STEAM_ROOT/config/htmlcache" || true

  find "$STEAM_ROOT" -maxdepth 1 -name 'ssfn*' -type f -delete 2>/dev/null || true

  if [[ -d "$DRIVE_C_ROOT/users" ]]; then
    while IFS= read -r -d '' user_dir; do
      rm -rf "$user_dir/AppData/Local/Steam/htmlcache" || true
      rm -rf "$user_dir/AppData/Local/Steam/userdata" || true
      rm -rf "$user_dir/AppData/Roaming/Steam" || true
    done < <(find "$DRIVE_C_ROOT/users" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
fi

if [[ "$CLEAR_LIBRARY" -eq 1 ]]; then
  echo "[2/2] Borrando biblioteca de juegos y datos locales..."

  if [[ -d "$STEAM_ROOT/steamapps" ]]; then
    find "$STEAM_ROOT/steamapps" -mindepth 1 -maxdepth 1 \
      ! -name "libraryfolders.vdf" \
      ! -name "sourcemods" \
      -exec rm -rf {} +
  fi

  rm -rf "$STEAM_ROOT/steamapps/common" || true
  rm -rf "$STEAM_ROOT/steamapps/downloading" || true
  rm -rf "$STEAM_ROOT/steamapps/temp" || true
  rm -rf "$STEAM_ROOT/steamapps/workshop" || true
  rm -rf "$STEAM_ROOT/steamapps/shadercache" || true
  rm -rf "$STEAM_ROOT/steamapps/compatdata" || true
fi

repair_steam_library_layout

echo "Limpieza completada correctamente."
