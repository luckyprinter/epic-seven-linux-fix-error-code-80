#!/usr/bin/env bash
# =============================================================================
# Epic Seven — STOVE ERROR Code -80 / WebView2 Fix for Linux & Steam Deck
# Version 1.2.0
#
# Fixes:
#   - "STOVE ERROR — Cmd:STOVE_INITIALIZE Code:-80"
#   - "STOVE ERROR — Cmd:STANDBY Code:-80"
#
# Cause:
#   The STOVE PC SDK requires Microsoft Edge WebView2 Runtime to display
#   its web views (login, notices, shop). Proton prefixes do not ship
#   WebView2 by default.
#
# What this script does:
#   1.  Checks that required tools (curl or wget) are installed.
#   2.  Auto-detects Steam root (native, Flatpak, Snap, or Steam Deck).
#   3.  Parses libraryfolders.vdf to find prefixes on any drive or SD card.
#   4.  Finds Epic Seven's compatdata prefix (official release, demo, or custom).
#   5.  Checks if the game is running to prevent prefix file locks.
#   6.  Finds the best available Proton version and container runtime.
#   7.  Downloads the official WebView2 standalone installer (~205 MB).
#   8.  Installs WebView2 silently into the game's prefix.
#   9.  Fixes partial installs (EdgeCore fallback + registry registration).
#   10. Verifies the result against registry and STOVE SDK logs.
#
# Tested on: Steam Deck (SteamOS) — native Steam
#            Arch Linux — native Steam
#            Ubuntu 22.04 — native Steam
#            CachyOS — native Steam (use --proton if cachy-proton isn't detected)
#            Proton 7.0 through 10.0, GE-Proton
#
#            Flatpak and Snap Steam: paths are auto-detected but not fully
#            verified on a live machine. If you're on Flatpak/Snap and run
#            into issues, use --prefix or --proton to point the script manually.
# =============================================================================

set -euo pipefail

SCRIPT_VERSION="1.2.1"
INSTALLER_URL="https://go.microsoft.com/fwlink/?linkid=2124701"
INSTALLER_NAME="MicrosoftEdgeWebView2RuntimeInstallerX64.exe"
DOWNLOAD_DIR="${HOME}/Downloads"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/epic7-fix"

# CLI flag overrides
MANUAL_PREFIX=""
MANUAL_APPID=""
MANUAL_PROTON=""
CHECK_ONLY=false
NON_INTERACTIVE=false
PGREP_AVAILABLE=true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# All diagnostic output goes to stderr so it never pollutes stdout.
# This matters because several functions return values via stdout inside
# command substitutions like INSTALLER="$(find_or_download_installer)".
# If info/success/warn wrote to stdout, their text would be captured
# into the variable instead of being printed to the terminal.
info()    { echo -e "${BLUE}[INFO]${NC}  $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC}    $*" >&2; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*" >&2; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Pre-Flight: Dependency & Environment Checks
# -----------------------------------------------------------------------------

# Detect the distro's package manager by looking for known binaries.
# This works even without /etc/os-release (e.g. minimal containers).
detect_pkg_mgr() {
    if   command -v apt    >/dev/null 2>&1; then echo "apt"
    elif command -v dnf    >/dev/null 2>&1; then echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then echo "pacman"
    elif command -v zypper >/dev/null 2>&1; then echo "zypper"
    else echo "unknown"
    fi
}

check_dependencies() {
    # Bash 4.0+ required for 'mapfile' (builtin array reader).
    # All modern distros ship 4.x or 5.x — only ancient macOS bash 3.2 fails this.
    if (( BASH_VERSINFO[0] < 4 )); then
        die "This script requires Bash 4.0 or newer. You have: ${BASH_VERSION}
Please update your bash installation using your package manager."
    fi

    # Need curl or wget to download the WebView2 installer (~205 MB).
    local has_curl=false has_wget=false
    command -v curl >/dev/null 2>&1 && has_curl=true
    command -v wget >/dev/null 2>&1 && has_wget=true

    if [[ "$has_curl" == false && "$has_wget" == false ]]; then
        local mgr; mgr="$(detect_pkg_mgr)"
        error "Neither 'curl' nor 'wget' is installed."
        error "This script needs one of them to download the WebView2 installer."
        error ""
        error "To install curl, open a terminal and run:"
        case "$mgr" in
            apt)    die "  sudo apt install curl" ;;
            dnf)    die "  sudo dnf install curl" ;;
            pacman) die "  sudo pacman -S curl" ;;
            zypper) die "  sudo zypper install curl" ;;
            *)      die "  Install 'curl' using your distribution's package manager." ;;
        esac
    fi

    # pgrep is used to detect if the game is already running before installing.
    # It lives in the 'procps' package. If it's not available we skip that check
    # rather than failing — it is not required for the actual fix to work.
    if ! command -v pgrep >/dev/null 2>&1; then
        warn "'pgrep' not found — skipping the game-running check."
        warn "To install it: 'procps' package on Ubuntu/Debian/openSUSE, 'procps-ng' on Fedora/Arch."
        PGREP_AVAILABLE=false
    fi
}

