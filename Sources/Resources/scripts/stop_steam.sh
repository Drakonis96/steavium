#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

STEAM_EXE="$(resolve_steam_exe || true)"
if [[ -z "${STEAM_EXE:-}" ]]; then
  echo "Steam no esta instalado en el entorno actual."
  exit 0
fi

is_target_steam_running() {
  if is_crossover_mode; then
    is_crossover_steam_running
  else
    pgrep -f "$STEAM_EXE" >/dev/null 2>&1
  fi
}

wait_for_shutdown() {
  local max_seconds="${1:-10}"
  local elapsed=0
  while (( elapsed < max_seconds )); do
    if ! is_target_steam_running; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  return 1
}

request_graceful_shutdown() {
  if is_crossover_mode; then
    "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "$STEAM_EXE" -shutdown >/dev/null 2>&1 || true
    "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" wineboot -e >/dev/null 2>&1 || true
    return 0
  fi

  local wine_bin=""
  wine_bin="$(detect_wine64 || true)"
  if [[ -n "${wine_bin:-}" ]]; then
    WINEPREFIX="$STEAM_PREFIX" WINEARCH=win64 "$wine_bin" "$STEAM_EXE" -shutdown >/dev/null 2>&1 || true
    WINEPREFIX="$STEAM_PREFIX" WINEARCH=win64 "$wine_bin" wineboot -e >/dev/null 2>&1 || true
  fi
}

force_kill_steam_processes() {
  if is_crossover_mode; then
    cleanup_crossover_steam_processes
  else
    pkill -f "$STEAM_EXE" >/dev/null 2>&1 || true
    pkill -f "^C:\\\\Program Files( \\(x86\\))?\\\\Steam\\\\[sS]team\\.exe( |$)" >/dev/null 2>&1 || true
  fi

  pkill -f "steamwebhelper.exe" >/dev/null 2>&1 || true
  pkill -f "steamservice.exe" >/dev/null 2>&1 || true
  pkill -f "gameoverlayui.exe" >/dev/null 2>&1 || true
  pkill -f "steamerrorreporter.exe" >/dev/null 2>&1 || true
}

if is_target_steam_running; then
  echo "[steam] Cerrando Steam por completo..."
  request_graceful_shutdown
  if ! wait_for_shutdown 10; then
    echo "[steam] Steam sigue activo tras cierre ordenado. Forzando finalizacion."
  fi
else
  echo "[steam] Steam no estaba en ejecucion. Limpiando procesos residuales."
fi

force_kill_steam_processes

if is_target_steam_running; then
  echo "[steam] No fue posible cerrar todos los procesos de Steam."
  exit 1
fi

echo "[steam] Steam cerrado por completo."
