#!/usr/bin/env bash
set -euo pipefail

STEAVIUM_HOME="${STEAVIUM_HOME:-$HOME/Library/Application Support/Steavium}"
STEAM_PREFIX="$STEAVIUM_HOME/prefixes/steam"
STEAM_CACHE="$STEAVIUM_HOME/cache"
STEAM_LOGS="$STEAVIUM_HOME/logs"
STEAM_INSTALLER="$STEAM_CACHE/SteamSetup.exe"

CROSSOVER_WINE="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"
CROSSOVER_BOTTLE_TOOL="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/cxbottle"
CROSSOVER_BOTTLE_NAME="${STEAVIUM_CROSSOVER_BOTTLE:-steavium-steam}"
CROSSOVER_BOTTLE_TEMPLATE="${STEAVIUM_CROSSOVER_TEMPLATE:-win10_64}"
CROSSOVER_BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$CROSSOVER_BOTTLE_NAME"
CROSSOVER_STEAM_EXE_X64="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files/Steam/Steam.exe"
CROSSOVER_STEAM_EXE_X86="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Steam/steam.exe"

STEAM_EXE_X86="$STEAM_PREFIX/drive_c/Program Files (x86)/Steam/steam.exe"
STEAM_EXE_X64="$STEAM_PREFIX/drive_c/Program Files/Steam/steam.exe"

ensure_dirs() {
  mkdir -p "$STEAVIUM_HOME" "$STEAM_PREFIX" "$STEAM_CACHE" "$STEAM_LOGS"
}

is_crossover_mode() {
  local mode="${STEAVIUM_WINE_MODE:-auto}"
  if [[ "$mode" == "wine" ]]; then
    return 1
  fi
  [[ -x "$CROSSOVER_WINE" && -x "$CROSSOVER_BOTTLE_TOOL" ]]
}

ensure_crossover_bottle() {
  if ! is_crossover_mode; then
    return 1
  fi

  if [[ -f "$CROSSOVER_BOTTLE_DIR/system.reg" ]]; then
    if grep -q "^#arch=win32$" "$CROSSOVER_BOTTLE_DIR/system.reg"; then
      local backup_path="$CROSSOVER_BOTTLE_DIR.backup.$(date +%Y%m%d-%H%M%S)"
      mv "$CROSSOVER_BOTTLE_DIR" "$backup_path"
      echo "Bottle 32-bit detectada y respaldada en: $backup_path"
    fi
  fi

  if [[ ! -d "$CROSSOVER_BOTTLE_DIR" ]]; then
    "$CROSSOVER_BOTTLE_TOOL" --bottle "$CROSSOVER_BOTTLE_NAME" \
      --create --template "$CROSSOVER_BOTTLE_TEMPLATE"
  fi
}