# -----------------------------------------------------------------------------
# Usage / Help
# -----------------------------------------------------------------------------
usage() {
    cat <<USAGE_EOF
Epic Seven WebView2 Fix v${SCRIPT_VERSION}
Fixes STOVE ERROR Code -80 on Linux & Steam Deck

Usage: $(basename "$0") [OPTIONS]

Options:
  -c, --check          Check prefix health and log status without installing
  -p, --prefix PATH    Manually specify path to game's compatdata folder
  -a, --appid ID       Manually specify Steam App ID (e.g. 5019180, 3678970, 5129800)
      --proton PATH    Manually specify a custom proton binary
  -y, --yes            Run non-interactively (skip confirmation prompts)
  -h, --help           Show this help message
  -v, --version        Show script version

Examples:
  $(basename "$0")                        # Auto-detect everything and install fix
  $(basename "$0") --check               # Only check if your prefix is already fixed
  $(basename "$0") -a 5019180            # Force a specific App ID
  $(basename "$0") -p ~/.local/share/Steam/steamapps/compatdata/5019180
USAGE_EOF
    exit 0
}

# Parse CLI options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--check)
            CHECK_ONLY=true; shift ;;
        -p|--prefix)
            MANUAL_PREFIX="${2:-}"
            [[ -z "$MANUAL_PREFIX" ]] && die "Option -p/--prefix requires a path argument"
            shift 2 ;;
        -a|--appid)
            MANUAL_APPID="${2:-}"
            [[ -z "$MANUAL_APPID" ]] && die "Option -a/--appid requires an App ID argument"
            shift 2 ;;
        --proton)
            MANUAL_PROTON="${2:-}"
            [[ -z "$MANUAL_PROTON" ]] && die "Option --proton requires a path argument"
            shift 2 ;;
        -y|--yes)
            NON_INTERACTIVE=true; shift ;;
        -h|--help)
            usage ;;
        -v|--version)
            echo "Epic Seven WebView2 Fix v${SCRIPT_VERSION}"; exit 0 ;;
        *)
            die "Unknown option: $1  (run with --help for usage)" ;;
    esac
done

# Run dependency checks before doing anything else
check_dependencies

echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD} Epic Seven — WebView2 Runtime Fix for Linux & Steam Deck   ${NC}"
echo -e "${BOLD}============================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Discover Steam Installation & Library Folders
# -----------------------------------------------------------------------------
discover_steam_roots() {
    local candidates=(
        "${STEAM_DIR:-}"
        "${STEAM_ROOT:-}"
        # Native Steam
        "${HOME}/.local/share/Steam"
        "${HOME}/.steam/steam"
        "${HOME}/.steam/root"
        # Flatpak Steam (most distros)
        "${HOME}/.var/app/com.valvesoftware.Steam/.local/share/Steam"
        "${HOME}/.var/app/com.valvesoftware.Steam/.steam/steam"
        # Snap Steam (Ubuntu App Center default)
        "${HOME}/snap/steam/common/.local/share/Steam"
        "${HOME}/snap/steam/common/.steam/steam"
        "${HOME}/snap/steam/common/.steam/root"
        "${HOME}/snap/steam/current/.local/share/Steam"
    )

    local roots=()
    for dir in "${candidates[@]}"; do
        if [[ -n "$dir" && -d "$dir" ]]; then
            local canonical
            canonical="$(readlink -f "$dir" 2>/dev/null || echo "$dir")"
            roots+=("$canonical")
        fi
    done

    printf '%s\n' "${roots[@]}" | sort -u
}

