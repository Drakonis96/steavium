#!/usr/bin/env bash
# ============================================================================
# install_prerequisites.sh — Installs Homebrew and Xcode CLT automatically
# ============================================================================
set -euo pipefail

echo "[1/3] Checking Xcode Command Line Tools..."
if xcode-select -p &>/dev/null; then
  echo "Xcode Command Line Tools already installed."
else
  echo "Xcode Command Line Tools not found. Requesting installation..."
  # Trigger the macOS GUI installer for Xcode CLT
  xcode-select --install 2>/dev/null || true
  echo "Waiting for Xcode Command Line Tools installation..."
  # Poll until installed (the GUI dialog runs separately)
  WAIT_SECONDS=0
  MAX_WAIT=600
  while ! xcode-select -p &>/dev/null; do
    sleep 5
    WAIT_SECONDS=$((WAIT_SECONDS + 5))
    if [[ $WAIT_SECONDS -ge $MAX_WAIT ]]; then
      echo "Timed out waiting for Xcode Command Line Tools. Please install them manually and retry."
      exit 1
    fi
  done
  echo "Xcode Command Line Tools installed."
fi

echo "[2/3] Checking Homebrew..."
BREW_BIN=""
if [[ -x /opt/homebrew/bin/brew ]]; then
  BREW_BIN="/opt/homebrew/bin/brew"
elif [[ -x /usr/local/bin/brew ]]; then
  BREW_BIN="/usr/local/bin/brew"
fi

if [[ -n "$BREW_BIN" ]]; then
  echo "Homebrew already installed at: $BREW_BIN"
else
  echo "Homebrew not found. Installing..."
  # Download the official Homebrew installer
  INSTALLER_SCRIPT="$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Run non-interactively; on Apple Silicon this may need admin for /opt/homebrew.
  # We try using osascript to get native macOS admin prompt first.
  TMPSCRIPT="$(mktemp /tmp/brew_install.XXXXXX.sh)"
  cat > "$TMPSCRIPT" << 'INNEREOF'
#!/bin/bash
set -e
export NONINTERACTIVE=1
export CI=1
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
INNEREOF
  chmod +x "$TMPSCRIPT"

  if osascript -e "do shell script \"$TMPSCRIPT\" with administrator privileges" 2>&1; then
    echo "Homebrew installed with admin privileges."
  else
    echo "Admin install failed. Trying without elevated privileges..."
    NONINTERACTIVE=1 CI=1 /bin/bash -c "$INSTALLER_SCRIPT" 2>&1 || {
      echo "Homebrew installation failed. Please install it manually from https://brew.sh"
      rm -f "$TMPSCRIPT"
      exit 1
    }
  fi
  rm -f "$TMPSCRIPT"

  # Verify installation
  if [[ -x /opt/homebrew/bin/brew ]]; then
    BREW_BIN="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    BREW_BIN="/usr/local/bin/brew"
  fi

  if [[ -z "$BREW_BIN" ]]; then
    echo "Homebrew installation could not be verified."
    exit 1
  fi

  echo "Homebrew installed at: $BREW_BIN"
fi

echo "[3/3] Verifying prerequisites..."
# Quick brew sanity check
"$BREW_BIN" --version | head -n 1

echo "All prerequisites installed successfully."
