#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

ensure_dirs
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

DETACHED=0
GRAPHICS_BACKEND="${STEAVIUM_GRAPHICS_BACKEND:-auto}"
IF_RUNNING="${STEAVIUM_IF_RUNNING:-reuse}"
MEDIA_COMPAT_ONLY=0
MEDIA_COMPAT_DRY_RUN="${STEAVIUM_MEDIA_COMPAT_DRY_RUN:-0}"
WORKER_MODE="${STEAVIUM_LAUNCH_WORKER_MODE:-0}"
EXTRA_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --detached)
      DETACHED=1
      shift
      ;;
    --backend)
      if [[ -z "${2:-}" ]]; then
        echo "Falta valor para --backend (d3dmetal|dxvk|auto)"
        exit 1
      fi
      GRAPHICS_BACKEND="$2"
      shift 2
      ;;
    --if-running)
      if [[ -z "${2:-}" ]]; then
        echo "Falta valor para --if-running (reuse|restart)"
        exit 1
      fi
      IF_RUNNING="$2"
      shift 2
      ;;
    --media-compat-only)
      MEDIA_COMPAT_ONLY=1
      shift
      ;;
    --media-dry-run)
      MEDIA_COMPAT_DRY_RUN=1
      shift
      ;;
    --worker-mode)
      WORKER_MODE=1
      shift
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

DEVICE_CHIP_MODEL="${STEAVIUM_DEVICE_CHIP_MODEL:-}"
if [[ -z "$DEVICE_CHIP_MODEL" ]]; then
  DEVICE_CHIP_MODEL="$(/usr/sbin/sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
fi
if [[ -z "$DEVICE_CHIP_MODEL" ]]; then
  DEVICE_CHIP_MODEL="Desconocido"
fi

DEVICE_CHIP_FAMILY="${STEAVIUM_DEVICE_CHIP_FAMILY:-unknown}"
DEVICE_RAM_GB="${STEAVIUM_DEVICE_RAM_GB:-0}"
if ! [[ "$DEVICE_RAM_GB" =~ ^[0-9]+$ ]]; then
  DEVICE_RAM_GB=0
fi
if [[ "$DEVICE_RAM_GB" -eq 0 ]]; then
  RAM_BYTES="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || echo 0)"
  if [[ "$RAM_BYTES" =~ ^[0-9]+$ ]] && [[ "$RAM_BYTES" -gt 0 ]]; then
    DEVICE_RAM_GB="$((RAM_BYTES / 1024 / 1024 / 1024))"
  fi
fi

DEVICE_PERFORMANCE_CORES="${STEAVIUM_DEVICE_PERFORMANCE_CORES:-0}"
if ! [[ "$DEVICE_PERFORMANCE_CORES" =~ ^[0-9]+$ ]]; then
  DEVICE_PERFORMANCE_CORES=0
fi
if [[ "$DEVICE_PERFORMANCE_CORES" -eq 0 ]]; then
  PERF_CORES_SYSCTL="$(/usr/sbin/sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || echo 0)"
  if [[ "$PERF_CORES_SYSCTL" =~ ^[0-9]+$ ]] && [[ "$PERF_CORES_SYSCTL" -gt 0 ]]; then
    DEVICE_PERFORMANCE_CORES="$PERF_CORES_SYSCTL"
  fi
fi
if [[ "$DEVICE_PERFORMANCE_CORES" -eq 0 ]]; then
  PHYSICAL_CORES_SYSCTL="$(/usr/sbin/sysctl -n hw.physicalcpu 2>/dev/null || echo 0)"
  if [[ "$PHYSICAL_CORES_SYSCTL" =~ ^[0-9]+$ ]] && [[ "$PHYSICAL_CORES_SYSCTL" -gt 0 ]]; then
    DEVICE_PERFORMANCE_CORES="$PHYSICAL_CORES_SYSCTL"
  fi
fi

DEVICE_EFFICIENCY_CORES="${STEAVIUM_DEVICE_EFFICIENCY_CORES:-0}"
if ! [[ "$DEVICE_EFFICIENCY_CORES" =~ ^[0-9]+$ ]]; then
  DEVICE_EFFICIENCY_CORES=0
fi
if [[ "$DEVICE_EFFICIENCY_CORES" -eq 0 ]]; then
  EFF_CORES_SYSCTL="$(/usr/sbin/sysctl -n hw.perflevel1.physicalcpu 2>/dev/null || echo 0)"
  if [[ "$EFF_CORES_SYSCTL" =~ ^[0-9]+$ ]] && [[ "$EFF_CORES_SYSCTL" -gt 0 ]]; then
    DEVICE_EFFICIENCY_CORES="$EFF_CORES_SYSCTL"
  fi
