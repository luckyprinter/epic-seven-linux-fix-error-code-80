# Epic Seven — STOVE ERROR Code -80 Fix for Linux & Steam Deck

A one-command fix for the **STOVE ERROR Code:-80** popups when running **Epic Seven** on Linux or Steam Deck through Steam (Proton).

---

## Contents

- [What Is This?](#what-is-this)
- [Tested On](#tested-on)
- [Before You Start](#before-you-start)
- [How to Use It](#how-to-use-it)
- [Check If It Worked](#check-if-it-worked)
- [Advanced Options](#advanced-options)
- [Manual Installation](#manual-installation-step-by-step)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

---

## What Is This?

When you run Epic Seven on Linux, you might see this popup every time you launch the game:

> *The service is currently unstable. If the issue persists, please contact our Customer Service.*
> `Cmd:STOVE_INITIALIZE Code:-80`

And again in the lobby when the shop or notices try to load:

> `Cmd:STANDBY Code:-80`

**The game itself is fine.** The problem is that Epic Seven's STOVE launcher uses a Windows component called **Microsoft Edge WebView2** to display its web panels (login screen, shop, announcements). On Windows, this component comes pre-installed with the OS. On Linux (running through Steam's Proton compatibility layer), it's missing.

This script installs the official Microsoft WebView2 Runtime inside the game's isolated Proton environment. Nothing is installed on your Linux system itself — everything stays inside the game's own folder.

---

## Tested On

| System | Steam Install Type | Status |
|---|---|---|
| **Steam Deck (SteamOS)** | Native (built-in) | ✅ Confirmed working |
| **Arch Linux** | Native | ✅ Confirmed working |
| **CachyOS** | Native | ✅ Confirmed working |
| **Ubuntu 22.04 LTS** | Native | ✅ Confirmed working |
| **Manjaro / EndeavourOS** | Native or Flatpak | 🟡 Should work — not live tested |
| **Ubuntu 24.04 LTS** | Native, Flatpak, or Snap | 🟡 Should work — not live tested |
| **Linux Mint / Pop!_OS / Zorin OS** | Native or Flatpak | 🟡 Should work — not live tested |
| **Fedora / Bazzite** | Native or Flatpak | 🟡 Should work — not live tested |
| **openSUSE Tumbleweed / Leap** | Native or Flatpak | 🟡 Should work — not live tested |
| **Debian** | Native or Flatpak | 🟡 Should work — may need `curl` installed first |

**✅ Confirmed** = tested on a real machine and verified working.
**🟡 Should work** = the script's path detection covers these setups, but nobody has reported back yet. If it works or doesn't work for you, feel free to open an issue or leave a comment — it helps improve accuracy here.

> **Using Flatpak or Snap Steam?** Paths are auto-detected, but these haven't been tested on a live machine. If you run into issues, see [Troubleshooting](#troubleshooting).

---

## Before You Start

You need one of these installed on your system. Most Linux distributions already have at least one — you probably don't need to do anything.

| Tool | Check if installed | Install it |
|---|---|---|
| **curl** *(preferred)* | Run: `curl --version` | Ubuntu/Debian: `sudo apt install curl` · Fedora: `sudo dnf install curl` · Arch: `sudo pacman -S curl` · openSUSE: `sudo zypper install curl` |
| **wget** *(alternative)* | Run: `wget --version` | Ubuntu/Debian: `sudo apt install wget` · Fedora: `sudo dnf install wget` · Arch: `sudo pacman -S wget` · openSUSE: `sudo zypper install wget` |

> **Steam Deck:** Both are already installed. No action needed.

---

## How to Use It

### Step 1 — Close Epic Seven completely

Make sure Epic Seven is **not running** before you start. If it's open, close it from Steam.

---

### Step 2 — Open a terminal

A terminal is the text window where you type commands. Here's how to open one on your system:

| System | How to open a terminal |
|---|---|
| **Ubuntu / Mint / Fedora** | Press **Ctrl + Alt + T** on your keyboard |
| **Arch / Manjaro** | Right-click the desktop → look for "Terminal" or "Konsole" in your app menu |
| **openSUSE** | Press the **Super** key (Windows key) → type *Terminal* → press Enter |
| **Steam Deck** | Press the power button → tap **Switch to Desktop** → look for **Konsole** in the taskbar |

---

### Step 3 — Run the script

Copy and paste **one** of these commands into the terminal, then press **Enter**:

**If you have `curl`:**
```bash
curl -sSL https://raw.githubusercontent.com/luckyprinter/epic-seven-linux-fix-error-code-80/main/fix-epic7-webview2.sh | bash
```

**If you have `wget` instead:**
```bash
wget -qO- https://raw.githubusercontent.com/luckyprinter/epic-seven-linux-fix-error-code-80/main/fix-epic7-webview2.sh | bash
```

The script will:
1. Find your Epic Seven installation automatically
2. Download the WebView2 installer from Microsoft (~205 MB)
3. Install it silently into the game's folder (takes about 60–90 seconds)
4. Confirm that everything worked

You don't need to type anything else — just wait for it to finish.

---

### Step 4 — Launch Epic Seven normally

Once the script says **"Fix completed successfully!"**, open Steam and launch Epic Seven as you normally would. The STOVE Code -80 popups will be gone.

---

## Check If It Worked

Not sure if the fix is already applied? Run this to check without changing anything:

```bash
# Download the script first, then run with --check:
curl -sSL https://raw.githubusercontent.com/luckyprinter/epic-seven-linux-fix-error-code-80/main/fix-epic7-webview2.sh -o fix-epic7-webview2.sh
chmod +x fix-epic7-webview2.sh
./fix-epic7-webview2.sh --check
```

You should see something like:
```
[OK]  WebView2 runtime files: Present (v156.0.4314.50)
[OK]  Windows Registry keys: Present and configured
[OK]  Log status: ViewUISDK initialized successfully — no Error -80!
[OK]  Status: WebView2 is fully installed. Your prefix is healthy!
```

---

## Advanced Options

For users who want more control:

| Option | What it does | Example |
|---|---|---|
| `--check` | Diagnose your prefix without installing anything | `./fix-epic7-webview2.sh --check` |
| `-a <ID>` | Force a specific Steam App ID | `./fix-epic7-webview2.sh -a 5019180` |
| `-p <PATH>` | Point to your prefix folder manually | `./fix-epic7-webview2.sh -p ~/.local/share/Steam/steamapps/compatdata/5019180` |
| `--proton <PATH>` | Use a specific Proton version | `./fix-epic7-webview2.sh --proton ~/.local/share/Steam/steamapps/common/Proton\ 10.0/proton` |
| `-y` | Skip all confirmation prompts (for scripts) | `./fix-epic7-webview2.sh -y` |
| `-h` | Show all available options | `./fix-epic7-webview2.sh --help` |

---

## Manual Installation (Step-by-Step)

If you prefer to do everything by hand without running a script, here are the full steps.

### 1. Download the standalone installer

```bash
curl -L -o ~/Downloads/MicrosoftEdgeWebView2RuntimeInstallerX64.exe \
  "https://go.microsoft.com/fwlink/?linkid=2124701"
```

*(Use the standalone installer — not the small web bootstrapper, which tends to stall inside Wine.)*

### 2. Set the paths for your system

```bash
STEAM="$HOME/.local/share/Steam"
PFX="$STEAM/steamapps/compatdata/5019180"       # Adjust App ID if needed
PROTON="$STEAM/steamapps/common/Proton 10.0/proton"
SNIPER="$STEAM/steamapps/common/SteamLinuxRuntime_sniper/run"
```

Check that they exist before continuing:
```bash
ls -d "$PFX/pfx" "$PROTON" "$SNIPER"
```

### 3. Run the installer

```bash
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM"
export STEAM_COMPAT_DATA_PATH="$PFX"
"$SNIPER" -- "$PROTON" run ~/Downloads/MicrosoftEdgeWebView2RuntimeInstallerX64.exe /silent /install
```

*(Runs silently in the background for about 60–90 seconds.)*

### 4. Register the registry keys

```bash
VER="$(ls "$PFX/pfx/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" \
  | grep -E '^[0-9]' | sort -V | tail -n 1)"
G='{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'

cat <<REG > /tmp/wv2.reg
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

## Troubleshooting

### "curl: command not found" or "wget: command not found"

You need to install one of them. Open a terminal and run the command for your distro:

| Distro | Command |
|---|---|
| Ubuntu / Debian / Mint | `sudo apt install curl` |
| Fedora / RHEL | `sudo dnf install curl` |
| Arch / Manjaro | `sudo pacman -S curl` |
| openSUSE | `sudo zypper install curl` |
| Steam Deck | `curl` is pre-installed — if missing, run: `sudo steamos-readonly disable && sudo pacman -S curl` |

---

### "Could not find any Steam installation"

The script couldn't find where Steam is installed. Try:

1. If you installed Steam normally → check that `~/.local/share/Steam` exists
2. If you use Flatpak Steam → check that `~/.var/app/com.valvesoftware.Steam` exists
3. If Steam is installed somewhere else, run the script with your prefix path:

```bash
./fix-epic7-webview2.sh -p /path/to/steamapps/compatdata/5019180
```

---

### "Could not find Epic Seven Proton prefix"

Epic Seven must have been launched at least once through Steam so that Proton creates the prefix folder. If you've never launched it:

1. Launch Epic Seven from Steam and let it reach the login screen
2. Close it
3. Run the script again

If you know your App ID, you can also pass it directly:
```bash
./fix-epic7-webview2.sh -a 5019180
```

---

### The fix says it worked but the error still appears

Try running the **check** first to confirm the current state:
```bash
./fix-epic7-webview2.sh --check
```

If the check says something is missing, run the script again without `--check`. The WebView2 installer's registry step sometimes needs a second pass.

---

### Script can't find Proton (custom Proton builds like cachy-proton)

If you're on a distro that installs Proton through its own package manager (e.g. CachyOS with `cachy-proton`, Nobara with GE-Proton via dnf), the script may not detect it automatically. Point it directly with `--proton`:

```bash
./fix-epic7-webview2.sh --proton "/path/to/your/proton"
```

Not sure where your Proton binary is? Run this to find it:

```bash
find /usr ~/.local ~/.steam -name 'proton' 2>/dev/null | grep -v 'dist\|python'
```

Example for CachyOS with cachy-proton:
```bash
./fix-epic7-webview2.sh --proton "$HOME/.local/share/Steam/steamapps/common/Proton - Experimental/proton"
```

---

### "Verifying game files" brought the error back

Steam can wipe the prefix folder when you verify game files or reinstall the game. If the error comes back, just run the script again. The WebView2 installer is cached in `~/.cache/epic7-fix/` so it won't need to download again.

---

## FAQ

**Will this get my account banned?**
No. This installs Microsoft's official WebView2 component inside Wine/Proton's isolated environment. It does not modify any game files, inject code into the game process, or touch network traffic.

**Does this change anything on my Linux system?**
No. Everything is contained inside the game's Proton prefix folder (`steamapps/compatdata/<id>/pfx`). Your host Linux system is completely untouched.

**I have multiple Steam library locations / a MicroSD card. Will the script find the game?**
Yes. The script reads your Steam library configuration file (`libraryfolders.vdf`) to scan all registered library locations, including external drives and MicroSD cards on the Steam Deck.

**I use GE-Proton or a custom Proton build (cachy-proton, etc.). Will that work?**
The script checks the standard `compatibilitytools.d` locations including system-wide paths used by package managers. If it still can't find your Proton, use `--proton` to point to it directly — see [Troubleshooting](#troubleshooting) for details.

---

## License

MIT — see [LICENSE](LICENSE) for details.