detect_wine64() {
  local mode="${STEAVIUM_WINE_MODE:-auto}"

  local crossover_candidates=(
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/CrossOver-Hosted Application/wine"
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/x86_64-unix/wine"
  )
  local wine_candidates=(
    "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64"
    "/Applications/Whisky.app/Contents/Resources/wine/bin/wine64"
    "/opt/homebrew/bin/wine64"
    "/opt/homebrew/bin/wine"
    "/usr/local/bin/wine64"
    "/usr/local/bin/wine"
  )

  local candidates=()
  case "$mode" in
    crossover)
      candidates=("${crossover_candidates[@]}")
      ;;
    wine)
      candidates=("${wine_candidates[@]}")
      ;;
    *)
      candidates=("${crossover_candidates[@]}" "${wine_candidates[@]}")
      ;;
  esac

  if [[ "$mode" != "crossover" ]]; then
    if command -v wine >/dev/null 2>&1; then
      candidates+=("$(command -v wine)")
    fi
    if command -v wine64 >/dev/null 2>&1; then
      candidates+=("$(command -v wine64)")
    fi
  fi

  local candidate=""
  for candidate in "${candidates[@]}"; do
    if [[ -n "${candidate:-}" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_steam_exe() {
  local crossover_manifest_x86="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files (x86)/Steam/package/steam_client_win64.installed"
  local crossover_manifest_x64="$CROSSOVER_BOTTLE_DIR/drive_c/Program Files/Steam/package/steam_client_win64.installed"
  local prefix_manifest_x86="$STEAM_PREFIX/drive_c/Program Files (x86)/Steam/package/steam_client_win64.installed"
  local prefix_manifest_x64="$STEAM_PREFIX/drive_c/Program Files/Steam/package/steam_client_win64.installed"

  if is_crossover_mode; then
    if [[ -f "$CROSSOVER_STEAM_EXE_X86" && -s "$crossover_manifest_x86" ]]; then
      printf '%s\n' "$CROSSOVER_STEAM_EXE_X86"
      return 0
    fi
    if [[ -f "$CROSSOVER_STEAM_EXE_X64" && -s "$crossover_manifest_x64" ]]; then
      printf '%s\n' "$CROSSOVER_STEAM_EXE_X64"
      return 0
    fi
    if [[ -f "$CROSSOVER_STEAM_EXE_X86" ]]; then
      printf '%s\n' "$CROSSOVER_STEAM_EXE_X86"
      return 0
    fi
    if [[ -f "$CROSSOVER_STEAM_EXE_X64" ]]; then
      printf '%s\n' "$CROSSOVER_STEAM_EXE_X64"
      return 0
    fi
  fi

  if [[ -f "$STEAM_EXE_X86" && -s "$prefix_manifest_x86" ]]; then
    printf '%s\n' "$STEAM_EXE_X86"
    return 0
  fi
  if [[ -f "$STEAM_EXE_X64" && -s "$prefix_manifest_x64" ]]; then
    printf '%s\n' "$STEAM_EXE_X64"
    return 0
  fi
  if [[ -f "$STEAM_EXE_X86" ]]; then
    printf '%s\n' "$STEAM_EXE_X86"
    return 0
  fi
  if [[ -f "$STEAM_EXE_X64" ]]; then
    printf '%s\n' "$STEAM_EXE_X64"
    return 0
  fi
  return 1
}

resolve_steam_root() {
  local steam_exe=""
  steam_exe="$(resolve_steam_exe || true)"
  if [[ -z "${steam_exe:-}" ]]; then
    return 1
  fi
  dirname "$steam_exe"
}

redirect_steam_dir_to_external() {
  local source_dir="$1"
  local target_dir="$2"

  mkdir -p "$target_dir"

  if [[ -L "$source_dir" ]]; then
    local linked_target=""
    linked_target="$(readlink "$source_dir" || true)"
    if [[ "$linked_target" == "$target_dir" ]]; then
      return 0
    fi
    rm -f "$source_dir" 2>/dev/null || true
  elif [[ -d "$source_dir" ]]; then
    if find "$source_dir" -mindepth 1 -print -quit >/dev/null 2>&1; then
      cp -a "$source_dir/." "$target_dir/" 2>/dev/null || true
    fi
    rm -rf "$source_dir"
  elif [[ -e "$source_dir" ]]; then
    rm -rf "$source_dir" 2>/dev/null || true
  fi

  ln -s "$target_dir" "$source_dir"
}

ensure_local_steam_dir() {
  local local_dir="$1"
  if [[ -L "$local_dir" ]]; then
    rm -f "$local_dir" 2>/dev/null || true
  fi
  mkdir -p "$local_dir"
}

repair_steam_library_layout() {
  local steam_root=""
  steam_root="$(resolve_steam_root || true)"
  if [[ -z "${steam_root:-}" ]]; then
    return 0
  fi

  local steamapps_dir="$steam_root/steamapps"
  mkdir -p "$steamapps_dir"

  local external_library_root="${STEAVIUM_GAME_LIBRARY_PATH:-}"
  external_library_root="${external_library_root%/}"

  if [[ -n "$external_library_root" ]]; then
    if [[ -d "$external_library_root" ]]; then
      local external_steam_root="$external_library_root/SteaviumSteamLibrary"
      mkdir -p "$external_steam_root"
      redirect_steam_dir_to_external "$steamapps_dir/common" "$external_steam_root/common"
      redirect_steam_dir_to_external "$steamapps_dir/downloading" "$external_steam_root/downloading"
      redirect_steam_dir_to_external "$steamapps_dir/temp" "$external_steam_root/temp"
      redirect_steam_dir_to_external "$steamapps_dir/workshop" "$external_steam_root/workshop"
      redirect_steam_dir_to_external "$steamapps_dir/shadercache" "$external_steam_root/shadercache"
      redirect_steam_dir_to_external "$steamapps_dir/compatdata" "$external_steam_root/compatdata"
      echo "[library] Biblioteca de juegos en almacenamiento externo: $external_steam_root"
    else
      echo "[library] Ruta de biblioteca no disponible: $external_library_root (usando ubicacion por defecto)"
      ensure_local_steam_dir "$steamapps_dir/common"
      ensure_local_steam_dir "$steamapps_dir/downloading"
      ensure_local_steam_dir "$steamapps_dir/temp"
      ensure_local_steam_dir "$steamapps_dir/workshop"
      ensure_local_steam_dir "$steamapps_dir/shadercache"
      ensure_local_steam_dir "$steamapps_dir/compatdata"
    fi
  else
    ensure_local_steam_dir "$steamapps_dir/common"
    ensure_local_steam_dir "$steamapps_dir/downloading"
    ensure_local_steam_dir "$steamapps_dir/temp"
    ensure_local_steam_dir "$steamapps_dir/workshop"
    ensure_local_steam_dir "$steamapps_dir/shadercache"
    ensure_local_steam_dir "$steamapps_dir/compatdata"
  fi

  # Only fix permissions on the steamapps root and its immediate
  # subdirectories — a recursive chmod on allgame files is extremely
  # slow when many games are installed.
  chmod u+rwX "$steamapps_dir" 2>/dev/null || true
  for subdir in common downloading temp workshop shadercache compatdata; do
    if [[ -d "$steamapps_dir/$subdir" ]]; then
      chmod u+rwX "$steamapps_dir/$subdir" 2>/dev/null || true
    fi
  done

  local library_vdf="$steamapps_dir/libraryfolders.vdf"
  if [[ ! -f "$library_vdf" ]]; then
    local windows_steam_path="C:\\Program Files (x86)\\Steam"
    if [[ "$steam_root" == *"/drive_c/"* ]]; then
      local relative_to_c="${steam_root##*/drive_c/}"
      windows_steam_path="C:\\${relative_to_c//\//\\}"
    fi

    cat > "$library_vdf" <<EOF
"libraryfolders"
{
	"0"
	{
		"path"		"$windows_steam_path"
		"label"		""
		"contentid"		"0"
		"totalsize"		"0"
		"update_clean_bytes_tally"		"0"
		"time_last_update_verified"		"0"
		"apps"
		{
		}
	}
}
EOF
  fi
}

cleanup_crossover_steam_processes() {
  if ! is_crossover_mode; then
    return 0
  fi

  # Remove orphaned wrapper processes that still point to this bottle.
  pkill -f "winewrapper.exe --run -- .*Bottles/$CROSSOVER_BOTTLE_NAME/drive_c/Program Files \\(x86\\)/Steam/steam.exe" >/dev/null 2>&1 || true
  pkill -f "winewrapper.exe --run -- .*Bottles/$CROSSOVER_BOTTLE_NAME/drive_c/Program Files/Steam/Steam.exe" >/dev/null 2>&1 || true

  # Also clear stale Steam client/webhelper leftovers that block relaunches.
  pkill -f "^C:\\\\Program Files( \\(x86\\))?\\\\Steam\\\\[sS]team\\.exe( |$)" >/dev/null 2>&1 || true
  pkill -f "steamwebhelper.exe" >/dev/null 2>&1 || true
}

is_crossover_steam_running() {
  if ! is_crossover_mode; then
    return 1
  fi

  pgrep -f "^C:\\\\Program Files( \\(x86\\))?\\\\Steam\\\\[sS]team\\.exe( |$)" >/dev/null 2>&1
}

focus_crossover_steam_window() {
  if ! is_crossover_mode; then
    return 1
  fi

  local steam_exe=""
  steam_exe="$(resolve_steam_exe || true)"
  if [[ -z "${steam_exe:-}" ]]; then
    return 1
  fi

  # Ask existing Steam instance to open/focus the main client window.
  "$CROSSOVER_WINE" --bottle "$CROSSOVER_BOTTLE_NAME" \
    "$steam_exe" -open "steam://open/main" >/dev/null 2>&1 || true
}

is_non_negative_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

is_non_negative_float() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

float_greater_than() {
  local lhs="${1:-0}"
  local rhs="${2:-0}"
  awk -v lhs="$lhs" -v rhs="$rhs" 'BEGIN { exit (lhs > rhs) ? 0 : 1 }'
}

parse_ffprobe_fps() {
  local rate="${1:-0/1}"
  awk -v rate="$rate" 'BEGIN {
    split(rate, pieces, "/");
    if (pieces[2] == "" || pieces[2] == 0) {
      printf "0";
      exit;
    }
    printf "%.3f", pieces[1] / pieces[2];
  }'
}

configure_crossover_multimedia_env() {
  if ! is_crossover_mode; then
    return 0
  fi

  local -a crossover_gst_plugin_paths=()
  local path_candidate=""
  for path_candidate in \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib64/gstreamer-1.0" \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/gstreamer-1.0"; do
    if [[ -d "$path_candidate" ]]; then
      crossover_gst_plugin_paths+=("$path_candidate")
    fi
  done

  if (( ${#crossover_gst_plugin_paths[@]} == 0 )); then
    return 0
  fi

  # Keep Wine on x86_64 GStreamer plugins from CrossOver. This avoids
  # picking arm64 Homebrew plugins that crash or stutter in video playback.
  unset GST_PLUGIN_PATH GST_PLUGIN_PATH_1_0 GST_PLUGIN_SYSTEM_PATH GST_PLUGIN_SYSTEM_PATH_1_0
  unset GST_PLUGIN_SCANNER GST_PLUGIN_SCANNER_1_0

  local joined_plugin_paths=""
  joined_plugin_paths="$(IFS=:; printf '%s' "${crossover_gst_plugin_paths[*]}")"
  export GST_PLUGIN_SYSTEM_PATH_1_0="$joined_plugin_paths"
  export GST_PLUGIN_SYSTEM_PATH="$joined_plugin_paths"
  export GST_PLUGIN_PATH_1_0="$joined_plugin_paths"
  export GST_PLUGIN_PATH="$joined_plugin_paths"

  local scanner_candidate=""
  for scanner_candidate in \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/libexec/gstreamer-1.0/gst-plugin-scanner" \
    "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/libexec/gstreamer-1.0/gst-plugin-scanner-1.0"; do
    if [[ -x "$scanner_candidate" ]]; then
      export GST_PLUGIN_SCANNER_1_0="$scanner_candidate"
      export GST_PLUGIN_SCANNER="$scanner_candidate"
      break
    fi
  done

  local gst_registry_dir="$STEAM_CACHE/gstreamer"
  mkdir -p "$gst_registry_dir"
  export GST_REGISTRY_1_0="$gst_registry_dir/registry.x86_64.bin"
  export GST_REGISTRY="$gst_registry_dir/registry.x86_64.bin"
}

run_media_compat_pass() {
  local enabled="${STEAVIUM_MEDIA_COMPAT_ENABLED:-1}"
  if [[ "$enabled" != "1" ]]; then
    echo "[media] Compatibilidad multimedia desactivada."
    return 0
  fi

  if ! command -v ffprobe >/dev/null 2>&1 || ! command -v ffmpeg >/dev/null 2>&1; then
    echo "[media] ffmpeg/ffprobe no disponibles. Saltando normalizacion de videos."
    return 0
  fi

  local steam_root=""
  steam_root="$(resolve_steam_root || true)"
  if [[ -z "${steam_root:-}" ]]; then
    echo "[media] Steam no localizado. Saltando normalizacion de videos."
    return 0
  fi

  local common_dir="$steam_root/steamapps/common"
  if [[ ! -d "$common_dir" ]]; then
    echo "[media] No hay biblioteca de juegos en: $common_dir"
    return 0
  fi

  local profile="${STEAVIUM_PERFORMANCE_TIER:-balanced}"
  local ram_gb="${STEAVIUM_DEVICE_RAM_GB:-${DEVICE_RAM_GB:-0}}"
  local dry_run="${STEAVIUM_MEDIA_COMPAT_DRY_RUN:-0}"
  local only_short="${STEAVIUM_MEDIA_COMPAT_ONLY_SHORT:-1}"
  local cooldown_minutes="${STEAVIUM_MEDIA_COMPAT_COOLDOWN_MINUTES:-120}"
  local stamp_file="$STEAM_CACHE/media-compat.last-run"

  if [[ "$dry_run" != "1" ]] && is_non_negative_integer "$cooldown_minutes" \
    && (( cooldown_minutes > 0 )) && [[ -f "$stamp_file" ]]; then
    local now_epoch
    now_epoch="$(date +%s)"
    local last_epoch
    last_epoch="$(stat -f %m "$stamp_file" 2>/dev/null || echo 0)"
    if is_non_negative_integer "$last_epoch" && (( last_epoch > 0 )); then
      local elapsed_seconds=$((now_epoch - last_epoch))
      local cooldown_seconds=$((cooldown_minutes * 60))
      if (( elapsed_seconds >= 0 && elapsed_seconds < cooldown_seconds )); then
        local remaining_minutes=$(((cooldown_seconds - elapsed_seconds + 59) / 60))
        echo "[media] Saltando compatibilidad multimedia (cooldown activo, restante=${remaining_minutes}m)."
        return 0
      fi
    fi
  fi

  local max_width=1920
  local max_height=1080
  local max_fps=30
  local max_duration=480
  local max_files=24
  local max_level=41
  local target_level_text="4.1"
  local target_profile="main"
  local encode_threads=4
  local video_crf=23
  local video_target_bitrate="4500k"
  local video_maxrate="6000k"
  local video_bufsize="9000k"
  local audio_bitrate="128k"

  case "$profile" in
    economy)
      max_width=1280
      max_height=720
      max_fps=30
      max_duration=300
      max_files=16
      max_level=40
      target_level_text="4.0"
      target_profile="main"
      encode_threads=2
      video_crf=24
      video_target_bitrate="2500k"
      video_maxrate="3500k"
      video_bufsize="5000k"
      audio_bitrate="96k"
      ;;
    balanced)
      max_width=1920
      max_height=1080
      max_fps=30
      max_duration=480
      max_files=24
      max_level=41
      target_level_text="4.1"
      target_profile="main"
      encode_threads=4
      video_crf=23
      video_target_bitrate="4500k"
      video_maxrate="6000k"
      video_bufsize="9000k"
      audio_bitrate="128k"
      ;;
    performance)
      max_width=1920
      max_height=1080
      max_fps=60
      max_duration=720
      max_files=36
      max_level=41
      target_level_text="4.1"
      target_profile="main"
      encode_threads=6
      video_crf=22
      video_target_bitrate="6500k"
      video_maxrate="8500k"
      video_bufsize="12000k"
      audio_bitrate="160k"
      ;;
    extreme)
      max_width=1920
      max_height=1080
      max_fps=60
      max_duration=900
      max_files=48
      max_level=41
      target_level_text="4.1"
      target_profile="main"
      encode_threads=8
      video_crf=21
      video_target_bitrate="8000k"
      video_maxrate="10000k"
      video_bufsize="14000k"
      audio_bitrate="192k"
      ;;
    *)
      ;;
  esac

  if is_non_negative_integer "$ram_gb"; then
    if (( ram_gb <= 8 )); then
      if (( max_files > 16 )); then
        max_files=16
      fi
      if (( encode_threads > 3 )); then
        encode_threads=3
      fi
    elif (( ram_gb >= 32 )); then
      max_files=$((max_files + 2))
    fi
  fi

  local max_files_override="${STEAVIUM_MEDIA_COMPAT_MAX_FILES:-}"
  if is_non_negative_integer "$max_files_override" && (( max_files_override > 0 )); then
    max_files="$max_files_override"
  fi

  local max_duration_override="${STEAVIUM_MEDIA_COMPAT_MAX_DURATION:-}"
  if is_non_negative_integer "$max_duration_override" && (( max_duration_override > 0 )); then
    max_duration="$max_duration_override"
  fi

  local video_encoder="libx264"
  local hevc_encoder=""
  local encoder_list=""
  encoder_list="$(ffmpeg -hide_banner -encoders 2>/dev/null || true)"
  if printf '%s' "$encoder_list" | grep -qE '[[:space:]]h264_videotoolbox[[:space:]]'; then
    video_encoder="h264_videotoolbox"
  fi
  if printf '%s' "$encoder_list" | grep -qE '[[:space:]]hevc_videotoolbox[[:space:]]'; then
    hevc_encoder="hevc_videotoolbox"
  fi

  # Detect Apple Silicon for VideoToolbox optimisations.  All M-series
  # chips (M1-M5) include dedicated H.264 and H.265/HEVC encode/decode
  # hardware engines, so software fallback (allow_sw) is unnecessary
  # and -realtime 1 safely prioritises latency over quality.
  local chip_family="${STEAVIUM_DEVICE_CHIP_FAMILY:-${DEVICE_CHIP_FAMILY:-unknown}}"
  local is_apple_silicon=0
  case "$chip_family" in
    m1|m2|m3|m4|m5|appleSiliconOther) is_apple_silicon=1 ;;
  esac

  # Prefer HEVC (H.265) on Apple Silicon when hevc_videotoolbox is
  # available.  HEVC delivers ~30% better compression than H.264 at
  # equivalent visual quality, saving disk space in game directories.
  # Users can override via env variable:
  #   STEAVIUM_MEDIA_PREFER_HEVC=0  -> force H.264
  #   STEAVIUM_MEDIA_PREFER_HEVC=1  -> force HEVC
  local prefer_hevc="${STEAVIUM_MEDIA_PREFER_HEVC:-auto}"
  if [[ "$prefer_hevc" == "auto" ]]; then
    if (( is_apple_silicon )) && [[ -n "$hevc_encoder" ]]; then
      prefer_hevc=1
    else
      prefer_hevc=0
    fi
  fi

  # HEVC-specific bitrate targets: ~30% lower than H.264 equivalents
  # for the same perceived quality.
  local hevc_target_bitrate="$video_target_bitrate"
  local hevc_maxrate="$video_maxrate"
  local hevc_bufsize="$video_bufsize"
  if [[ "$prefer_hevc" == "1" ]]; then
    case "$profile" in
      economy)
        hevc_target_bitrate="1750k"; hevc_maxrate="2450k"; hevc_bufsize="3500k" ;;
      balanced)
        hevc_target_bitrate="3150k"; hevc_maxrate="4200k"; hevc_bufsize="6300k" ;;
      performance)
        hevc_target_bitrate="4550k"; hevc_maxrate="6000k"; hevc_bufsize="8400k" ;;
      extreme)
        hevc_target_bitrate="5600k"; hevc_maxrate="7000k"; hevc_bufsize="9800k" ;;
    esac
  fi

  local -a media_extensions=(mp4 m4v mov mkv m2ts mts ts avi wmv asf mpg mpeg)
  local media_extensions_csv="${media_extensions[*]}"
  media_extensions_csv="${media_extensions_csv// /,}"

  local compat_signature="profile=$profile;res=${max_width}x${max_height};fps=$max_fps;level=$max_level;duration=$max_duration;only_short=$only_short;exts=$media_extensions_csv;hevc=$prefer_hevc"

  echo "[media] Escaneando videos (${media_extensions_csv}) en rutas multimedia comunes (perfil=$profile, ram_gb=$ram_gb, limite=$max_files, encoder=$video_encoder, hevc=$prefer_hevc, dry_run=$dry_run)."

  local inspected=0
  local selected=0
  local converted=0
  local failed=0
  local skipped_long=0
  local skipped_cached=0
  local found_any=0

  local movie_file=""
  while IFS= read -r -d '' movie_file; do
    found_any=1
    inspected=$((inspected + 1))

    if (( selected >= max_files )); then
      break
    fi

    if [[ "$movie_file" == *.steavium-orig ]]; then
      continue
    fi

    local extension="${movie_file##*.}"
    if [[ "$extension" == "$movie_file" ]]; then
      extension="mp4"
    fi
    local extension_lower=""
    extension_lower="$(printf '%s' "$extension" | tr '[:upper:]' '[:lower:]')"

    local target_video_codec="h264"
    local target_audio_codec="aac"
    local enforce_h264_profile_level=1
    case "$extension_lower" in
      wmv|asf)
        target_video_codec="wmv2"
        target_audio_codec="wmav2"
        enforce_h264_profile_level=0
        ;;
      avi)
        target_video_codec="mpeg4"
        target_audio_codec="mp3"
        enforce_h264_profile_level=0
        ;;
      mpg|mpeg)
        target_video_codec="mpeg2video"
        target_audio_codec="mp2"
        enforce_h264_profile_level=0
        ;;
      *)
        ;;
    esac

    local normalized_marker="${movie_file}.steavium-normalized"
    local checked_marker="${movie_file}.steavium-checked"
    if [[ -f "$normalized_marker" && "$normalized_marker" -nt "$movie_file" ]]; then
      local normalized_signature=""
      normalized_signature="$(head -n 1 "$normalized_marker" 2>/dev/null || true)"
      if [[ "$normalized_signature" == "$compat_signature" ]]; then
        skipped_cached=$((skipped_cached + 1))
        continue
      fi
    fi
    if [[ -f "$checked_marker" && "$checked_marker" -nt "$movie_file" ]]; then
      local checked_signature=""
      checked_signature="$(head -n 1 "$checked_marker" 2>/dev/null || true)"
      if [[ "$checked_signature" == "$compat_signature" ]]; then
        skipped_cached=$((skipped_cached + 1))
        continue
      fi
    fi

    local video_codec=""
    local width=""
    local height=""
    local level=""
    local profile_name=""
    local fps_rate=""
    local pix_fmt=""
    while IFS='=' read -r key value; do
      case "$key" in
        codec_name)
          video_codec="$value"
          ;;
        width)
          width="$value"
          ;;
        height)
          height="$value"
          ;;
        level)
          level="$value"
          ;;
        profile)
          profile_name="$value"
          ;;
        r_frame_rate)
          fps_rate="$value"
          ;;
        pix_fmt)
          pix_fmt="$value"
          ;;
      esac
    done < <(
      ffprobe -v error -select_streams v:0 \
        -show_entries stream=codec_name,width,height,level,profile,r_frame_rate,pix_fmt \
        -of default=noprint_wrappers=1 "$movie_file" 2>/dev/null || true
    )

    if [[ -z "$video_codec" || -z "$width" || -z "$height" || -z "$fps_rate" ]]; then
      continue
    fi

    local audio_codec=""
    audio_codec="$(
      ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
        -of csv=p=0 "$movie_file" 2>/dev/null | head -n 1 || true
    )"

    local duration_seconds=""
    duration_seconds="$(
      ffprobe -v error -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$movie_file" 2>/dev/null | tr -d '\r' | head -n 1 || true
    )"

    local fps="0"
    fps="$(parse_ffprobe_fps "$fps_rate")"

    if [[ "$only_short" == "1" ]] && is_non_negative_float "$duration_seconds" \
      && float_greater_than "$duration_seconds" "$max_duration"; then
      skipped_long=$((skipped_long + 1))
      continue
    fi

    local needs_reencode=0
    local -a reasons=()

    if [[ "$video_codec" != "$target_video_codec" ]]; then
      needs_reencode=1
      reasons+=("vcodec=$video_codec->$target_video_codec")
    fi

    if [[ -n "$audio_codec" && "$audio_codec" != "$target_audio_codec" ]]; then
      needs_reencode=1
      reasons+=("acodec=$audio_codec->$target_audio_codec")
    fi

    if [[ "$pix_fmt" != "yuv420p" ]]; then
      needs_reencode=1
      reasons+=("pix_fmt=$pix_fmt")
    fi

    if (( enforce_h264_profile_level == 1 )); then
      if [[ -n "$profile_name" && ! "$profile_name" =~ ^(High|Main|Baseline|Constrained[[:space:]]Baseline)$ ]]; then
        needs_reencode=1
        reasons+=("profile=$profile_name")
      fi
    fi

    if is_non_negative_integer "$width" && is_non_negative_integer "$height"; then
      if (( width > max_width || height > max_height )); then
        needs_reencode=1
        reasons+=("res=${width}x${height}")
      fi
    fi

    if (( enforce_h264_profile_level == 1 )); then
      if is_non_negative_integer "$level" && (( level > max_level )); then
        needs_reencode=1
        reasons+=("level=$level")
      fi
    fi

    if is_non_negative_float "$fps" && float_greater_than "$fps" "$max_fps"; then
      needs_reencode=1
      reasons+=("fps=$fps->$max_fps")
    fi

    if (( needs_reencode == 0 )); then
      if [[ "$dry_run" != "1" ]]; then
        printf '%s\n' "$compat_signature" > "$checked_marker" 2>/dev/null || true
      fi
      continue
    fi

    selected=$((selected + 1))
    local reason_text="${reasons[*]}"

    if [[ "$dry_run" == "1" ]]; then
      echo "[media] Candidato: $movie_file ($reason_text)"
      continue
    fi

    local backup_file="${movie_file}.steavium-orig"
    if [[ ! -f "$backup_file" ]]; then
      if ! cp -p "$movie_file" "$backup_file"; then
        failed=$((failed + 1))
        echo "[media] No se pudo crear backup: $backup_file"
        continue
      fi
    fi

    local tmp_file="${movie_file}.steavium-tmp.$$.$extension"
    # Only apply fps filter when the source exceeds max_fps to avoid
    # unnecessary framerate conversion that causes judder/stuttering.
    local video_filter="scale='min(iw,${max_width})':'min(ih,${max_height})':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2"
    local needs_fps_limit=0
    if is_non_negative_float "$fps" && float_greater_than "$fps" "$max_fps"; then
      video_filter="scale='min(iw,${max_width})':'min(ih,${max_height})':force_original_aspect_ratio=decrease,fps=${max_fps},scale=trunc(iw/2)*2:trunc(ih/2)*2"
      needs_fps_limit=1
    fi
    local -a muxer_tuning_flags=()
    local -a video_codec_flags=()
    local -a audio_codec_flags=()
    case "$extension_lower" in
      mp4|m4v|mov)
        muxer_tuning_flags=(-movflags +faststart)
        ;;
      *)
        ;;
    esac

    case "$target_video_codec" in
      h264)
        if (( is_apple_silicon )) && [[ "$prefer_hevc" == "1" ]] \
          && [[ -n "$hevc_encoder" ]] \
          && [[ "$extension_lower" =~ ^(mp4|m4v|mov|mkv)$ ]]; then
          # HEVC via VideoToolbox — M1-M5 all have dedicated HEVC
          # encode hardware.  ~30% bitrate savings at equivalent quality.
          video_codec_flags=(
            -c:v hevc_videotoolbox
            -allow_sw 0
            -realtime 1
            -profile:v main
            -tag:v hvc1
            -b:v "$hevc_target_bitrate"
            -maxrate "$hevc_maxrate"
            -bufsize "$hevc_bufsize"
          )
        elif [[ "$video_encoder" == "h264_videotoolbox" ]]; then
          video_codec_flags=(
            -c:v h264_videotoolbox
            -profile:v "$target_profile"
            -level:v "$target_level_text"
            -b:v "$video_target_bitrate"
            -maxrate "$video_maxrate"
            -bufsize "$video_bufsize"
          )
          if (( is_apple_silicon )); then
            # M1-M5: dedicated H.264 encode hardware — no need for
            # software fallback; prefer low-latency mode.
            video_codec_flags+=(-allow_sw 0 -realtime 1)
          else
            video_codec_flags+=(-allow_sw 1)
          fi
        else
          video_codec_flags=(
            -c:v libx264
            -preset veryfast
            -crf "$video_crf"
            -profile:v "$target_profile"
            -level:v "$target_level_text"
          )
        fi
        ;;
      wmv2)
        video_codec_flags=(
          -c:v wmv2
          -q:v 3
        )
        ;;
      mpeg4)
        video_codec_flags=(
          -c:v mpeg4
          -q:v 4
        )
        ;;
      mpeg2video)
        video_codec_flags=(
          -c:v mpeg2video
          -q:v 3
          -maxrate "$video_maxrate"
          -bufsize "$video_bufsize"
        )
        ;;
      *)
        video_codec_flags=(
          -c:v libx264
          -preset veryfast
          -crf "$video_crf"
          -profile:v "$target_profile"
          -level:v "$target_level_text"
        )
        ;;
    esac

    case "$target_audio_codec" in
      aac)
        audio_codec_flags=(
          -c:a aac
          -b:a "$audio_bitrate"
          -ar 48000
          -ac 2
        )
        ;;
      wmav2)
        audio_codec_flags=(
          -c:a wmav2
          -b:a "$audio_bitrate"
          -ar 44100
          -ac 2
        )
        ;;
      mp3)
        audio_codec_flags=(
          -c:a mp3
          -b:a "$audio_bitrate"
          -ar 44100
          -ac 2
        )
        ;;
      mp2)
        audio_codec_flags=(
          -c:a mp2
          -b:a "$audio_bitrate"
          -ar 48000
          -ac 2
        )
        ;;
      *)
        audio_codec_flags=(
          -c:a aac
          -b:a "$audio_bitrate"
          -ar 48000
          -ac 2
        )
        ;;
    esac

    local -a ffmpeg_cmd=(
      ffmpeg -hide_banner -loglevel error -nostdin -y -threads "$encode_threads"
      -i "$movie_file" -map 0:v:0 -map 0:a:0?
    )
    ffmpeg_cmd+=("${video_codec_flags[@]}")
    ffmpeg_cmd+=(
      -pix_fmt yuv420p
      -vf "$video_filter"
    )
    # Only force output framerate when source exceeds max_fps.
    # Forcing framerate on videos already at or below the cap creates
    # uneven frame timing (e.g. 24fps→30fps causes 3:2 pulldown judder).
    if (( needs_fps_limit == 1 )); then
      ffmpeg_cmd+=(-r "$max_fps")
    fi
    ffmpeg_cmd+=("${audio_codec_flags[@]}")
    if (( ${#muxer_tuning_flags[@]} > 0 )); then
      ffmpeg_cmd+=("${muxer_tuning_flags[@]}")
    fi
    ffmpeg_cmd+=("$tmp_file")

    if "${ffmpeg_cmd[@]}"; then
      mv "$tmp_file" "$movie_file"
      printf '%s\n' "$compat_signature" > "$normalized_marker" 2>/dev/null || true
      printf '%s\n' "$compat_signature" > "$checked_marker" 2>/dev/null || true
      converted=$((converted + 1))
      echo "[media] Normalizado: $movie_file ($reason_text)"
    else
      rm -f "$tmp_file" 2>/dev/null || true
      failed=$((failed + 1))
      echo "[media] Error al normalizar: $movie_file"
    fi
  done < <(
    find "$common_dir" -type f \
      \( \
        -iname "*.mp4" -o -iname "*.m4v" -o -iname "*.mov" -o -iname "*.mkv" -o \
        -iname "*.m2ts" -o -iname "*.mts" -o -iname "*.ts" -o -iname "*.avi" -o \
        -iname "*.wmv" -o -iname "*.asf" -o -iname "*.mpg" -o -iname "*.mpeg" \
      \) \
      \( \
        -ipath "*/movies/*" -o -ipath "*/movie/*" -o -ipath "*/videos/*" -o -ipath "*/video/*" -o \
        -ipath "*/media/*" -o \
        -ipath "*/cinematics/*" -o -ipath "*/cinematic/*" -o -ipath "*/cutscenes/*" -o -ipath "*/cutscene/*" -o \
        -ipath "*/trailers/*" -o -ipath "*/trailer/*" -o -ipath "*/intros/*" -o -ipath "*/intro/*" -o \
        -ipath "*/logos/*" -o -ipath "*/logo/*" -o \
        -iname "*intro*.mp4" -o -iname "*intro*.m4v" -o -iname "*intro*.mov" -o -iname "*intro*.mkv" -o \
        -iname "*intro*.m2ts" -o -iname "*intro*.mts" -o -iname "*intro*.ts" -o -iname "*intro*.avi" -o \
        -iname "*intro*.wmv" -o -iname "*intro*.asf" -o -iname "*opening*.mp4" -o -iname "*opening*.mkv" -o \
        -iname "*opening*.avi" -o -iname "*opening*.wmv" -o -iname "*splash*.mp4" -o -iname "*splash*.mov" -o \
        -iname "*splash*.avi" -o -iname "*splash*.wmv" -o -iname "*logo*.mp4" -o -iname "*logo*.mov" -o \
        -iname "*logo*.avi" -o -iname "*logo*.wmv" -o -iname "*startup*.mp4" -o -iname "*startup*.mkv" -o \
        -iname "*startup*.avi" -o -iname "*startup*.wmv" \
      \) \
      -print0 2>/dev/null
  )

  if [[ "$found_any" -eq 0 ]]; then
    echo "[media] No se detectaron videos compatibles en rutas multimedia comunes."
    return 0
  fi

  if [[ "$dry_run" == "1" ]]; then
    echo "[media] Simulacion completa: inspeccionados=$inspected candidatos=$selected omitidos_cache=$skipped_cached omitidos_largos=$skipped_long"
  else
    touch "$stamp_file" 2>/dev/null || true
    echo "[media] Normalizacion completa: inspeccionados=$inspected candidatos=$selected convertidos=$converted errores=$failed omitidos_cache=$skipped_cached omitidos_largos=$skipped_long"
  fi
}
