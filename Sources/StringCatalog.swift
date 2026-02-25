import Foundation

// MARK: - Localized entry type

struct LocalizedEntry: Sendable {
    let english: String
    let spanish: String

    func resolve(in language: AppLanguage) -> String {
        language.pick(english, spanish)
    }
}

// MARK: - Centralized string catalog

// swiftlint:disable type_body_length
enum L {

    // MARK: General / Common

    static let ready = LocalizedEntry(
        english: "Ready.",
        spanish: "Listo."
    )
    static let cancel = LocalizedEntry(
        english: "Cancel",
        spanish: "Cancelar"
    )
    static let close = LocalizedEntry(
        english: "Close",
        spanish: "Cerrar"
    )
    static let yes = LocalizedEntry(
        english: "Yes",
        spanish: "Si"
    )
    static let no = LocalizedEntry(
        english: "No",
        spanish: "No"
    )
    static let save = LocalizedEntry(
        english: "Save",
        spanish: "Guardar"
    )
    static let select = LocalizedEntry(
        english: "Select",
        spanish: "Seleccionar"
    )
    static let notDetected = LocalizedEntry(
        english: "Not detected",
        spanish: "No detectado"
    )
    static let unknown = LocalizedEntry(
        english: "Unknown",
        spanish: "Desconocido"
    )
    static let disabled = LocalizedEntry(
        english: "Disabled",
        spanish: "Desactivado"
    )
    static let application = LocalizedEntry(
        english: "Application",
        spanish: "Aplicacion"
    )
    static let noOutput = LocalizedEntry(
        english: "(no output)",
        spanish: "(sin salida)"
    )

    // MARK: Language picker

    static let language = LocalizedEntry(
        english: "Language",
        spanish: "Idioma"
    )

    // MARK: Status / Header

    static let status = LocalizedEntry(
        english: "Status",
        spanish: "Estado"
    )
    static let backend = LocalizedEntry(
        english: "Backend",
        spanish: "Backend"
    )
    static let gamepads = LocalizedEntry(
        english: "Gamepads",
        spanish: "Gamepads"
    )
    static let appSubtitle = LocalizedEntry(
        english: "macOS launcher (Apple Silicon) optimized for Windows Steam",
        spanish: "Launcher macOS (Apple Silicon) optimizado para Steam de Windows"
    )
    static let openManual = LocalizedEntry(
        english: "Open Manual",
        spanish: "Abrir Manual"
    )

    // MARK: Working / Progress