fi

DEVICE_LOGICAL_CORES="${STEAVIUM_DEVICE_LOGICAL_CORES:-0}"
if ! [[ "$DEVICE_LOGICAL_CORES" =~ ^[0-9]+$ ]]; then
  DEVICE_LOGICAL_CORES=0
fi
if [[ "$DEVICE_LOGICAL_CORES" -eq 0 ]]; then
  LOGICAL_CORES_SYSCTL="$(/usr/sbin/sysctl -n hw.logicalcpu 2>/dev/null || echo 0)"
  if [[ "$LOGICAL_CORES_SYSCTL" =~ ^[0-9]+$ ]] && [[ "$LOGICAL_CORES_SYSCTL" -gt 0 ]]; then
    DEVICE_LOGICAL_CORES="$LOGICAL_CORES_SYSCTL"
  fi
fi
if [[ "$DEVICE_LOGICAL_CORES" -eq 0 ]]; then
  DEVICE_LOGICAL_CORES="$((DEVICE_PERFORMANCE_CORES + DEVICE_EFFICIENCY_CORES))"
fi

if [[ "$DEVICE_CHIP_FAMILY" == "unknown" || -z "$DEVICE_CHIP_FAMILY" ]]; then
  CHIP_MODEL_NORMALIZED="$(printf '%s' "$DEVICE_CHIP_MODEL" | tr '[:upper:]' '[:lower:]')"
  if [[ "$CHIP_MODEL_NORMALIZED" == *"m5"* ]]; then
    DEVICE_CHIP_FAMILY="m5"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"m4"* ]]; then
    DEVICE_CHIP_FAMILY="m4"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"m3"* ]]; then
    DEVICE_CHIP_FAMILY="m3"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"m2"* ]]; then
    DEVICE_CHIP_FAMILY="m2"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"m1"* ]]; then
    DEVICE_CHIP_FAMILY="m1"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"intel"* ]]; then
    DEVICE_CHIP_FAMILY="intel"
  elif [[ "$CHIP_MODEL_NORMALIZED" == *"apple"* ]]; then
    DEVICE_CHIP_FAMILY="appleSiliconOther"
  else
    DEVICE_CHIP_FAMILY="unknown"
  fi
fi

# Performance tier: provided by HardwareTuningAdvisor.swift via env var.
# When running standalone (no Swift host), use a conservative default.
PERFORMANCE_TIER="${STEAVIUM_PERFORMANCE_TIER:-}"
if [[ -z "$PERFORMANCE_TIER" ]]; then
  echo "[tuning] No Swift-provided performance tier; using conservative 'balanced' default."
  PERFORMANCE_TIER="balanced"
fi

# Recommended backend: provided by HardwareTuningAdvisor.swift via env var.
RECOMMENDED_BACKEND="${STEAVIUM_RECOMMENDED_BACKEND:-}"
if [[ -z "$RECOMMENDED_BACKEND" ]]; then
  echo "[tuning] No Swift-provided backend recommendation; defaulting to 'd3dmetal'."
  RECOMMENDED_BACKEND="d3dmetal"
fi

RECOMMENDED_DXVK_COMPILER_THREADS="${STEAVIUM_RECOMMENDED_DXVK_COMPILER_THREADS:-}"

# Display refresh rate (passed from Swift or detected here).
DISPLAY_REFRESH_RATE="${STEAVIUM_DISPLAY_REFRESH_RATE:-}"
if ! [[ "$DISPLAY_REFRESH_RATE" =~ ^[0-9]+$ ]] || (( DISPLAY_REFRESH_RATE <= 0 )); then
  # Fallback: try to detect via system_profiler.
  DISPLAY_REFRESH_RATE="$(system_profiler SPDisplaysDataType 2>/dev/null \
    | grep -i 'UI Looks like\|Resolution\|Refresh Rate' \
    | grep -oi '[0-9]\+ Hz' | head -1 | grep -o '[0-9]\+' || echo "60")"
  if ! [[ "$DISPLAY_REFRESH_RATE" =~ ^[0-9]+$ ]] || (( DISPLAY_REFRESH_RATE <= 0 )); then
    DISPLAY_REFRESH_RATE=60
  fi
fi

