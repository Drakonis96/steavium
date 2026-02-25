<p align="center">
  <img src="logo.png" width="128" height="128" alt="Steavium logo" />
</p>

<h1 align="center">Steavium</h1>

<p align="center">
  <strong>Run Windows Steam on your Mac — optimized for Apple Silicon.</strong><br />
  A native macOS launcher that installs, configures, and runs Steam through Wine/CrossOver<br />
  with automatic hardware-aware performance tuning.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="macOS 14+" />
  <img src="https://img.shields.io/badge/arch-Apple%20Silicon-orange" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/swift-6.0-F05138" alt="Swift 6" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Option A — Download the DMG](#option-a--download-the-dmg)
  - [Option B — Build from Source](#option-b--build-from-source)
- [Getting Started](#getting-started)
- [Game Library Location](#game-library-location)
- [Per-Game Compatibility Profiles](#per-game-compatibility-profiles)
- [Graphics Backend](#graphics-backend)
- [Automatic Performance Tuning](#automatic-performance-tuning)
- [Media Compatibility](#media-compatibility)
- [CrossOver Mode](#crossover-mode)
- [Session Management](#session-management)
- [Data Management](#data-management)
- [Uninstallation](#uninstallation)
- [Building the Installer](#building-the-installer)
- [Project Structure](#project-structure)
- [Running Tests](#running-tests)
- [Known Limitations](#known-limitations)
- [License](#license)

---

## Features

- **Guided setup** — Install runtime, set up Steam, and launch — one click each.
- **Hardware detection** — Identifies your Apple chip (M1 through M5), RAM, CPU core topology (performance + efficiency cores), and display resolution.
- **Dynamic performance profiles** — Classifies your Mac as `economy`, `balanced`, `performance`, or `extreme` and tunes DXVK threads, frame rate caps, shader caches, and graphics backend accordingly.
- **Per-game compatibility profiles** — Set Windows compatibility mode, windowed mode, DPI overrides, reduced color depth, admin privileges, and more on a per-game basis.
- **CrossOver integration** — Automatically uses CrossOver when installed for better Steam UI compatibility; falls back to standalone Wine.
- **Multimedia fixer** — Scans game video files and re-encodes incompatible formats using hardware-accelerated VideoToolbox.
- **Custom game library** — Store games on an external drive or any custom folder. Reinstall the app later and point to the same folder to recover your entire library.
- **Gamepad support** — Detects connected controllers via the GameController framework and HID.
- **Bilingual UI** — Full English and Spanish interface.
- **Built-in uninstaller** — Remove Steavium cleanly from within the app, from the DMG, or manually.

---

## Requirements

| Requirement | Details |
|---|---|
| **macOS** | 14.0 (Sonoma) or later |
| **Architecture** | Apple Silicon (M1, M2, M3, M4, M5) |
| **Wine runtime** | [CrossOver](https://www.codeweavers.com/crossover) (recommended) or standalone Wine via [Homebrew](https://brew.sh) |
| **Build tools** | Xcode 16+ or Swift 6 toolchain *(only if building from source)* |
| **Internet** | Required on first run to download Homebrew packages and `SteamSetup.exe` |

---

## Installation

### Option A — Download the DMG

1. Download **`Steavium-Installer.dmg`** from the [Releases](../../releases) page.
2. Open the DMG.
3. Drag **Steavium.app** into the **Applications** folder.
4. Launch Steavium from Applications or Spotlight.

> **First launch:** macOS may show a Gatekeeper warning. Right-click the app → **Open** → **Open** to allow it.

### Option B — Build from Source

```bash
git clone https://github.com/Drakonis96/steavium.git
cd steavium

# Quick run (debug build)
swift build && swift run Steavium

# Or build a full .app bundle (release)
bash Installer/build_app.sh
open build/Steavium.app
```

---

## Getting Started

Steavium walks you through a simple three-step workflow:

### Step 1 — Install Runtime

Click **Install Runtime**. Steavium will:

- Detect if CrossOver is installed (preferred) or install Wine via Homebrew.
- Optionally install `ffmpeg` for multimedia compatibility.
- Run preflight checks: Homebrew availability, disk space, network connectivity, and runtime status.

### Step 2 — Set Up Steam

Click **Set Up Steam**. This will:

- Create a dedicated 64-bit Wine prefix.
- Download and silently run `SteamSetup.exe`.
- Build the Steam library folder structure (including symlinks if you chose a custom game library path).

### Step 3 — Launch Steam

Click **Launch Steam**. Steavium will:

- Apply your chosen graphics backend and hardware-tuned performance flags.
- Sync per-game compatibility profiles to the Wine registry.
- Run the multimedia compatibility pass on game video files.
- Start Steam and monitor the process with a real-time progress bar until its window appears.

---

## Game Library Location

By default, games are stored inside the Wine prefix:

```
~/Library/Application Support/Steavium/prefixes/steam/drive_c/Program Files (x86)/Steam/steamapps/
```

To use a **custom location** (e.g., an external drive):

1. Click **Choose Library** in the *Folders and Data* section.
2. Select any folder — Steavium creates a `SteaviumSteamLibrary` subfolder inside it.
3. Internal Steam folders (`common`, `downloading`, `workshop`, `shadercache`, `compatdata`) are symlinked to the external location.

### Recovering games after reinstall

If you uninstall and reinstall Steavium, or set up on a new machine:

1. Complete **Install Runtime** and **Set Up Steam**.
2. Click **Choose Library** and select the same folder you used before.
3. Launch Steam — it detects the existing game files automatically.

> **Your custom game library is never deleted** by any uninstall or wipe operation. Your games are always safe.

---

## Per-Game Compatibility Profiles

Steavium automatically discovers installed games by reading `steamapps/appmanifest_*.acf` manifests.

For each game you can configure:

| Setting | Description |
|---|---|
| **Windows compatibility mode** | Windows 95, 98/ME, XP SP2, XP SP3, Vista SP2, 7, or 8 |
| **Force windowed** | Adds `-windowed` to the game's Steam launch options |
| **Reduced color mode** | 8-bit or 16-bit color depth |
| **Force 640×480** | Low-resolution mode for legacy titles |
| **High DPI override** | Application-level DPI scaling |
| **Disable fullscreen optimizations** | Prevents compositing conflicts |
| **Run as administrator** | Elevated privilege emulation |

Profiles are saved to `~/Library/Application Support/Steavium/settings/game-profiles.json` and written to the Windows registry before each Steam launch:

```
HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers
```

Quick presets: **Automatic** · **Classic Mode** · **Windowed Safe** · **Custom**

---

## Graphics Backend

Choose the rendering backend before launching:

| Backend | Best for |
|---|---|
| **D3DMetal** | Most Apple Silicon Macs — Direct3D → Metal translation (recommended) |
| **DXVK** | Games that perform better on Vulkan (via MoltenVK), useful on higher-end configs |
| **Auto** | Steavium picks the best backend based on your chip family and RAM |

---

## Automatic Performance Tuning

Steavium profiles your hardware and applies optimized settings at launch:

| Parameter | Logic |
|---|---|
| `DXVK_NUM_COMPILER_THREADS` | 2–8 threads, based on performance tier, RAM, and available cores |
| `DXVK_FRAME_RATE` | 45 / 60 / 75 / 90 fps cap for stable frame pacing |
| `DXVK_STATE_CACHE` | Persistent shader cache to reduce stutter |
| `WINEESYNC` / `WINEFSYNC` | Enabled for lower synchronization overhead |
| `WINEMSYNC` | Enabled when running under CrossOver |
| `WINEDEBUG` | Set to `-all` for maximum performance |
| Steam overlay | Disabled in Vulkan mode to reduce input lag |
| Steam launch flags | `-no-dwrite -no-cef-sandbox` |

**Performance tiers:**

| Tier | Typical hardware |
|---|---|
| `economy` | M1 / M2 with 8 GB RAM |
| `balanced` | M1 Pro / M2 Pro / M3 with 16 GB |
| `performance` | M2 Max / M3 Pro / M4 with 24+ GB |
| `extreme` | M2 Ultra / M3 Max / M4 Pro+ with 32+ GB |

---

## Media Compatibility

Some game cutscenes use video formats that Wine cannot decode. Steavium runs an automatic media compatibility pass that:

- Scans common media folders (`Movies`, `Videos`, `Cutscenes`, `Cinematics`, `Intros`, etc.) and filename patterns (`intro`, `splash`, `logo`, etc.).
- Detects problematic codecs, 4K/60fps content, incompatible H.264 profiles, and mismatched containers.
- Re-encodes via **VideoToolbox** (hardware) or **libx264** (fallback) to: H.264 Main @ Level 4.1, 30 fps, AAC audio.
- Preserves originals as `*.steavium-orig` backups.

**Run the media pass independently:**

```bash
# Full pass (without launching Steam)
bash Sources/Resources/scripts/launch_steam.sh --media-compat-only

# Dry run (preview changes without writing)
bash Sources/Resources/scripts/launch_steam.sh --media-compat-only --media-dry-run
```

**Environment overrides:**

| Variable | Description |
|---|---|
| `STEAVIUM_MEDIA_COMPAT_MAX_FILES` | Max files to process per pass |
| `STEAVIUM_MEDIA_COMPAT_MAX_DURATION` | Max video duration (seconds) in short-only mode |
| `STEAVIUM_MEDIA_COMPAT_COOLDOWN_MINUTES` | Minimum wait between passes (default: `0`) |

---

## CrossOver Mode

When [CrossOver](https://www.codeweavers.com/crossover) is installed, Steavium uses it as the preferred runtime with a dedicated bottle:

| Property | Value |
|---|---|
| Bottle name | `steavium-steam` |
| Template | `win10_64` (64-bit) |
| Location | `~/Library/Application Support/CrossOver/Bottles/steavium-steam` |

This provides better Steam UI rendering and stability compared to standalone Wine.

---

## Session Management

- **Steam already running?** Steavium asks whether to **reuse** the current session or **restart** Steam cleanly.
- **Steam updates:** After a Steam version change, a one-time update may occur. Subsequent launches skip it.
- **Real-time monitoring:** The progress bar tracks each phase — environment prep → process spawn → waiting for window → done.

---

## Data Management

### Selective wipe

From the **Wipe Data** dialog you can choose:

| Option | What it removes |
|---|---|
| **Account data** | Steam session, login cache, local user data |
| **Library data** | `steamapps`, workshop files, shader cache |

Your custom game library folder is never affected.

### Diagnostics export

Click **Export Diagnostics** to generate a `.zip` bundle containing hardware profile, environment details, preflight results, in-app console log, and recent Steam logs.

---

## Uninstallation

Steavium can be removed in three ways:

### From within the app

1. Click the **⋯** menu in the top-right header area.
2. Select **Uninstall Steavium**.
3. Confirm in the dialog.

The app removes all settings, preferences, Wine prefixes, caches, and saved state, moves itself to the Trash, and quits.

### Using the standalone script

From the DMG or the source repository:

```bash
bash Installer/uninstall_steavium.sh
```

The script interactively confirms and then removes:

- `/Applications/Steavium.app`
- `~/Library/Application Support/Steavium/`
- UserDefaults and saved application state
- Application caches

### Manual removal

1. Delete **Steavium.app** from `/Applications`.
2. Delete `~/Library/Application Support/Steavium/`.
3. Optionally remove the CrossOver bottle: `~/Library/Application Support/CrossOver/Bottles/steavium-steam/`.

> **Your custom game library folder is never deleted** by any uninstall method. Your games are always safe.

---

## Building the Installer

Create a distributable DMG from source:

```bash
# 1. Build the .app bundle (Release, arm64, with icon and resources)
bash Installer/build_app.sh

# 2. Package into a DMG (drag-to-install layout + uninstaller)
bash Installer/create_dmg.sh
```

Output:

| File | Description |
|---|---|
| `build/Steavium.app` | The macOS application bundle |
| `build/Steavium-Installer.dmg` | Distributable DMG with app, Applications shortcut, and uninstaller |

---

## Project Structure

```
steavium/
├── Sources/
│   ├── SteaviumApp.swift              # App entry point
│   ├── ContentView.swift              # Main window layout
│   ├── SteamViewModel.swift           # UI state and business logic
│   ├── SteamManager.swift             # Core Steam/Wine management (actor)
│   ├── SteamManaging.swift            # Protocol for testability
│   ├── SteamManagerError.swift        # Error types
│   ├── Models.swift                   # Data models and enums
│   ├── GameLibraryScanner.swift       # Game discovery from Steam manifests
│   ├── GameProfilePersistence.swift   # Per-game profile I/O
│   ├── GameProfileEditor.swift        # Profile editor UI state
│   ├── GamepadMonitor.swift           # Controller detection
│   ├── HardwareTuningAdvisor.swift    # Performance tier logic
│   ├── RuntimePreflight.swift         # System readiness checks
│   ├── ValveKeyValue.swift            # Valve VDF file parser
│   ├── ShellRunner.swift              # Shell command executor
│   ├── Localization.swift             # Language enum
│   ├── StringCatalog.swift            # All localized strings (EN/ES)
│   ├── SharedComponents.swift         # Reusable SwiftUI components
│   ├── ActionPanel.swift              # Action buttons panel
│   ├── StatusPanel.swift              # Environment status tiles
│   ├── PreflightPanel.swift           # Preflight checks display
│   ├── GameProfilesPanel.swift        # Game list and profile editor
│   ├── LogPanel.swift                 # Console log viewer
│   ├── UserManualSheet.swift          # Built-in documentation
│   ├── WipeDataSheet.swift            # Data wipe dialog
│   └── Resources/
│       ├── logo.png                   # App icon source image
│       └── scripts/
│           ├── common.sh              # Shared shell functions
│           ├── install_runtime.sh     # Runtime installation
│           ├── setup_steam.sh         # Steam setup
│           ├── launch_steam.sh        # Steam launch + media compat
│           ├── stop_steam.sh          # Graceful Steam shutdown
│           └── wipe_steam_data.sh     # Selective data wipe
├── Tests/                             # 60 unit tests
├── Installer/
│   ├── build_app.sh                   # Builds Steavium.app
│   ├── create_dmg.sh                  # Creates DMG installer
│   ├── uninstall_steavium.sh          # Standalone uninstaller
│   └── Info.plist                     # App bundle metadata
├── Package.swift                      # Swift Package Manager manifest
├── LICENSE                            # MIT License
└── README.md
```

---

## Running Tests

```bash
swift test
```

The test suite (60 tests) covers:

- Valve VDF file parsing
- Game library scanning and manifest parsing
- Per-game compatibility profile persistence and composition
- Game launch options generation
- Hardware tuning advisor tier classification
- Runtime preflight validation
- Steam launch flow state machine

---

## Known Limitations

- Does **not** bundle its own Wine — relies on CrossOver or a system-installed Wine.
- Game compatibility depends on the Wine/CrossOver version and each individual title.
- No per-title performance telemetry yet.
- Not code-signed or notarized — macOS Gatekeeper will prompt on first launch.

---

## License

[MIT License](LICENSE) — Copyright © 2026 Drakonis96
