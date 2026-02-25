#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if is_crossover_mode; then
  echo "[1/6] Preparando bottle CrossOver..."
  ensure_crossover_bottle

  echo "[2/6] Limpiando procesos Steam previos del bottle..."
  cleanup_crossover_steam_processes

  if [[ ! -f "$STEAM_INSTALLER" ]]; then
    echo "[3/6] Descargando SteamSetup.exe..."
    curl -fL --retry 3 --connect-timeout 15 \
      "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" \
      -o "$STEAM_INSTALLER"
  else
    echo "[3/6] Reutilizando instalador existente: $STEAM_INSTALLER"
  fi

  echo "[4/6] Ejecutando instalador de Steam (CrossOver)..."
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$STEAM_INSTALLER" /S \
    || "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$STEAM_INSTALLER"

  echo "[5/6] Reparando layout de libreria..."
  repair_steam_library_layout

  echo "[6/6] Verificando instalacion..."
  STEAM_EXE="$(resolve_steam_exe || true)"
  if [[ -z "${STEAM_EXE:-}" ]]; then
    echo "No se encontro steam.exe tras la instalacion en CrossOver."
    exit 1
  fi
  echo "Steam preparado correctamente en bottle CrossOver: $CROSSOVER_BOTTLE_NAME"
  exit 0
fi

WINE_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE_BIN:-}" ]]; then
  echo "No se detecto runtime Wine compatible. Ejecuta primero la instalacion de runtime."
  exit 1
fi

export WINEPREFIX="$STEAM_PREFIX"
export WINEARCH=win64
export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export WINEDLLOVERRIDES="mscoree=d;mshtml=d"

echo "[1/6] Inicializando prefix de Steam..."
"$WINE_BIN" wineboot -u

echo "[2/6] Saltando winetricks en modo fallback para evitar configuraciones inestables."

if [[ ! -f "$STEAM_INSTALLER" ]]; then
  echo "[3/6] Descargando SteamSetup.exe..."
  curl -fL --retry 3 --connect-timeout 15 \
    "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" \
    -o "$STEAM_INSTALLER"
else
  echo "[3/6] Reutilizando instalador existente: $STEAM_INSTALLER"
fi

echo "[4/6] Ejecutando instalador de Steam..."
"$WINE_BIN" "$STEAM_INSTALLER" /S || "$WINE_BIN" "$STEAM_INSTALLER"

echo "[5/6] Reparando layout de libreria..."
repair_steam_library_layout

echo "[6/6] Verificando instalacion..."
STEAM_EXE="$(resolve_steam_exe || true)"
if [[ -z "${STEAM_EXE:-}" ]]; then
  echo "No se encontro steam.exe dentro del prefix."
  exit 1
fi

echo "Steam preparado correctamente en: $STEAM_EXE"