# Recommended FPS cap: provided by HardwareTuningAdvisor.swift via env var.
RECOMMENDED_FPS_CAP="${STEAVIUM_RECOMMENDED_FPS_CAP:-}"
if [[ -z "$RECOMMENDED_FPS_CAP" ]]; then
  echo "[tuning] No Swift-provided FPS cap; defaulting to display refresh rate ($DISPLAY_REFRESH_RATE Hz)."
  RECOMMENDED_FPS_CAP="$DISPLAY_REFRESH_RATE"
fi
EFFECTIVE_BACKEND="$GRAPHICS_BACKEND"

apply_hardware_tuning() {
  export WINEESYNC="${WINEESYNC:-1}"
  export WINEFSYNC="${WINEFSYNC:-1}"
  export WINEMSYNC="${WINEMSYNC:-1}"

  # Expose all logical cores to Wine so heavily-threaded games can use
  # them. The previous approach of limiting to P-cores only caused
  # throughput issues in multi-threaded titles. E-cores will handle
  # Wine background tasks via the OS scheduler's QoS hints, while
  # render-critical threads naturally migrate to P-cores.
  if (( DEVICE_LOGICAL_CORES > 0 )); then
    export WINE_CPU_TOPOLOGY="${WINE_CPU_TOPOLOGY:-${DEVICE_LOGICAL_CORES}:0}"
  fi

  export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
  export DXVK_HUD="${DXVK_HUD:-0}"
  export MTL_HUD_ENABLED="${MTL_HUD_ENABLED:-0}"
  export MTL_SHADER_VALIDATION="${MTL_SHADER_VALIDATION:-0}"
  export DXVK_PERF_EVENTS="${DXVK_PERF_EVENTS:-0}"
  export WINEDEBUG="${WINEDEBUG:--all}"
  export DISABLE_VK_LAYER_VALVE_steam_overlay_1="${DISABLE_VK_LAYER_VALVE_steam_overlay_1:-1}"
  export SteamNoOverlayUIDrawing="${SteamNoOverlayUIDrawing:-1}"
  export STEAM_DISABLE_OVERLAY="${STEAM_DISABLE_OVERLAY:-1}"

  # --- Low-latency input pipeline ----------------------------------------
  # Disable VSync at the Mesa/GL driver level.  DXVK_MAX_FRAME_LATENCY
  # already limits the present queue, but vblank_mode=0 ensures no
  # secondary VSync gate adds frames of latency in the OpenGL fallback
  # path or during compositor hand-off.
  export vblank_mode="${vblank_mode:-0}"
  export __GL_SYNC_TO_VBLANK="${__GL_SYNC_TO_VBLANK:-0}"

  # Disable Wine's IME (Input Method Editor) integration.  macdrv's IME
  # hook injects CoreText round-trips into the event pipeline for every
  # input message.  For gaming this adds pointless overhead (50–200 ms
  # cumulative per frame at high mouse poll rates) and is never needed.
  export WINE_IME_IMPLEMENTATION="${WINE_IME_IMPLEMENTATION:-disabled}"

  # Use the legacy TrueType interpreter (v35) to avoid font rendering
  # crashes in the newer interpreter that can trigger Objective-C
  # exceptions in winemac.so during glyph bitmap creation.
  export FREETYPE_PROPERTIES="${FREETYPE_PROPERTIES:-truetype:interpreter-version=35}"

  # Enable Wine large address awareness and staging shared-memory
  # optimisation.  Both improve memory layout stability during the
  # critical first seconds of process start-up.
  export WINE_LARGE_ADDRESS_AWARE="${WINE_LARGE_ADDRESS_AWARE:-1}"
  export STAGING_SHARED_MEMORY="${STAGING_SHARED_MEMORY:-1}"

  # DXVK compiler threads and FPS cap: use Swift-provided values directly.
  # The full calculation logic lives in HardwareTuningAdvisor.swift to
  # avoid maintaining duplicate decision trees in both Swift and bash.
  local compiler_threads="${RECOMMENDED_DXVK_COMPILER_THREADS:-3}"
  if ! [[ "$compiler_threads" =~ ^[0-9]+$ ]] || (( compiler_threads < 2 )); then
    compiler_threads=3
  fi
  if (( compiler_threads > 8 )); then
    compiler_threads=8
  fi

  local fps_cap="$RECOMMENDED_FPS_CAP"

  export DXVK_ASYNC="${DXVK_ASYNC:-1}"
  export DXVK_GPLASYNCD="${DXVK_GPLASYNCD:-1}"
  export DXVK_NUM_COMPILER_THREADS="${DXVK_NUM_COMPILER_THREADS:-$compiler_threads}"
  export DXVK_STATE_CACHE="${DXVK_STATE_CACHE:-1}"
  export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$STEAM_CACHE/dxvk-cache}"
  mkdir -p "$DXVK_STATE_CACHE_PATH"

  # Limit the present queue to 1 frame.  The default (3) adds multi-
  # frame latency between input sampling and display, so fast mouse
  # movements feel "delayed" and frame-time variance is amplified.
  # With depth=1 the GPU presents the most recently completed frame,
  # giving the tightest input→display loop.
  export DXVK_MAX_FRAME_LATENCY="${DXVK_MAX_FRAME_LATENCY:-1}"

  if [[ -n "$fps_cap" ]]; then
    export DXVK_FRAME_RATE="${DXVK_FRAME_RATE:-$fps_cap}"
  fi

  # Fsync spinlock count controls how long a thread busy-waits before
  # falling back to a kernel wait.  Too low (e.g. 100) causes frequent
  # context switches that introduce scheduling jitter visible as micro-
  # stutters; too high wastes CPU cycles.  500 is a good middle ground
  # for 60–120 Hz gaming on Apple Silicon.
  export WINEFSYNC_SPINCOUNT="${WINEFSYNC_SPINCOUNT:-500}"
}

