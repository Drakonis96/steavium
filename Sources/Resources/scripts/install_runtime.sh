#!/usr/bin/env bash
set -euo pipefail

# Ensure Homebrew paths are available (GUI apps do not inherit shell PATH)
for p in /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /usr/local/sbin; do
  [[ -d "$p" ]] && [[ ":$PATH:" != *":$p:"* ]] && export PATH="$p:$PATH"
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_dirs

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew no detectado. Usa el boton 'Instalar Prerequisitos' primero."
  exit 1
fi

echo "[1/4] Preparando runtime..."
if [[ -x "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" ]]; then
  echo "CrossOver detectado. Se usara como runtime prioritario."
else
  echo "CrossOver no detectado. Intentando instalar CrossOver (trial)."
  if ! brew list --cask crossover >/dev/null 2>&1; then
    brew install --cask crossover || true
  fi

  if [[ -x "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" ]]; then
    echo "CrossOver instalado correctamente."
  else
    echo "No se pudo instalar CrossOver automaticamente. Usando fallback wine-crossover..."
    if ! brew tap | grep -q "^gcenx/wine$"; then
      brew tap gcenx/wine
    fi
    brew install --cask --no-quarantine wine-crossover
  fi
fi

echo "[2/4] Instalando utilidades para prefixes y multimedia..."
brew install winetricks cabextract samba ffmpeg \
  gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav >/dev/null || true

echo "[3/4] Verificando runtime..."
WINE64_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE64_BIN:-}" ]]; then
  echo "No se pudo encontrar wine64 tras la instalacion."
  exit 1
fi
"$WINE64_BIN" --version

echo "[4/4] Comprobando ntlm_auth..."
if ! command -v ntlm_auth >/dev/null 2>&1; then
  echo "Aviso: ntlm_auth no esta disponible. Algunos inicios de Steam pueden fallar."
else
  ntlm_auth --version | head -n 1 || true
fi

echo "Runtime instalado correctamente en: $WINE64_BIN"
