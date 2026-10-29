# Epic Seven — STOVE ERROR Code -80 Fix for Linux & Steam Deck

An automated, one-command fix for the **STOVE ERROR Code:-80** popups when running **Epic Seven** through Proton on Linux or Steam Deck.

---

## The Problem

When launching Epic Seven on Linux or Steam Deck, you run into popups that block the game:

1. **On launch / loading screen:**
   > *The service is currently unstable. If the issue persists, please contact our Customer Service.*  
   > `Cmd:STOVE_INITIALIZE Code:-80`

2. **In the lobby (when opening notices or the shop):**
   > `Cmd:STANDBY Code:-80`

The game itself is completely fine — the problem is Smilegate's STOVE SDK. It uses **Microsoft Edge WebView2** to render web dialogs (login, events, announcements). On Windows, WebView2 is bundled with the operating system, but a clean Proton prefix doesn't have it installed.

When WebView2 is missing, the STOVE log reports:
```text
ERROR  Failed to initialize ViewUISDK, ViewUIResultCpp[code=1,externalCode=0,
       errMessage=Fail to initialize ViewUI. WebView rumtime is not available.,externalMessage=]
```

Installing the official Microsoft WebView2 Runtime into the game's Proton prefix resolves the issue permanently.

---

## Quick Start (Automated Fix)

Make sure **Epic Seven is closed**, then open a terminal and run:

```bash
curl -sSL https://raw.githubusercontent.com/luckyprinter/epic-seven-linux-fix-error-code-80/main/fix-epic7-webview2.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/luckyprinter/epic-seven-linux-fix-error-code-80.git
cd epic-seven-linux-fix-error-code-80
chmod +x fix-epic7-webview2.sh
./fix-epic7-webview2.sh
```

The script will automatically:
- Locate your Steam installation (Native Steam, Flatpak Steam, or Steam Deck).
- Scan all library drives and MicroSD cards for your Epic Seven prefix.
- Auto-detect your installed Proton version and container runtime.
- Download the official Microsoft WebView2 standalone installer (~205 MB).
- Install the runtime silently into the prefix and configure the required registry keys.
- Run a health check to confirm everything is working.

---

## Health Check / Diagnostics

Want to check if your prefix is already fixed without changing anything? Run:

```bash
./fix-epic7-webview2.sh --check
```

Example healthy output:
```text
[OK]  WebView2 runtime files: Present (v156.0.4314.50)
[OK]  Windows Registry keys: Present and configured
[OK]  Log diagnosis: ViewUISDK initialized successfully! (No error -80)
[OK]  Status: WebView2 is fully installed and working in this prefix!
```

---

## Options & Flags

| Flag | Description |
|---|---|
| `-c, --check` | Verify current prefix health without downloading or installing anything |
| `-p, --prefix <PATH>` | Manually specify the path to your Epic Seven compatdata folder |
| `-a, --appid <ID>` | Manually specify Steam App ID (e.g. `5019180`, `3678970`, `5129800`) |
| `--proton <PATH>` | Manually specify a custom `proton` binary |
| `-y, --yes` | Run non-interactively (useful for scripts) |
| `-h, --help` | Display usage instructions |

---

## Manual Installation (Step-by-Step)

If you prefer doing everything by hand without running a script:

### 1. Download the Standalone Installer
Download the x64 Evergreen Standalone installer directly from Microsoft:
```bash
curl -L -o ~/Downloads/MicrosoftEdgeWebView2RuntimeInstallerX64.exe "https://go.microsoft.com/fwlink/?linkid=2124701"
```
*(Do not use the small web bootstrapper — it frequently stalls inside Wine).*

### 2. Set Paths for Your System
Adjust the paths to match your Steam library and Proton version:
```bash
STEAM="$HOME/.local/share/Steam"
# Replace 5019180 with your game's App ID if different (e.g. 3678970 or 5129800)
PFX="$STEAM/steamapps/compatdata/5019180"
PROTON="$STEAM/steamapps/common/Proton 10.0/proton"
SNIPER="$STEAM/steamapps/common/SteamLinuxRuntime_sniper/run"
```

### 3. Run the Installer
```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
export STEAM_COMPAT_DATA_PATH="$PFX"
"$SNIPER" -- "$PROTON" run ~/Downloads/MicrosoftEdgeWebView2RuntimeInstallerX64.exe /silent /install
```
*(It runs silently in the background and takes about 60–90 seconds).*

### 4. Register the Keys (if needed)
If the installer finishes without writing the registry keys, add them manually:
```bash
VER="$(ls "$PFX/pfx/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" | grep -E '^[0-9]' | sort -V | tail -1)"
G='{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'

cat << REG > /tmp/wv2.reg
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\\$G]
"pv"="$VER"
"name"="Microsoft Edge WebView2 Runtime"
"location"="C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application"

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\EdgeUpdate\Clients\\$G]
"pv"="$VER"
"name"="Microsoft Edge WebView2 Runtime"
"location"="C:\\Program Files (x86)\\Microsoft\\EdgeWebView\\Application"
REG

"$SNIPER" -- "$PROTON" run regedit /S 'Z:\tmp\wv2.reg'
```

---

## Frequently Asked Questions

#### Will verifying game files or reinstalling undo this?
Yes. When Steam verifies integrity or recreates a prefix, it wipes the `compatdata` directory. If the error ever comes back, simply re-run the script. Because the installer `.exe` is cached in `~/Downloads`, re-applying takes less than 30 seconds.

#### Will this get my account banned?
No. This installs Microsoft's official WebView2 component inside Wine/Proton. It does not modify game binaries, inject code into the game process, or alter network traffic.

#### Does this touch anything outside the game's prefix?
No. Everything is contained entirely inside the game's Proton prefix (`steamapps/compatdata/<id>/pfx`). Your host Linux system remains completely untouched.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