# ---------------------------------------------------------------------------
# Disable HiDPI / Retina in Wine's macOS driver.
#
# winemac.so's HiDPI code path creates NSBitmapImageRep objects whose
# internal NSColorSpace can be erroneously sent -lock (an NSImage method)
# on macOS 14 (Sonoma) and later.  Disabling Retina mode forces Wine to
# use standard-resolution bitmaps, sidestepping this crash entirely.
# ---------------------------------------------------------------------------
configure_bottle_display() {
  local bottle_dir=""
  if is_crossover_mode; then
    bottle_dir="$CROSSOVER_BOTTLE_DIR"
  else
    bottle_dir="$STEAM_PREFIX"
  fi

  if [[ ! -d "$bottle_dir" ]]; then
    return 0
  fi

  local user_reg="$bottle_dir/user.reg"
  if [[ ! -f "$user_reg" ]]; then
    return 0
  fi

  # Already correctly set → nothing to do.
  if grep -qF '"RetinaMode"="n"' "$user_reg" 2>/dev/null; then
    echo "[display] Retina mode already disabled in Wine registry."
    return 0
  fi

  # If the key exists with a different value, replace it.
  if grep -qF '"RetinaMode"' "$user_reg" 2>/dev/null; then
    sed -i '' 's/"RetinaMode"="y"/"RetinaMode"="n"/g' "$user_reg" 2>/dev/null || true
    echo "[display] Retina mode disabled in Wine registry (updated)."
    return 0
  fi

  # If the [Software\\Wine\\Mac Driver] section exists, insert the key.
  # Use a broad pattern to match regardless of backslash escaping.
  if grep -q 'Software.*Wine.*Mac.Driver' "$user_reg" 2>/dev/null; then
    awk 'BEGIN{done=0} /Software.*Wine.*Mac.Driver/{print; if(!done){print "\"RetinaMode\"=\"n\""; done=1}; next} 1' \
      "$user_reg" > "${user_reg}.tmp" && mv "${user_reg}.tmp" "$user_reg"
    echo "[display] Retina mode disabled in Wine registry (inserted)."
    return 0
  fi

  # Section missing → append it.
  printf '\n[Software\\\\Wine\\\\Mac Driver]\n"RetinaMode"="n"\n' >> "$user_reg"
  echo "[display] Retina mode disabled in Wine registry (added)."
}