    static let working = LocalizedEntry(
        english: "Working...",
        spanish: "Procesando..."
    )
    static func inProgress(_ title: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(title) in progress...",
            spanish: "\(title) en curso..."
        )
    }
    static func completed(_ title: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(title) completed.",
            spanish: "\(title) completada."
        )
    }
    static func failed(_ title: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(title) failed.",
            spanish: "\(title) fallo."
        )
    }
    static func errorSuffix(_ title: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(title) (error)",
            spanish: "\(title) (error)"
        )
    }

    // MARK: Environment Status

    static let environmentStatus = LocalizedEntry(
        english: "Environment Status",
        spanish: "Estado del entorno"
    )
    static let wineRuntime = LocalizedEntry(
        english: "Wine Runtime",
        spanish: "Runtime Wine"
    )
    static let steamInstalled = LocalizedEntry(
        english: "Steam Installed",
        spanish: "Steam instalado"
    )
    static let detectedChip = LocalizedEntry(
        english: "Detected Chip",
        spanish: "Chip detectado"
    )
    static let cpuCores = LocalizedEntry(
        english: "CPU Cores",
        spanish: "Nucleos CPU"
    )
    static let resolution = LocalizedEntry(
        english: "Resolution",
        spanish: "Resolucion"
    )
    static let hwProfile = LocalizedEntry(
        english: "HW Profile",
        spanish: "Perfil HW"
    )
    static let autoTuning = LocalizedEntry(
        english: "Auto Tuning",
        spanish: "Auto tuning"
    )
    static let library = LocalizedEntry(
        english: "Library",
        spanish: "Biblioteca"
    )
    static let gameProfiles = LocalizedEntry(
        english: "Game Profiles",
        spanish: "Perfiles juego"
    )
    static let preflight = LocalizedEntry(
        english: "Preflight",
        spanish: "Preflight"
    )

    // MARK: Auto tuning summaries

    static func autoTuningWithCap(_ backend: String, _ threads: Int, _ fps: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "Backend \(backend), DXVK threads \(threads), \(fps) FPS cap",
            spanish: "Backend \(backend), hilos DXVK \(threads), cap \(fps) FPS"
        )
    }
    static func autoTuningNoCap(_ backend: String, _ threads: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "Backend \(backend), DXVK threads \(threads), no FPS cap",
            spanish: "Backend \(backend), hilos DXVK \(threads), sin cap FPS"
        )
    }

    // MARK: Preflight

    static let runtimePreflight = LocalizedEntry(
        english: "Runtime Preflight",
        spanish: "Preflight de runtime"
    )
    static let runPreflight = LocalizedEntry(
        english: "Run Preflight",
        spanish: "Ejecutar preflight"
    )
    static let noPreflightData = LocalizedEntry(
        english: "No preflight data yet. Run a check before installing runtime.",
        spanish: "Aun no hay datos de preflight. Ejecuta el chequeo antes de instalar el runtime."
    )
    static let openHomebrewGuide = LocalizedEntry(
        english: "Open Homebrew Guide",
        spanish: "Abrir guia de Homebrew"
    )
    static let installFfmpeg = LocalizedEntry(
        english: "Install ffmpeg",
        spanish: "Instalar ffmpeg"
    )
    static let openAppFolder = LocalizedEntry(
        english: "Open App Folder",
        spanish: "Abrir carpeta de la app"
    )
    static let retryCheck = LocalizedEntry(
        english: "Retry Check",
        spanish: "Reintentar chequeo"
    )
    static let preflightRefreshed = LocalizedEntry(
        english: "Preflight refreshed.",
        spanish: "Preflight actualizado."
    )
    static let preflightNotRunYet = LocalizedEntry(
        english: "Not run yet",
        spanish: "Sin ejecutar"
    )
    static func preflightSummary(ok: Int, warnings: Int, failed: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(ok) OK, \(warnings) warnings, \(failed) failed",
            spanish: "\(ok) OK, \(warnings) avisos, \(failed) error"
        )
    }

    // MARK: Actions

    static let actions = LocalizedEntry(
        english: "Actions",
        spanish: "Acciones"
    )
    static let setup = LocalizedEntry(
        english: "Setup",
        spanish: "Configuracion"
    )
    static let utilities = LocalizedEntry(
        english: "Utilities",
        spanish: "Utilidades"
    )
    static let foldersAndData = LocalizedEntry(
        english: "Folders and Data",
        spanish: "Carpetas y datos"
    )

    // MARK: Action buttons

    static let installRuntime = LocalizedEntry(
        english: "Install Runtime",
        spanish: "Instalar Runtime"
    )
    static let setUpSteam = LocalizedEntry(
        english: "Set Up Steam",
        spanish: "Preparar Steam"
    )
    static let launchSteam = LocalizedEntry(
        english: "Launch Steam",
        spanish: "Lanzar Steam"
    )
    static let closeSteam = LocalizedEntry(
        english: "Close Steam",
        spanish: "Cerrar Steam"
    )
    static let refresh = LocalizedEntry(
        english: "Refresh",
        spanish: "Refrescar"
    )
    static let exportDiagnostics = LocalizedEntry(
        english: "Export Diagnostics",
        spanish: "Exportar diagnostico"
    )
    static let refreshGamepads = LocalizedEntry(
        english: "Refresh Gamepads",
        spanish: "Refrescar Gamepads"
    )
    static let clearConsole = LocalizedEntry(
        english: "Clear Console",
        spanish: "Limpiar Consola"
    )
    static let chooseLibrary = LocalizedEntry(
        english: "Choose Library",
        spanish: "Elegir Biblioteca"
    )
    static let clearLibrary = LocalizedEntry(
        english: "Clear Library",
        spanish: "Limpiar Biblioteca"
    )
    static let openLibrary = LocalizedEntry(
        english: "Open Library",
        spanish: "Abrir Biblioteca"
    )
    static let openPrefix = LocalizedEntry(
        english: "Open Prefix",
        spanish: "Abrir Prefix"
    )
    static let openLogs = LocalizedEntry(
        english: "Open Logs",
        spanish: "Abrir Logs"
    )
    static let wipeData = LocalizedEntry(
        english: "Wipe Data",
        spanish: "Borrar Datos"
    )

    // MARK: Steam running dialog

    static let closeSteamCompletely = LocalizedEntry(
        english: "Close Steam completely",
        spanish: "Cerrar Steam por completo"
    )
    static let closeSteamMessage = LocalizedEntry(
        english: "Steam and related processes from the current bottle/prefix will be closed.",
        spanish: "Se cerraran Steam y procesos asociados del entorno actual (bottle/prefix)."
    )
    static let steamAlreadyRunning = LocalizedEntry(
        english: "Steam is already running",
        spanish: "Steam ya esta ejecutandose"
    )
    static let reuse = LocalizedEntry(
        english: "Reuse",
        spanish: "Reusar"
    )
    static let restart = LocalizedEntry(
        english: "Restart",
        spanish: "Reiniciar"
    )
    static let steamRunningMessage = LocalizedEntry(
        english: "You can reuse the current session or restart Steam for a clean state.",
        spanish: "Puedes reusar la sesion actual o reiniciar Steam para un estado limpio."
    )

    // MARK: Sidebar toggles

    static let toggleLeftSidebar = LocalizedEntry(
        english: "Toggle Left Sidebar",
        spanish: "Mostrar u ocultar sidebar izquierdo"
    )
    static let leftSidebar = LocalizedEntry(
        english: "Left sidebar",
        spanish: "Sidebar izquierdo"
    )
    static let toggleRightSidebar = LocalizedEntry(
        english: "Toggle Right Sidebar",
        spanish: "Mostrar u ocultar sidebar derecho"
    )
    static let rightSidebar = LocalizedEntry(
        english: "Right sidebar",
        spanish: "Sidebar derecho"
    )

    // MARK: Log panel

    static let console = LocalizedEntry(
        english: "Console",
        spanish: "Consola"
    )
    static let noRunsYet = LocalizedEntry(
        english: "No runs yet.",
        spanish: "Sin ejecuciones todavia."
    )

    // MARK: Wipe data sheet

    static let selectiveDataWipe = LocalizedEntry(
        english: "Selective Data Wipe",
        spanish: "Borrado Selectivo de Datos"
    )
    static let wipeDataWarning = LocalizedEntry(
        english: "Select what you want to remove. This action cannot be undone.",
        spanish: "Selecciona que deseas borrar. Esta accion es irreversible."
    )
    static let removeAccountData = LocalizedEntry(
        english: "Remove Steam account data (session, user, and caches)",
        spanish: "Borrar datos de cuenta Steam (sesion, usuario y caches)"
    )
    static let removeLibraryData = LocalizedEntry(
        english: "Remove game library and local game data",
        spanish: "Borrar biblioteca de juegos y datos locales"
    )
    static let deleteSelection = LocalizedEntry(
        english: "Delete Selection",
        spanish: "Borrar Seleccion"
    )
    static let confirmDataWipe = LocalizedEntry(
        english: "Confirm data wipe",
        spanish: "Confirmar borrado de datos"
    )
    static let wipeConfirmMessage = LocalizedEntry(
        english: "This action permanently removes the selected Steam data. Continue?",
        spanish: "Esta accion elimina permanentemente los datos de Steam seleccionados. Continuar?"
    )

    // MARK: Game profiles

    static let perGameProfiles = LocalizedEntry(
        english: "Per-Game Compatibility Profiles",
        spanish: "Perfiles de compatibilidad por juego"
    )
    static let detectGames = LocalizedEntry(
        english: "Detect Games",
        spanish: "Detectar Juegos"
    )
    static let searchByNameOrAppID = LocalizedEntry(
        english: "Search by name or AppID",
        spanish: "Buscar por nombre o AppID"
    )
    static let onlySavedProfiles = LocalizedEntry(
        english: "Only saved profiles",
        spanish: "Solo perfiles guardados"
    )
    static let noInstalledGames = LocalizedEntry(
        english: "No installed games were detected. Launch Steam, then press Detect Games again.",
        spanish: "No se detectaron juegos instalados. Lanza Steam y vuelve a pulsar Detectar Juegos."
    )
    static let noMatchingGames = LocalizedEntry(
        english: "No games match the current filters.",
        spanish: "No hay juegos que coincidan con los filtros actuales."
    )
    static let savedProfile = LocalizedEntry(
        english: "Saved profile",
        spanish: "Perfil guardado"
    )
    static func filteredGamesSummary(shown: Int, total: Int, profilesSummary: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(shown) shown of \(total) games (\(profilesSummary))",
            spanish: "\(shown) mostrados de \(total) juegos (\(profilesSummary))"
        )
    }
    static func gameProfilesSummary(games: Int, profiles: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(games) games detected, \(profiles) active profiles",
            spanish: "\(games) juegos detectados, \(profiles) perfiles activos"
        )
    }

    // MARK: Game profile editor

    static func targetResolution(_ resolution: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Target resolution: \(resolution)",
            spanish: "Resolucion orientativa: \(resolution)"
        )
    }
    static let preset = LocalizedEntry(
        english: "Preset",
        spanish: "Preset"
    )
    static let compatibilityMode = LocalizedEntry(
        english: "Compatibility Mode",
        spanish: "Modo de compatibilidad"
    )
    static let executable = LocalizedEntry(
        english: "Executable",
        spanish: "Ejecutable"
    )
    static let noExecutableFound = LocalizedEntry(
        english: "No executable was found for this game. Only launch options will be applied.",
        spanish: "No se encontro ejecutable para este juego. Solo se aplicaran opciones de lanzamiento."
    )
    static let forceWindowed = LocalizedEntry(
        english: "Force windowed mode (-windowed)",
        spanish: "Forzar modo ventana (-windowed)"
    )
    static let force640x480 = LocalizedEntry(
        english: "Force 640 x 480",
        spanish: "Forzar 640 x 480"
    )
    static let reducedColor = LocalizedEntry(
        english: "Reduced Color",
        spanish: "Color reducido"
    )
    static let highDPIOverride = LocalizedEntry(
        english: "High DPI Override",
        spanish: "Override DPI alto"
    )
    static let disableFullscreenOpt = LocalizedEntry(
        english: "Disable fullscreen optimizations",
        spanish: "Desactivar optimizaciones de pantalla completa"
    )
    static let runAsAdmin = LocalizedEntry(
        english: "Run as administrator",
        spanish: "Ejecutar como administrador"
    )
    static let saveProfile = LocalizedEntry(
        english: "Save Profile",
        spanish: "Guardar Perfil"
    )
    static let reset = LocalizedEntry(
        english: "Reset",
        spanish: "Restablecer"
    )
    static let openFolder = LocalizedEntry(
        english: "Open Folder",
        spanish: "Abrir Carpeta"
    )
    static let selectGameToEdit = LocalizedEntry(
        english: "Select a game to edit its compatibility profile.",
        spanish: "Selecciona un juego para editar su perfil de compatibilidad."
    )

    // MARK: ViewModel action titles

    static let runtimeInstallation = LocalizedEntry(
        english: "Runtime installation",
        spanish: "Instalacion de runtime"
    )
    static let steamSetup = LocalizedEntry(
        english: "Steam setup",
        spanish: "Configuracion de Steam"
    )
    static let steamLaunch = LocalizedEntry(
        english: "Steam launch",
        spanish: "Lanzamiento de Steam"
    )
    static let steamLaunchCanceled = LocalizedEntry(
        english: "Steam launch canceled.",
        spanish: "Lanzamiento de Steam cancelado."
    )

    // MARK: Launch phase strings

    static let launchPhasePreparing = LocalizedEntry(
        english: "Preparing environment...",
        spanish: "Preparando entorno..."
    )
    static let launchPhaseSpawning = LocalizedEntry(
        english: "Starting Steam process...",
        spanish: "Iniciando proceso de Steam..."
    )
    static func launchPhaseWaiting(_ seconds: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "Waiting for Steam window... (\(seconds)s)",
            spanish: "Esperando ventana de Steam... (\(seconds)s)"
        )
    }
    static let launchPhaseSteamDetected = LocalizedEntry(
        english: "Steam is running!",
        spanish: "Steam esta en ejecucion!"
    )
    static func launchPhaseProcessStarted(_ seconds: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "Steam process started, loading UI... (\(seconds)s)",
            spanish: "Proceso de Steam iniciado, cargando interfaz... (\(seconds)s)"
        )
    }
    static let steamLaunchSuccess = LocalizedEntry(
        english: "Steam launched successfully.",
        spanish: "Steam se lanzo correctamente."
    )
    static let steamLaunchTimedOut = LocalizedEntry(
        english: "Steam process started. The window may take a moment to appear.",
        spanish: "Proceso de Steam iniciado. La ventana puede tardar un momento en aparecer."
    )
    static let launchingLabel = LocalizedEntry(
        english: "Launching...",
        spanish: "Lanzando..."
    )
    static let clearLogs = LocalizedEntry(
        english: "Clear",
        spanish: "Limpiar"
    )
    static let copyLogs = LocalizedEntry(
        english: "Copy",
        spanish: "Copiar"
    )
    static let logsCopied = LocalizedEntry(
        english: "Logs copied to clipboard.",
        spanish: "Logs copiados al portapapeles."
    )
    static let liveLogSuffix = LocalizedEntry(
        english: "live",
        spanish: "en vivo"
    )

    static let completeSteamShutdown = LocalizedEntry(
        english: "Complete Steam shutdown",
        spanish: "Cierre completo de Steam"
    )
    static let dataWipe = LocalizedEntry(
        english: "Data wipe",
        spanish: "Borrado de datos"
    )
    static let perGameProfileSave = LocalizedEntry(
        english: "Per-game profile save",
        spanish: "Guardado de perfil por juego"
    )
    static let perGameProfileReset = LocalizedEntry(
        english: "Per-game profile reset",
        spanish: "Restablecer perfil por juego"
    )
    static let ffmpegInstallation = LocalizedEntry(
        english: "ffmpeg installation",
        spanish: "Instalacion de ffmpeg"
    )
    static let diagnosticsExport = LocalizedEntry(
        english: "Diagnostics export",
        spanish: "Exportacion de diagnostico"
    )
    static let diagnosticsExportCanceled = LocalizedEntry(
        english: "Diagnostics export canceled.",
        spanish: "Exportacion de diagnostico cancelada."
    )
    static let exportCanceledByUser = LocalizedEntry(
        english: "Export canceled by user.",
        spanish: "Exportacion cancelada por el usuario."
    )
    static func diagnosticsExportedTo(_ path: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Diagnostics exported to: \(path)",
            spanish: "Diagnostico exportado en: \(path)"
        )
    }
    static func diagnosticsPackageSavedAt(_ path: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Diagnostics package saved at:\n\(path)",
            spanish: "Paquete de diagnostico guardado en:\n\(path)"
        )
    }
    static let selectGamesLocation = LocalizedEntry(
        english: "Select games location",
        spanish: "Seleccionar ubicacion de juegos"
    )
    static func gameLibraryConfiguredAt(_ path: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Game library configured at: \(path)",
            spanish: "Biblioteca de juegos configurada en: \(path)"
        )
    }
    static let gameLibraryRestoredDefault = LocalizedEntry(
        english: "Game library restored to the default location.",
        spanish: "Biblioteca de juegos restaurada a la ubicacion por defecto."
    )
    static let defaultInsidePrefix = LocalizedEntry(
        english: "Default (inside the prefix)",
        spanish: "Por defecto (dentro del prefix)"
    )
    static let noneDetected = LocalizedEntry(
        english: "None detected",
        spanish: "Ninguno detectado"
    )

    // MARK: CPU layout

    static func cpuLayoutPE(_ perfCores: Int, _ effCores: Int, _ logicalCores: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "P\(perfCores) / E\(effCores) (\(logicalCores) logical)",
            spanish: "P\(perfCores) / E\(effCores) (\(logicalCores) logicos)"
        )
    }
    static func cpuLayoutCores(_ cores: Int, _ logicalCores: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(cores) cores (\(logicalCores) logical)",
            spanish: "\(cores) nucleos (\(logicalCores) logicos)"
        )
    }
    static func cpuLayoutLogical(_ logicalCores: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "\(logicalCores) logical",
            spanish: "\(logicalCores) logicos"
        )
    }

    // MARK: Model titles

    static let ask = LocalizedEntry(
        english: "Ask",
        spanish: "Preguntar"
    )
    static let economy = LocalizedEntry(
        english: "Economy",
        spanish: "Economico"
    )
    static let balanced = LocalizedEntry(
        english: "Balanced",
        spanish: "Balanceado"
    )
    static let performance = LocalizedEntry(
        english: "Performance",
        spanish: "Rendimiento"
    )
    static let extreme = LocalizedEntry(
        english: "Extreme",
        spanish: "Extremo"
    )

    // MARK: Game compatibility presets

    static let presetNoChanges = LocalizedEntry(
        english: "No changes",
        spanish: "Sin cambios"
    )
    static let presetClassicMode = LocalizedEntry(
        english: "Classic mode 640/16-bit",
        spanish: "Modo clasico 640/16-bit"
    )
    static let presetWindowedSafe = LocalizedEntry(
        english: "Safe windowed mode",
        spanish: "Modo ventana seguro"
    )
    static let presetCustom = LocalizedEntry(
        english: "Custom",
        spanish: "Personalizado"
    )

    // MARK: Color modes

    static let colors256 = LocalizedEntry(
        english: "8-bit (256 colors)",
        spanish: "8-bit (256 colores)"
    )
    static let colors16Bit = LocalizedEntry(
        english: "16-bit (65536 colors)",
        spanish: "16-bit (65536 colores)"
    )

    // MARK: Preflight check kinds

    static let homebrewTitle = LocalizedEntry(
        english: "Homebrew",
        spanish: "Homebrew"
    )
    static let diskSpaceTitle = LocalizedEntry(
        english: "Disk Space",
        spanish: "Espacio en disco"
    )
    static let networkTitle = LocalizedEntry(
        english: "Network",
        spanish: "Red"
    )
    static let wineRuntimeTitle = LocalizedEntry(
        english: "Wine Runtime",
        spanish: "Runtime Wine"
    )

    // MARK: Preflight statuses

    static let statusOK = LocalizedEntry(
        english: "OK",
        spanish: "OK"
    )
    static let statusWarning = LocalizedEntry(
        english: "Warning",
        spanish: "Aviso"
    )
    static let statusFailed = LocalizedEntry(
        english: "Failed",
        spanish: "Error"
    )

    // MARK: User manual

    static let userManual = LocalizedEntry(
        english: "User Manual",
        spanish: "Manual de uso"
    )
    static let beginnerManual = LocalizedEntry(
        english: "Steavium Beginner Manual",
        spanish: "Manual basico de Steavium"
    )
    static let manualIntro = LocalizedEntry(
        english: "This guide is designed for basic users. Follow the sections in order the first time, then repeat only the parts you need.",
        spanish: "Esta guia esta pensada para usuarios basicos. Sigue las secciones en orden la primera vez y despues repite solo las partes que necesites."
    )
    static let manualPart1Title = LocalizedEntry(
        english: "Part 1. Before you start",
        spanish: "Parte 1. Antes de empezar"
    )
    static let manualPart1Summary = LocalizedEntry(
        english: "Prepare your Mac and understand what Steavium controls.",
        spanish: "Prepara tu Mac y entiende que controla Steavium."
    )
    static let manualPart1Step1 = LocalizedEntry(
        english: "Use an Apple Silicon Mac and keep free disk space for Steam, prefixes, and game files.",
        spanish: "Usa un Mac con Apple Silicon y deja espacio libre para Steam, prefixes y archivos de juegos."
    )
    static let manualPart1Step2 = LocalizedEntry(
        english: "Steavium manages a Windows Steam environment (runtime + prefix + launch scripts).",
        spanish: "Steavium gestiona un entorno de Steam de Windows (runtime + prefix + scripts de arranque)."
    )
    static let manualPart1Step3 = LocalizedEntry(
        english: "If this is your first time, do not skip runtime installation.",
        spanish: "Si es tu primera vez, no omitas la instalacion del runtime."
    )
    static let manualPart2Title = LocalizedEntry(
        english: "Part 2. First setup (quick flow)",
        spanish: "Parte 2. Configuracion inicial (flujo rapido)"
    )
    static let manualPart2Summary = LocalizedEntry(
        english: "Run these buttons from left to right for a clean first setup.",
        spanish: "Ejecuta estos botones de izquierda a derecha para una configuracion limpia."
    )
    static let manualPart2Step1 = LocalizedEntry(
        english: "1) Install Runtime: installs and validates Wine runtime components.",
        spanish: "1) Instalar Runtime: instala y valida los componentes del runtime de Wine."
    )
    static let manualPart2Step2 = LocalizedEntry(
        english: "2) Set Up Steam: creates or updates the Steam Windows environment.",
        spanish: "2) Preparar Steam: crea o actualiza el entorno de Steam para Windows."
    )
    static let manualPart2Step3 = LocalizedEntry(
        english: "3) Launch Steam: opens Steam inside Steavium. Log in and let updates finish.",
        spanish: "3) Lanzar Steam: abre Steam dentro de Steavium. Inicia sesion y deja terminar actualizaciones."
    )
    static let manualPart3Title = LocalizedEntry(
        english: "Part 3. Library management",
        spanish: "Parte 3. Gestion de biblioteca"
    )
    static let manualPart3Summary = LocalizedEntry(
        english: "Choose where games live and verify what Steavium is using.",
        spanish: "Elige donde viven los juegos y verifica que ruta esta usando Steavium."
    )
    static let manualPart3Step1 = LocalizedEntry(
        english: "Use Choose Library to set a custom games folder.",
        spanish: "Usa Elegir Biblioteca para definir una carpeta de juegos personalizada."
    )
    static let manualPart3Step2 = LocalizedEntry(
        english: "Use Open Library, Open Prefix, and Open Logs when you need to inspect files.",
        spanish: "Usa Abrir Biblioteca, Abrir Prefix y Abrir Logs cuando necesites inspeccionar archivos."
    )
    static let manualPart3Step3 = LocalizedEntry(
        english: "Clear Library only resets the configured path; it does not uninstall Steam.",
        spanish: "Limpiar Biblioteca solo restablece la ruta configurada; no desinstala Steam."
    )
    static let manualPart4Title = LocalizedEntry(
        english: "Part 4. Per-game compatibility profiles",
        spanish: "Parte 4. Perfiles de compatibilidad por juego"
    )
    static let manualPart4Summary = LocalizedEntry(
        english: "Use profiles only for problematic games; keep defaults for stable titles.",
        spanish: "Usa perfiles solo para juegos problematicos; deja valores por defecto en juegos estables."
    )
    static let manualPart4Step1 = LocalizedEntry(
        english: "Press Detect Games, pick a game, then start with a preset.",
        spanish: "Pulsa Detectar Juegos, elige un juego y empieza con un preset."
    )
    static let manualPart4Step2 = LocalizedEntry(
        english: "If needed, adjust compatibility mode, windowed mode, resolution, color mode, and admin execution.",
        spanish: "Si hace falta, ajusta modo de compatibilidad, modo ventana, resolucion, color reducido y ejecucion como administrador."
    )
    static let manualPart4Step3 = LocalizedEntry(
        english: "Use Save Profile to persist changes or Reset to return to defaults.",
        spanish: "Usa Guardar Perfil para guardar cambios o Restablecer para volver a valores por defecto."
    )
    static let manualPart5Title = LocalizedEntry(
        english: "Part 5. Maintenance and recovery",
        spanish: "Parte 5. Mantenimiento y recuperacion"
    )
    static let manualPart5Summary = LocalizedEntry(
        english: "Use safe cleanup options when Steam behaves incorrectly.",
        spanish: "Usa opciones de limpieza seguras cuando Steam se comporte mal."
    )
    static let manualPart5Step1 = LocalizedEntry(
        english: "Close Steam if updates hang or game launches are inconsistent.",
        spanish: "Cierra Steam si una actualizacion se queda colgada o los lanzamientos son inconsistentes."
    )
    static let manualPart5Step2 = LocalizedEntry(
        english: "Use Wipe Data only when needed; choose account data, library data, or both carefully.",
        spanish: "Usa Borrar Datos solo cuando sea necesario; elige con cuidado datos de cuenta, biblioteca o ambos."
    )
    static let manualPart5Step3 = LocalizedEntry(
        english: "If something fails, review Console logs first before retrying setup.",
        spanish: "Si algo falla, revisa primero los logs de Consola antes de repetir la configuracion."
    )

    // MARK: SteamManagerError messages

    static func errorMissingScript(_ name: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Internal script not found: \(name)",
            spanish: "No se encontro el script interno: \(name)"
        )
    }
    static let errorHomebrewNotFound = LocalizedEntry(
        english: "Homebrew was not detected. Install Homebrew and retry.",
        spanish: "No se detecto Homebrew. Instala Homebrew y vuelve a intentar."
    )
    static func errorPreflightBlocking(_ checksText: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Preflight blocked runtime installation. Fix blocking checks and retry: \(checksText).",
            spanish: "El preflight bloqueo la instalacion del runtime. Corrige los checks bloqueantes y reintenta: \(checksText)."
        )
    }
    static let errorWineRuntimeNotFound = LocalizedEntry(
        english: "No compatible Wine runtime detected. Use \"Install Runtime\" first.",
        spanish: "No se detecto un runtime de Wine compatible. Usa \"Instalar Runtime\" primero."
    )
    static let errorDataWipeSelectionRequired = LocalizedEntry(
        english: "Select at least one option to delete data.",
        spanish: "Selecciona al menos una opcion para borrar datos."
    )
    static let errorSteamAlreadyRunning = LocalizedEntry(
        english: "Steam is already running.",
        spanish: "Steam ya esta ejecutandose."
    )
    static func errorGameNotFound(_ appID: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "Game with AppID \(appID) was not found in the installed library.",
            spanish: "No se encontro el juego con AppID \(appID) en la biblioteca instalada."
        )
    }
    static func errorExecutableNotFound(_ appID: Int) -> LocalizedEntry {
        LocalizedEntry(
            english: "No valid executable found for AppID \(appID).",
            spanish: "No se encontro ejecutable valido para AppID \(appID)."
        )
    }
    static let errorSteamRootNotFound = LocalizedEntry(
        english: "Steam installation could not be located to apply per-game profiles.",
        spanish: "No se pudo localizar la instalacion de Steam para aplicar perfiles por juego."
    )
    static func errorLocalConfigUnreadable(_ path: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Could not read localconfig.vdf: \(path)",
            spanish: "No se pudo leer localconfig.vdf: \(path)"
        )
    }
    static func errorLocalConfigWriteFailed(_ path: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Could not write localconfig.vdf: \(path)",
            spanish: "No se pudo escribir localconfig.vdf: \(path)"
        )
    }
    static func errorCompatVerificationFailed(_ executable: String, _ expected: String, _ actual: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Compatibility flags verification failed for \(executable). Expected: \(expected). Actual: \(actual).",
            spanish: "La verificacion de flags de compatibilidad fallo para \(executable). Esperado: \(expected). Actual: \(actual)."
        )
    }

    // MARK: Uninstaller

    static let uninstallSteavium = LocalizedEntry(
        english: "Uninstall Steavium",
        spanish: "Desinstalar Steavium"
    )

    // MARK: Menu bar

    static let menuBarSteamRunning = LocalizedEntry(
        english: "Steam is running",
        spanish: "Steam esta en ejecucion"
    )
    static let menuBarSteamNotRunning = LocalizedEntry(
        english: "Steam is not running",
        spanish: "Steam no esta en ejecucion"
    )
    static let menuBarShowSteavium = LocalizedEntry(
        english: "Show Steavium",
        spanish: "Mostrar Steavium"
    )
    static let menuBarQuit = LocalizedEntry(
        english: "Quit Steavium",
        spanish: "Salir de Steavium"
    )
    static let uninstallTitle = LocalizedEntry(
        english: "Uninstall Steavium?",
        spanish: "¿Desinstalar Steavium?"
    )
    static let uninstallMessage = LocalizedEntry(
        english: "This will remove Steavium from your system, including all app data, Wine prefixes, and settings. Your custom game library folder (if set) will NOT be deleted.",
        spanish: "Esto eliminara Steavium de tu sistema, incluyendo todos los datos de la app, los prefixes de Wine y la configuracion. Tu carpeta personalizada de juegos (si la configuraste) NO sera eliminada."
    )
    static let uninstallConfirm = LocalizedEntry(
        english: "Uninstall",
        spanish: "Desinstalar"
    )
    static let uninstallSuccess = LocalizedEntry(
        english: "Steavium has been uninstalled. The app will now close.",
        spanish: "Steavium ha sido desinstalado. La aplicacion se cerrara ahora."
    )
    static let uninstallKeepDataOption = LocalizedEntry(
        english: "Keep Wine prefix and game data",
        spanish: "Conservar prefix de Wine y datos de juegos"
    )

    // MARK: Auto-updater

    static let checkForUpdates = LocalizedEntry(
        english: "Check for Updates",
        spanish: "Buscar actualizaciones"
    )
    static let updateAvailable = LocalizedEntry(
        english: "Update Available",
        spanish: "Actualizacion disponible"
    )
    static func updateNewVersion(_ version: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "A new version (\(version)) is available.",
            spanish: "Una nueva version (\(version)) esta disponible."
        )
    }
    static let updateNow = LocalizedEntry(
        english: "Update Now",
        spanish: "Actualizar ahora"
    )
    static let updateChecking = LocalizedEntry(
        english: "Checking for updates…",
        spanish: "Buscando actualizaciones…"
    )
    static let updateNoUpdate = LocalizedEntry(
        english: "You're up to date!",
        spanish: "¡Estas al dia!"
    )
    static let updateDownloading = LocalizedEntry(
        english: "Downloading update…",
        spanish: "Descargando actualizacion…"
    )
    static let updateInstalling = LocalizedEntry(
        english: "Installing update…",
        spanish: "Instalando actualizacion…"
    )
    static func updateInstalled(_ version: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Version \(version) installed! Relaunch to apply.",
            spanish: "¡Version \(version) instalada! Reinicia para aplicar."
        )
    }
    static let updateRelaunch = LocalizedEntry(
        english: "Relaunch",
        spanish: "Reiniciar"
    )
    static let updateFailed = LocalizedEntry(
        english: "Update failed",
        spanish: "La actualizacion fallo"
    )
    static let updateRetry = LocalizedEntry(
        english: "Retry",
        spanish: "Reintentar"
    )
    static let releaseNotes = LocalizedEntry(
        english: "Release Notes",
        spanish: "Notas de la version"
    )
    static func currentVersionLabel(_ version: String) -> LocalizedEntry {
        LocalizedEntry(
            english: "Current version: \(version)",
            spanish: "Version actual: \(version)"
        )
    }
}
// swiftlint:enable type_body_length
