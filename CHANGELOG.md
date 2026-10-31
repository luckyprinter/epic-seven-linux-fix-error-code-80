# Changelog

All notable changes to this project are documented here.

---

## v1.2.2 — Linux Mint Fix: GnuTLS Noise & False-Negative Log Check

### Bug Fixes
- **Fixed (misleading):** After a successful install, the final verification step would show `[ERROR] Log status: Error -80 still present` on some systems. This was a false negative — the STOVE SDK log only records results during an actual game session. After the fix is applied but before the game is relaunched, the log still reflects the pre-fix state. The `[ERROR]` label has been replaced with a `[WARN]` that clearly explains the log is expected to show old data until the game runs again. Thanks to a Linux Mint user for the report.
- **Fixed (noise):** On some distros (including Linux Mint), Wine/Proton logs many `GnuTLS error: The request is invalid.` messages during the WebView2 installer run. These are non-fatal — the installer still succeeds. The script now filters these known-harmless Wine noise lines from installer output and warns the user upfront that such messages may appear and can be ignored.

### Documentation
- **Linux Mint** added to the Tested On table as ✅ Confirmed working (native Steam).

---

## v1.2.1 — CachyOS Fix & Stdout/Stderr Bug Fix

### Bug Fixes
- **Fixed (critical):** `info()`, `success()`, and `warn()` were writing to stdout instead of stderr. Because several functions return values via `echo` inside command substitutions (e.g. `INSTALLER="$(find_or_download_installer)"`), their diagnostic messages were being silently captured into variables instead of printed to the terminal. This caused broken paths, empty variables, and confusing errors — particularly visible on CachyOS. All diagnostic output now correctly goes to stderr (`>&2`). Thanks to a CachyOS user for the report and fix.

### New Features
- **CachyOS / system-wide Proton detection:** Added `/usr/share/steam/compatibilitytools.d` and `/usr/lib/steam/compatibilitytools.d` to `find_proton()`. Distros that package custom Proton builds via their package manager (e.g. `cachy-proton` on CachyOS, `proton-ge-custom` on Nobara) install to these system paths rather than inside the Steam library folder. Also added `~/.steam/root/compatibilitytools.d` as an explicit check.
- **Improved "Proton not found" error:** Now shows a `find` command users can run to locate their Proton binary, and clearly explains how to use the `--proton` flag.

### Documentation
- **"Tested on" updated to be honest:** Flatpak and Snap Steam are marked as auto-detected but unverified. CachyOS added as a confirmed distro (with the `--proton` flag note).
- Added CachyOS and `--proton` tip to the Steam guide.

---

## v1.2.0 — Cross-Distro Hardening

### Bug Fixes
- **Fixed:** `local` keyword used illegally outside a function body (line 504 in v1.1.0). This caused a bash warning and could silently misbehave on strict shells. The EdgeCore fallback logic is now wrapped in a proper `complete_edgecore_install()` function.
- **Fixed:** `read -r` used for the "game is running" prompt without redirecting from `/dev/tty`. When the script is run via pipe (`curl ... | bash`), stdin is the pipe — the pause would be skipped silently. Now reads from `/dev/tty` when available, with a 10-second countdown fallback.
- **Fixed:** All six uses of `tail -1` changed to `tail -n 1` (POSIX-compliant form). The short `-1` flag is deprecated and produces warnings on some minimal/strict systems.

### New Features
- **Pre-flight dependency check:** The script now checks for required tools before doing anything else. If `curl` and `wget` are both missing, it detects your package manager (`apt`, `dnf`, `pacman`, `zypper`) and prints the exact install command for your distro.
- **Ubuntu Snap Steam support:** Added four Snap Steam path variants to `discover_steam_roots()`. Ubuntu users who installed Steam via the App Center (Snap) are now auto-detected.
- **`pgrep` availability handling:** If `pgrep` (from `procps`/`procps-ng`) is not installed, the game-running check is skipped gracefully instead of crashing the script.
- **Bash version guard:** Added an upfront check for Bash 4.0+ (required for `mapfile`).

### Documentation
- README completely rewritten for clarity and beginner-friendliness.
- Added: Table of Contents, Supported Systems table, Before You Start prerequisites table with per-distro install commands, Step-by-Step "How to Use It" section (including how to open a terminal on each distro), both `curl` and `wget` one-liner quick-start commands, Troubleshooting section, expanded FAQ.
- Added: This `CHANGELOG.md`.

### Code Quality
- Updated "Tested on" comment in the script header to list all confirmed distros.
- Version bumped to `1.2.0`.

---

## v1.1.0 — Initial Public Release

- Auto-detects Native Steam, Flatpak Steam, and Steam Deck installations.
- Scans `libraryfolders.vdf` to find prefixes across all library drives and MicroSD cards.
- Finds Epic Seven prefix dynamically via STOVE SDK log path (supports any App ID variant).
- Downloads WebView2 standalone installer from Microsoft (~205 MB, cached after first download).
- Installs WebView2 silently inside the game's Proton prefix.
- Handles partial installs (EdgeCore fallback + manual registry key writing).
- Final health check verifies files, registry, and STOVE SDK log status.
- Supports `--check`, `--prefix`, `--appid`, `--proton`, `--yes` flags.
- Tested on: Arch Linux (Omarchy / Hyprland / Wayland), Proton 10.0, Steam Linux Runtime 3.0 (sniper).
