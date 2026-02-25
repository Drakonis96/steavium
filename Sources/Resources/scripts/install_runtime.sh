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

WINE_MODE="${STEAVIUM_WINE_MODE:-auto}"
echo "[1/4] Preparando runtime (mode: $WINE_MODE)..."

install_wine_standalone() {
  echo "Instalando Wine (open-source) via Homebrew..."
  if ! brew tap | grep -q "^gcenx/wine$"; then
    brew tap gcenx/wine
  fi
  brew install --cask --no-quarantine wine-crossover
}

case "$WINE_MODE" in
  crossover)
    if [[ -x "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" ]]; then
      echo "CrossOver detectado. Se usara como runtime."
    else
      echo "CrossOver no detectado. Intentando instalar CrossOver."
      if ! brew list --cask crossover >/dev/null 2>&1; then
        brew install --cask crossover || true
      fi
      if [[ -x "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" ]]; then
        echo "CrossOver instalado correctamente."
      else
        echo "Error: No se pudo instalar CrossOver. Selecciona 'Auto' o 'Wine' en la UI."
        exit 1
      fi
    fi
    ;;
  wine)
    echo "Modo Wine seleccionado. Omitiendo CrossOver."
    if ! command -v wine64 >/dev/null 2>&1 && ! command -v wine >/dev/null 2>&1; then
      install_wine_standalone
    else
      echo "Wine ya esta instalado."
    fi
    ;;
  *)
    # Auto: prefer CrossOver if present, otherwise install standalone Wine
    if [[ -x "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine" ]]; then
      echo "CrossOver detectado. Se usara como runtime prioritario."
    else
      echo "CrossOver no detectado. Instalando Wine (open-source)..."
      install_wine_standalone
    fi
    ;;
esac

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