# ---------------------------------------------------------------------------
# Pre-warm the Wine prefix.
#
# Ensures wineserver and winemac.so's display subsystem are initialised
# before Steam tries to create its first window.  Without this warm-up,
# Steam's initial window creation can race with winemac.so's display
# bootstrap and crash with NSColorSpace / NSInvalidArgumentException.
#
# For already-initialised bottles a lightweight "hostname" command is
# used instead of a full wineboot --init, reducing overhead from ~10 s
# to ~2 s on a warm system.
# ---------------------------------------------------------------------------
prewarm_wine_prefix() {
  # If wineserver is already alive, the display driver is already loaded.
  if pgrep -x wineserver >/dev/null 2>&1; then
    echo "[prewarm] Wineserver already running — skipping."
    return 0
  fi

  local bottle_dir=""
  if is_crossover_mode; then
    bottle_dir="$CROSSOVER_BOTTLE_DIR"
  else
    bottle_dir="$STEAM_PREFIX"
  fi

  local max_seconds=8
  if [[ -f "$bottle_dir/system.reg" ]]; then
    # Bottle already exists — lightweight startup via hostname query.
    # This starts wineserver + loads winemac.so without running the full
    # registry/service bootstrap that wineboot performs.
    echo "[prewarm] Quick Wine startup (max ${max_seconds}s)..."
    if is_crossover_mode; then
      "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" \
        hostname >/dev/null 2>&1 &
    else
      WINEPREFIX="$STEAM_PREFIX" WINEARCH=win64 \
        "$WINE_BIN" hostname >/dev/null 2>&1 &
    fi
  else
    # First-time boot — needs full initialisation.
    max_seconds=12
    echo "[prewarm] First-time Wine initialization (max ${max_seconds}s)..."
    if is_crossover_mode; then
      "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" \
        wineboot --init >/dev/null 2>&1 &
    else
      WINEPREFIX="$STEAM_PREFIX" WINEARCH=win64 \
        "$WINE_BIN" wineboot --init >/dev/null 2>&1 &
    fi
  fi
  local boot_pid=$!

  local waited=0
  while kill -0 "$boot_pid" 2>/dev/null && (( waited < max_seconds )); do
    sleep 1
    waited=$((waited + 1))
  done

  if kill -0 "$boot_pid" 2>/dev/null; then
    kill "$boot_pid" 2>/dev/null || true
    wait "$boot_pid" 2>/dev/null || true
    echo "[prewarm] Wine initialization timed out (${max_seconds}s) — continuing."
  else
    wait "$boot_pid" 2>/dev/null || true
    echo "[prewarm] Wine ready (${waited}s)."
  fi
}

resolve_effective_backend() {
  case "$GRAPHICS_BACKEND" in
    d3dmetal|dxvk)
      EFFECTIVE_BACKEND="$GRAPHICS_BACKEND"
      ;;
    auto)
      EFFECTIVE_BACKEND="$RECOMMENDED_BACKEND"
      ;;
    *)
      echo "Backend invalido: $GRAPHICS_BACKEND (usa d3dmetal|dxvk|auto)"
      exit 1
      ;;
  esac

  case "$EFFECTIVE_BACKEND" in
    d3dmetal|dxvk)
      ;;
    *)
      EFFECTIVE_BACKEND="d3dmetal"
      ;;
  esac
}

apply_backend_tuning() {
  local backend="$1"

  case "$backend" in
    d3dmetal)
      export D3DMETAL="${D3DMETAL:-1}"
      export DXVK="${DXVK:-0}"

      # Unified memory optimization (M1–M5): enable optimized shared
      # event handling to reduce CPU↔GPU synchronisation overhead.
      export MTL_SHARED_EVENT_HANDLING_OPTIMIZED="${MTL_SHARED_EVENT_HANDLING_OPTIMIZED:-1}"

      # Skip wrapping swap-chain presents inside a Metal command buffer;
      # present directly to CAMetalLayer.  Eliminates one scheduling
      # round-trip per frame, tightening frame pacing and reducing
      # input-to-photon latency.
      export MVK_CONFIG_PRESENT_WITH_COMMAND_BUFFER="${MVK_CONFIG_PRESENT_WITH_COMMAND_BUFFER:-0}"
      ;;
    dxvk)
      export DXVK="${DXVK:-1}"
      export D3DMETAL="${D3DMETAL:-0}"

      # MoltenVK tuning — only relevant when DXVK translates Vulkan→Metal.
      export MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS="${MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS:-2}"
      export MVK_CONFIG_RESUME_LOST_DEVICE="${MVK_CONFIG_RESUME_LOST_DEVICE:-1}"
      # Aggressively prefill Metal command buffers (level 2) to reduce
      # CPU-side submission overhead and improve frame pacing.
      export MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS="${MVK_CONFIG_PREFILL_METAL_COMMAND_BUFFERS:-2}"
      export MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS="${MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS:-0}"
      export MVK_CONFIG_FAST_MATH_ENABLED="${MVK_CONFIG_FAST_MATH_ENABLED:-1}"
      export MVK_CONFIG_LOG_LEVEL="${MVK_CONFIG_LOG_LEVEL:-0}"
      export MVK_CONFIG_DEBUG_UTILS="${MVK_CONFIG_DEBUG_UTILS:-0}"
      # Timestamp period must be non-zero for DXVK frame pacing to work
      # correctly on Apple GPUs where the native timestamp period is 0.
      export MVK_CONFIG_TIMESTAMP_PERIOD_LOWPASS_ALPHA="${MVK_CONFIG_TIMESTAMP_PERIOD_LOWPASS_ALPHA:-0.05}"

      # Present directly to CAMetalLayer without wrapping in a command
      # buffer — same rationale as D3DMetal path above.
      export MVK_CONFIG_PRESENT_WITH_COMMAND_BUFFER="${MVK_CONFIG_PRESENT_WITH_COMMAND_BUFFER:-0}"

      # Unified memory optimization (M1–M5): force use of the high-
      # performance GPU and avoid falling back to low-power integrated.
      export MVK_CONFIG_FORCE_LOW_POWER_GPU="${MVK_CONFIG_FORCE_LOW_POWER_GPU:-0}"
      ;;
    *)
      ;;
  esac
}