discover_all_libraries() {
    local steam_roots
    mapfile -t steam_roots < <(discover_steam_roots)

    if [[ ${#steam_roots[@]} -eq 0 ]]; then
        return
    fi

    local libs=()
    for root in "${steam_roots[@]}"; do
        libs+=("$root")
        # Parse libraryfolders.vdf to find extra library drives / SD cards
        for vdf in "$root/steamapps/libraryfolders.vdf" "$root/config/libraryfolders.vdf"; do
            if [[ -f "$vdf" ]]; then
                while read -r p; do
                    if [[ -n "$p" && -d "$p" ]]; then
                        local canon
                        canon="$(readlink -f "$p" 2>/dev/null || echo "$p")"
                        libs+=("$canon")
                    fi
                done < <(awk -F'"' '/"path"/ {print $4}' "$vdf" 2>/dev/null)
            fi
        done
    done

    printf '%s\n' "${libs[@]}" | sort -u
}

mapfile -t STEAM_LIBRARIES < <(discover_all_libraries)

if [[ ${#STEAM_LIBRARIES[@]} -eq 0 && -z "$MANUAL_PREFIX" ]]; then
    die "Could not find any Steam installation on your system.
If Steam is installed in a custom location, run:
  $0 -p /path/to/steamapps/compatdata/<appid>"
fi

PRIMARY_STEAM="${STEAM_LIBRARIES[0]:-$HOME/.local/share/Steam}"
info "Primary Steam directory: $PRIMARY_STEAM"
info "Total Steam libraries scanned: ${#STEAM_LIBRARIES[@]}"

# -----------------------------------------------------------------------------
# 2. Find Epic Seven Compatdata Prefix
# -----------------------------------------------------------------------------
find_epic7_prefix() {
    # Priority 1: user specified a manual path
    if [[ -n "$MANUAL_PREFIX" ]]; then
        if [[ -d "$MANUAL_PREFIX/pfx" ]]; then
            echo "$MANUAL_PREFIX"; return
        elif [[ -d "$MANUAL_PREFIX" && "$(basename "$MANUAL_PREFIX")" == "pfx" ]]; then
            dirname "$MANUAL_PREFIX"; return
        else
            die "Specified prefix does not look like a valid Proton prefix: $MANUAL_PREFIX"
        fi
    fi

    # Priority 2: user specified a Steam App ID
    if [[ -n "$MANUAL_APPID" ]]; then
        for lib in "${STEAM_LIBRARIES[@]}"; do
            if [[ -d "$lib/steamapps/compatdata/$MANUAL_APPID/pfx" ]]; then
                echo "$lib/steamapps/compatdata/$MANUAL_APPID"; return
            fi
        done
        die "Could not find compatdata for App ID $MANUAL_APPID in any Steam library."
    fi

    # Priority 3: scan for STOVE_EPIC7 log directory (most reliable — works for
    # any App ID including regional variants the user might have)
    for lib in "${STEAM_LIBRARIES[@]}"; do
        for log_dir in "$lib"/steamapps/compatdata/*/pfx/drive_c/users/*/AppData/Local/STOVEPCSDK3/logs/STOVE_EPIC7; do
            if [[ -d "$log_dir" ]]; then
                echo "$log_dir" | sed -E 's|(/steamapps/compatdata/[^/]+)/.*|\1|'
                return
            fi
        done
    done

    # Priority 4: known official App IDs as fallback
    local known_ids=(5019180 3678970 5129800)
    for lib in "${STEAM_LIBRARIES[@]}"; do
        for id in "${known_ids[@]}"; do
            if [[ -d "$lib/steamapps/compatdata/$id/pfx" ]]; then
                echo "$lib/steamapps/compatdata/$id"; return
            fi
        done
    done
}

PFX="$(find_epic7_prefix || true)"

if [[ -z "$PFX" || ! -d "$PFX/pfx" ]]; then
    die "Could not find Epic Seven's Proton prefix.
Make sure you have launched Epic Seven at least once via Steam so Proton
creates the prefix folder, then run this script again.

If your library is in a custom location, specify it manually:
  $0 -p /path/to/steamapps/compatdata/<appid>"
fi

DETECTED_APPID="$(basename "$PFX")"
success "Found Epic Seven prefix: $PFX (App ID: ${DETECTED_APPID})"

# -----------------------------------------------------------------------------
# 3. Health Check / Status Mode  (--check flag)
# -----------------------------------------------------------------------------
EDGEWEBVIEW="$PFX/pfx/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application"
EDGECORE="$PFX/pfx/drive_c/Program Files (x86)/Microsoft/EdgeCore"
SYSREG="$PFX/pfx/system.reg"

check_status() {
    echo ""
    echo -e "${BOLD}--- Installation Health Check ---${NC}"

    local files_ok=false reg_ok=false installed_ver="none"

    if [[ -d "$EDGEWEBVIEW" ]]; then
        local found_ver
        found_ver="$(ls "$EDGEWEBVIEW" 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -n 1 || true)"
        if [[ -n "$found_ver" ]]; then
            files_ok=true
            installed_ver="$found_ver"
            success "WebView2 runtime files: Present (v${installed_ver})"
        fi
    fi

    if [[ "$files_ok" == false ]]; then
        if [[ -d "$EDGECORE" && -n "$(ls -A "$EDGECORE" 2>/dev/null)" ]]; then
            warn "WebView2 runtime files: Stalled in EdgeCore (partial install — re-run to complete)"
        else
            warn "WebView2 runtime files: Not installed"
        fi
    fi

    if [[ -f "$SYSREG" ]] && grep -aq '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' "$SYSREG" 2>/dev/null; then
        reg_ok=true
        success "Windows Registry keys: Present and configured"
    else
        warn "Windows Registry keys: Missing"
    fi

    # Check the most recent STOVE SDK log for the definitive result
    local latest_log
    latest_log="$(find "$PFX/pfx/drive_c/users" -name "BaseSDK_*.log" 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$latest_log" ]]; then
        echo ""
        info "Latest STOVE SDK log: $(basename "$latest_log")"
        if grep -q "Success to initialize ViewUISDK" "$latest_log" 2>/dev/null; then
            success "Log status: ViewUISDK initialized successfully — no Error -80!"
        elif grep -q "WebView rumtime is not available" "$latest_log" 2>/dev/null; then
            error "Log status: Error -80 still present (WebView2 runtime not found by STOVE)"
        else
            info "Log status: No WebView initialization recorded yet in the latest log"
        fi
    fi

    echo ""
    if [[ "$files_ok" == true && "$reg_ok" == true ]]; then
        success "Status: WebView2 is fully installed. Your prefix is healthy!"
        return 0
    else
        warn "Status: WebView2 is NOT fully installed. Run the script without --check to fix it."
        return 1
    fi
}

if [[ "$CHECK_ONLY" == true ]]; then
    check_status
    exit $?
fi

# -----------------------------------------------------------------------------
# 4. Check If Epic Seven Is Currently Running
# -----------------------------------------------------------------------------
check_game_running() {
    if [[ "$PGREP_AVAILABLE" == false ]]; then
        return
    fi

    local running_pids
    running_pids="$(pgrep -f "EpicSeven|STOVE_EPIC7" 2>/dev/null || true)"
    if [[ -n "$running_pids" ]]; then
        echo ""
        warn "Epic Seven appears to be running (PID: ${running_pids//$'\n'/ })."
        warn "Please close it before continuing — installing WebView2 while the game"
        warn "is open can cause file locks or registry changes to be rolled back."

        if [[ "$NON_INTERACTIVE" == true ]]; then
            die "Game is running and --yes was specified. Exit Epic Seven first."
        fi

        echo -n "Close Epic Seven, then press [Enter] to continue (or Ctrl+C to cancel)... "

        # Read from the real terminal even if this script is being piped
        # (e.g. run via: curl ... | bash)
        if [[ -t 0 ]]; then
            read -r
        elif [[ -r /dev/tty ]]; then
            read -r </dev/tty
        else
            warn "No interactive terminal detected. Waiting 10 seconds and continuing..."
            sleep 10
        fi
    fi
}
check_game_running

# -----------------------------------------------------------------------------
# 5. Detect Proton & Steam Linux Runtime
# -----------------------------------------------------------------------------
find_proton() {
    if [[ -n "$MANUAL_PROTON" ]]; then
        [[ -x "$MANUAL_PROTON" ]] && { echo "$MANUAL_PROTON"; return; }
        die "Specified Proton path is not executable: $MANUAL_PROTON"
    fi

    # Try versions newest-first; Proton 10 has the best Wine compatibility for
    # the WebView2 installer's silent mode.
    local preferred=(
        "Proton 10.0"
        "Proton 11.0"
        "Proton - Experimental"
        "Proton 9.0 (Beta)"
        "Proton 9.0"
        "Proton 8.0"
        "Proton 7.0"
    )

    for lib in "${STEAM_LIBRARIES[@]}"; do
        for p in "${preferred[@]}"; do
            local candidate="$lib/steamapps/common/$p/proton"
            [[ -f "$candidate" ]] && { echo "$candidate"; return; }
        done
    done

    # GE-Proton and other custom tools in user-level compatibilitytools.d
    for lib in "${STEAM_LIBRARIES[@]}"; do
        local compat="$lib/compatibilitytools.d"
        if [[ -d "$compat" ]]; then
            local ge_proton
            ge_proton="$(find "$compat" -maxdepth 2 -name "proton" 2>/dev/null | sort -V | tail -n 1)"
            [[ -n "$ge_proton" && -f "$ge_proton" ]] && { echo "$ge_proton"; return; }
        fi
    done

    # ~/.steam/root/compatibilitytools.d — Steam's own symlink location,
    # sometimes separate from the library paths above
    local steam_root_compat="${HOME}/.steam/root/compatibilitytools.d"
    if [[ -d "$steam_root_compat" ]]; then
        local sr_proton
        sr_proton="$(find "$steam_root_compat" -maxdepth 2 -name "proton" 2>/dev/null | sort -V | tail -n 1)"
        [[ -n "$sr_proton" && -f "$sr_proton" ]] && { echo "$sr_proton"; return; }
    fi

    # System-wide compatibilitytools.d — used by distros that package custom
    # Proton builds via their package manager (e.g. CachyOS cachy-proton,
    # Nobara proton-ge-custom installed via dnf/pacman)
    local sys_compat_dirs=(
        "/usr/share/steam/compatibilitytools.d"
        "/usr/lib/steam/compatibilitytools.d"
    )
    for compat in "${sys_compat_dirs[@]}"; do
        if [[ -d "$compat" ]]; then
            local sys_proton
            sys_proton="$(find "$compat" -maxdepth 2 -name "proton" 2>/dev/null | sort -V | tail -n 1)"
            [[ -n "$sys_proton" && -f "$sys_proton" ]] && { echo "$sys_proton"; return; }
        fi
    done

    # Last resort: any proton binary anywhere in the libraries
    for lib in "${STEAM_LIBRARIES[@]}"; do
        local any_proton
        any_proton="$(find "$lib/steamapps/common" -maxdepth 3 -name "proton" 2>/dev/null | sort -V | tail -n 1)"
        [[ -n "$any_proton" && -f "$any_proton" ]] && { echo "$any_proton"; return; }
    done
}

find_runtime() {
    local runtimes=(
        "SteamLinuxRuntime_sniper/run"
        "SteamLinuxRuntime_soldier/run"
        "SteamLinuxRuntime_4/run"
        "SteamLinuxRuntime/run"
    )
    for lib in "${STEAM_LIBRARIES[@]}"; do
        for r in "${runtimes[@]}"; do
            local candidate="$lib/steamapps/common/$r"
            [[ -f "$candidate" ]] && { echo "$candidate"; return; }
        done
    done
}

PROTON="$(find_proton || true)"
RUNTIME="$(find_runtime || true)"

[[ -n "$PROTON" && -f "$PROTON" ]] \
    || die "Could not find a Proton installation in any of the standard locations.

If you use a custom Proton build (e.g. cachy-proton, GE-Proton installed
via your package manager), point the script to it directly:

  $0 --proton /path/to/proton

To find the path, run:
  find /usr ~/.local ~/.steam -name 'proton' 2>/dev/null | grep -v 'dist\|python'

Then install Proton via Steam → Library → Tools if none are found."

info "Proton binary : $PROTON"

if [[ -n "$RUNTIME" && -f "$RUNTIME" ]]; then
    info "Steam Runtime  : $RUNTIME"
else
    warn "Steam Linux Runtime not found — running Proton directly on the host system."
    RUNTIME=""
fi

# -----------------------------------------------------------------------------
# 6. Locate or Download the WebView2 Standalone Installer
# -----------------------------------------------------------------------------
find_or_download_installer() {
    # Check common locations for an already-downloaded copy first
    local search_spots=(
        "$PWD/$INSTALLER_NAME"
        "$DOWNLOAD_DIR/$INSTALLER_NAME"
        "$CACHE_DIR/$INSTALLER_NAME"
    )

    for path in "${search_spots[@]}"; do
        if [[ -f "$path" ]]; then
            local sz
            sz="$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null || echo 0)"
            if [[ "$sz" -gt 150000000 ]]; then
                success "Found existing installer: $path (re-using it)"
                echo "$path"
                return
            fi
        fi
    done

    # Nothing cached — download now
    mkdir -p "$CACHE_DIR"
    local target="$CACHE_DIR/$INSTALLER_NAME"

    info "Downloading Microsoft Edge WebView2 Standalone Installer (~205 MB)..."
    info "This is the official installer from Microsoft. It will only be run inside"
    info "the game's Proton prefix — nothing is installed on your Linux system."

    if command -v curl >/dev/null 2>&1; then
        curl -L --progress-bar -o "$target" "$INSTALLER_URL" \
            || die "Download failed. Check your internet connection and try again."
    else
        wget --show-progress -O "$target" "$INSTALLER_URL" \
            || die "Download failed. Check your internet connection and try again."
    fi

    local size
    size="$(stat -c%s "$target" 2>/dev/null || stat -f%z "$target" 2>/dev/null || echo 0)"
    if [[ "$size" -lt 150000000 ]]; then
        rm -f "$target"
        die "Downloaded file is too small (${size} bytes) — it was likely truncated.
Please check your internet connection and run the script again."
    fi

    success "Download complete ($(du -sh "$target" | cut -f1))"
    echo "$target"
}

INSTALLER="$(find_or_download_installer)"

# -----------------------------------------------------------------------------
# 7. Run the Installer Inside the Proton Prefix
# -----------------------------------------------------------------------------
info "Installing WebView2 inside Proton prefix — this runs silently for ~60-90 seconds..."

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$PRIMARY_STEAM"
export STEAM_COMPAT_DATA_PATH="$PFX"

set +e
if [[ -n "$RUNTIME" ]]; then
    "$RUNTIME" -- "$PROTON" run "$INSTALLER" /silent /install
else
    "$PROTON" run "$INSTALLER" /silent /install
fi
INSTALL_EXIT=$?
set -e

info "Installer exited with code: $INSTALL_EXIT (a non-zero exit is normal here)"

# Give wineserver a moment to write everything to disk
sleep 3

# -----------------------------------------------------------------------------
# 8. Post-Install Fixups: EdgeCore fallback and registry keys
# -----------------------------------------------------------------------------

# Check for version number in the standard install location
VER=""
if [[ -d "$EDGEWEBVIEW" ]]; then
    VER="$(ls "$EDGEWEBVIEW" 2>/dev/null | grep -E '^[0-9]' | sort -V | tail -n 1 || true)"
fi

# On some Proton/Wine versions the installer unpacks to EdgeCore instead of
# EdgeWebView/Application and skips the final registry step.
# This function completes the install manually when that happens.
complete_edgecore_install() {
    if [[ ! -d "$EDGECORE" ]] || [[ -z "$(ls -A "$EDGECORE" 2>/dev/null)" ]]; then
        return 1
    fi
    local core_dir
    core_dir="$(ls -d "$EDGECORE"/* 2>/dev/null | sort -V | tail -n 1)"
    [[ -z "$core_dir" ]] && return 1

    # Set the global VER so the registry step picks it up
    VER="$(basename "$core_dir")"
    info "Completing partial install from EdgeCore (v${VER})..."
    mkdir -p "$EDGEWEBVIEW/$VER"
    cp -rn "$core_dir/." "$EDGEWEBVIEW/$VER/"
    success "Copied files to EdgeWebView/Application/${VER}"
    return 0
}

if [[ -z "$VER" ]]; then
    complete_edgecore_install || true
fi

if [[ -z "$VER" ]]; then
    die "Installation failed — no WebView2 files were created.
Expected to find files in:
  $EDGEWEBVIEW
  $EDGECORE

Make sure Proton launched correctly and try running the script again."
fi

# Write registry keys so WebView2Loader.dll can find the runtime.
# These are needed even when the file install succeeded — Proton's regedit
# sometimes skips writing them.
REG_KEY_EXISTS=false
if [[ -f "$SYSREG" ]] && grep -aq '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}' "$SYSREG" 2>/dev/null; then
    REG_KEY_EXISTS=true
fi

if [[ "$REG_KEY_EXISTS" == false ]]; then
    info "Writing required WebView2 registry keys..."
    GUID='{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
    REG_TMP="/tmp/wv2_epic7_${DETECTED_APPID}.reg"

    cat <<REG_EOF > "$REG_TMP"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\\${GUID}]
"pv"="${VER}"
"name"="Microsoft Edge WebView2 Runtime"
"location"="C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\EdgeUpdate\Clients\\${GUID}]
"pv"="${VER}"
"name"="Microsoft Edge WebView2 Runtime"
"location"="C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application"
REG_EOF

    set +e
    if [[ -n "$RUNTIME" ]]; then
        "$RUNTIME" -- "$PROTON" run regedit /S "Z:\\tmp\\wv2_epic7_${DETECTED_APPID}.reg"
    else
        "$PROTON" run regedit /S "Z:\\tmp\\wv2_epic7_${DETECTED_APPID}.reg"
    fi
    set -e
    rm -f "$REG_TMP"
    success "Registry keys written"
else
    success "Registry keys already present — skipping"
fi

# -----------------------------------------------------------------------------
# 9. Final Verification
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}============================================================${NC}"
echo -e "${BOLD} Verification & Final Status                                ${NC}"
echo -e "${BOLD}============================================================${NC}"

if check_status; then
    echo ""
    echo -e "${GREEN}${BOLD}✓ All done! The fix was applied successfully.${NC}"
    echo "Launch Epic Seven normally through Steam — the STOVE Code -80 errors should be gone."
    echo ""
    echo -e "${BLUE}Tip:${NC} If you ever verify game files or reinstall the game, Steam may"
    echo "wipe the prefix. Just run this script again — it takes under 30 seconds"
    echo "if the installer is already in your Downloads folder."
else
    echo ""
    echo -e "${RED}${BOLD}✗ Verification found issues. See the messages above for details.${NC}"
    echo "You can run the script again to retry, or use --check to re-diagnose."
fi

echo -e "${BOLD}============================================================${NC}"
echo ""