# Tune QoS for Wine auxiliary processes after launch.
#
# wineserver serialises ALL window messages — including raw mouse input.
# When the macOS scheduler deprioritises it (normal under heavy GPU
# load), every mouse event is delayed by the scheduling quantum
# (≈ 4–8 ms per event), which compounds into the 2–4 s perceived
# lag users report when sweeping the camera quickly.
#
# Strategy:
#   1. Apply interactive QoS (taskpolicy -t) to wineserver as early as
#      possible — reduced initial sleep from 2 s → 1 s.
#   2. RE-APPLY the boost in several rounds over ~30 s.  Wineserver may
#      restart during Steam's bootstrap phase, and fresh dxvk-compiler
#      threads can spawn at any time during the first minute of gameplay.
#   3. Also `renice` wineserver to -5 so the Mach scheduler gives it
#      higher effective priority even when P-cores are saturated.
#   4. Relegate shader compilers to background QoS so they never steal
#      cycles from the render or input threads.
relegate_wine_auxiliaries() {
  local rounds=5
  local delays=(1 4 8 15 30)   # cumulative: 1 s, 5 s, 13 s, 28 s, 58 s

  for (( i = 0; i < rounds; i++ )); do
    sleep "${delays[$i]}"

    # Boost wineserver → interactive / throughput QoS + higher nice.
    for pid in $(pgrep -x wineserver 2>/dev/null); do
      taskpolicy -t -p "$pid" 2>/dev/null && \
        echo "[tuning] taskpolicy -t (interactive) applied to wineserver (PID=$pid)" || true
      renice -n -5 -p "$pid" 2>/dev/null && \
        echo "[tuning] renice -5 applied to wineserver (PID=$pid)" || true
    done

    # Relegate shader compiler → background QoS.
    for pid in $(pgrep -f dxvk-compiler 2>/dev/null); do
      taskpolicy -b -p "$pid" 2>/dev/null && \
        echo "[tuning] taskpolicy -b applied to dxvk-compiler (PID=$pid)" || true
    done
  done
}

# Pre-load the DXVK state cache into memory so shader recompilation
# stutters are eliminated on the first session after each boot.
warmup_shader_cache() {
  local cache_dir="${DXVK_STATE_CACHE_PATH:-}"
  if [[ -z "$cache_dir" ]] || [[ ! -d "$cache_dir" ]]; then
    return 0
  fi

  # Collect .dxvk-cache files using find (compatible with macOS bash 3.2).
  local cache_files=()
  while IFS= read -r -d '' f; do
    cache_files+=("$f")
  done < <(find "$cache_dir" -name '*.dxvk-cache' -type f -print0 2>/dev/null)
  if (( ${#cache_files[@]} == 0 )); then
    echo "[shader-warmup] No cache files found in $cache_dir — skipping."
    return 0
  fi

  local warmup_timeout="${STEAVIUM_SHADER_WARMUP_TIMEOUT:-10}"
  echo "[shader-warmup] Warming up ${#cache_files[@]} cache file(s) (timeout=${warmup_timeout}s)..."

  # Read each cache file into /dev/null to pull it into the unified
  # memory page cache, so DXVK finds it hot when it opens the file.
  local start_epoch
  start_epoch="$(date +%s)"
  for f in "${cache_files[@]}"; do
    local elapsed=$(( $(date +%s) - start_epoch ))
    if (( elapsed >= warmup_timeout )); then
      echo "[shader-warmup] Timeout reached after ${elapsed}s — continuing launch."
      break
    fi
    cat "$f" > /dev/null 2>&1 || true
  done

  echo "[shader-warmup] Done."
}

run_steam_with_retry() {
  local max_attempts="${STEAVIUM_STEAM_RELAUNCH_ATTEMPTS:-3}"
  local relaunch_statuses="${STEAVIUM_STEAM_RELAUNCH_STATUSES:-42,143}"
  local attempt=1
  local status=0

  if ! [[ "$max_attempts" =~ ^[0-9]+$ ]] || (( max_attempts < 1 )); then
    max_attempts=3
  fi

  while true; do
    set +e
    "$@" &
    local steam_pid=$!
    relegate_wine_auxiliaries &
    wait "$steam_pid"
    status=$?
    set -e

    status_requires_retry=0
    for code in ${relaunch_statuses//,/ }; do
      if [[ "$code" =~ ^[0-9]+$ ]] && (( status == code )); then
        status_requires_retry=1
        break
      fi
    done

    if (( status_requires_retry == 1 )) && (( attempt < max_attempts )); then
      echo "[steam] Bootstrap solicito relanzamiento (exit=${status}). Reintento ${attempt}/${max_attempts}..."
      attempt=$((attempt + 1))
      sleep 1
      continue
    fi

    return "$status"
  done
}

run_bootstrap_until_running() {
  local checker_fn="$1"
  shift

  local bootstrap_attempts="${STEAVIUM_STEAM_BOOTSTRAP_ATTEMPTS:-3}"
  local stable_runtime_seconds="${STEAVIUM_STEAM_STABLE_RUNTIME_SECONDS:-45}"
  local bootstrap_index=1
  local status=0

  if ! [[ "$bootstrap_attempts" =~ ^[0-9]+$ ]] || (( bootstrap_attempts < 1 )); then
    bootstrap_attempts=3
  fi
  if ! [[ "$stable_runtime_seconds" =~ ^[0-9]+$ ]] || (( stable_runtime_seconds < 1 )); then
    stable_runtime_seconds=45
  fi

  while (( bootstrap_index <= bootstrap_attempts )); do
    local start_epoch
    local end_epoch
    local runtime_seconds

    start_epoch="$(date +%s)"
    run_steam_with_retry "$@"
    status=$?
    end_epoch="$(date +%s)"
    runtime_seconds=$((end_epoch - start_epoch))

    if (( status != 0 )); then
      return "$status"
    fi

    # If Steam stayed attached for a while, treat it as a valid user session end.
    if (( runtime_seconds >= stable_runtime_seconds )); then
      return 0
    fi

    if "$checker_fn"; then
      return 0
    fi

    if (( bootstrap_index < bootstrap_attempts )); then
      echo "[steam] Proceso finalizo demasiado pronto (${runtime_seconds}s) y Steam no quedo activo. Reintento ${bootstrap_index}/${bootstrap_attempts}..."
      sleep 1
    fi
    bootstrap_index=$((bootstrap_index + 1))
  done

  echo "[steam] Steam no quedo en ejecucion tras ${bootstrap_attempts} intentos."
  return 1
}

STEAM_EXE="$(resolve_steam_exe || true)"
if [[ -z "${STEAM_EXE:-}" ]]; then
  echo "Steam no esta instalado en el entorno actual."
  exit 1
fi

is_fallback_steam_running() {
  pgrep -f "$STEAM_EXE" >/dev/null 2>&1
}

repair_steam_library_layout

resolve_effective_backend
apply_hardware_tuning
echo "[hardware] chip=\"$DEVICE_CHIP_MODEL\" familia=$DEVICE_CHIP_FAMILY ram_gb=$DEVICE_RAM_GB cores=P${DEVICE_PERFORMANCE_CORES}/E${DEVICE_EFFICIENCY_CORES}/L${DEVICE_LOGICAL_CORES} perfil=$PERFORMANCE_TIER backend=$EFFECTIVE_BACKEND dxvk_threads=${DXVK_NUM_COMPILER_THREADS:-unset} refresh=${DISPLAY_REFRESH_RATE}Hz"

# Shader cache warm-up is deferred to AFTER the Steam process
# launches (see below).  This avoids blocking the launch with up
# to 10 s of I/O before the user sees any Steam window.

export STEAVIUM_MEDIA_COMPAT_DRY_RUN="$MEDIA_COMPAT_DRY_RUN"

if [[ "$MEDIA_COMPAT_ONLY" -eq 1 ]]; then
  run_media_compat_pass
  echo "[media] Modo solo-compatibilidad completado."
  exit 0
fi

# Run the media compat scan only in the worker or interactive mode.
# In worker mode, run it in background so Steam launches immediately
# instead of waiting for the (potentially minutes-long) scan to finish.
if [[ "$DETACHED" -eq 0 ]]; then
  run_media_compat_pass
elif [[ "$WORKER_MODE" -eq 1 ]]; then
  run_media_compat_pass &
fi

LOG_FILE="$STEAM_LOGS/steam-live.log"
# -noverifyfiles: skip the file-verification splash window whose
#   creation triggers the winemac.so NSColorSpace crash.
# -no-dwrite: disable DirectWrite (GDI fallback is more stable under Wine).
# -no-cef-sandbox: required for CEF in the Wine environment.
FLAGS=(-no-dwrite -no-cef-sandbox -noverifyfiles)
if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
  STEAM_CMD_ARGS=("$STEAM_EXE" "${FLAGS[@]}" "${EXTRA_ARGS[@]}")
else
  STEAM_CMD_ARGS=("$STEAM_EXE" "${FLAGS[@]}")
fi

if is_crossover_mode; then
  ensure_crossover_bottle

  apply_backend_tuning "$EFFECTIVE_BACKEND"
  configure_crossover_multimedia_env

  # --- Display crash prevention (NSColorSpace / winemac.so) -------------
  configure_bottle_display

  case "$IF_RUNNING" in
    reuse|restart)
      ;;
    *)
      echo "Modo invalido para --if-running: $IF_RUNNING (usa reuse|restart)"
      exit 1
      ;;
  esac

  if is_crossover_steam_running; then
    if [[ "$IF_RUNNING" == "reuse" ]]; then
      focus_crossover_steam_window
      echo "Steam ya estaba ejecutandose. Se mantuvo la sesion activa."
      exit 0
    fi
    echo "Steam en ejecucion detectado. Reiniciando por solicitud."
  fi

  # If Steam was not running, this still clears stale helpers from
  # incomplete sessions before relaunch.
  cleanup_crossover_steam_processes

  if [[ "$DETACHED" -eq 1 && "$WORKER_MODE" -ne 1 ]]; then
    worker_args=(--backend "$GRAPHICS_BACKEND" --if-running "$IF_RUNNING" --worker-mode)
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
      worker_args+=("${EXTRA_ARGS[@]}")
    fi
    nohup /bin/bash "$0" \
      "${worker_args[@]}" >> "$LOG_FILE" 2>&1 &
    echo "Steam lanzado en background (CrossOver worker). PID=$! LOG=$LOG_FILE"
    exit 0
  fi

  # Pre-warm Wine and shader cache in parallel to minimise startup latency.
  prewarm_wine_prefix &
  local prewarm_pid=$!
  warmup_shader_cache &
  wait "$prewarm_pid" 2>/dev/null || true

  run_bootstrap_until_running \
    is_crossover_steam_running \
    "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" "${STEAM_CMD_ARGS[@]}"
  exit $?
fi

WINE_BIN="$(detect_wine64 || true)"
if [[ -z "${WINE_BIN:-}" ]]; then
  echo "No se detecto runtime Wine compatible."
  exit 1
fi

export WINEPREFIX="$STEAM_PREFIX"
export WINEARCH=win64

if [[ "$EFFECTIVE_BACKEND" == "d3dmetal" ]]; then
  echo "[hardware] D3DMetal requiere CrossOver. En fallback Wine se usara DXVK."
  EFFECTIVE_BACKEND="dxvk"
fi
apply_backend_tuning "$EFFECTIVE_BACKEND"

# --- Display crash prevention (NSColorSpace / winemac.so) ---------------
configure_bottle_display

case "$IF_RUNNING" in
  reuse|restart)
    ;;
  *)
    echo "Modo invalido para --if-running: $IF_RUNNING (usa reuse|restart)"
    exit 1
    ;;
esac

if pgrep -f "$STEAM_EXE" >/dev/null 2>&1; then
  if [[ "$IF_RUNNING" == "reuse" ]]; then
    echo "Steam ya esta ejecutandose."
    exit 0
  fi

  pkill -f "$STEAM_EXE" >/dev/null 2>&1 || true
  sleep 1
fi

if [[ "$DETACHED" -eq 1 && "$WORKER_MODE" -ne 1 ]]; then
  worker_args=(--backend "$GRAPHICS_BACKEND" --if-running "$IF_RUNNING" --worker-mode)
  if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
    worker_args+=("${EXTRA_ARGS[@]}")
  fi
  nohup /bin/bash "$0" \
    "${worker_args[@]}" >> "$LOG_FILE" 2>&1 &
  echo "Steam lanzado en background (worker). PID=$! LOG=$LOG_FILE"
  exit 0
fi

# Pre-warm Wine and shader cache in parallel to minimise startup latency.
prewarm_wine_prefix &
_prewarm_pid=$!
warmup_shader_cache &
wait "$_prewarm_pid" 2>/dev/null || true

run_bootstrap_until_running is_fallback_steam_running "$WINE_BIN" "${STEAM_CMD_ARGS[@]}"
