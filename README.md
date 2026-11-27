# Spice3x Linux Launcher (beatmania IIDX 9th Style – 17 SIRIUS)

A universal, zero-config Bash launcher for running legacy **beatmania IIDX (9th Style through 17 SIRIUS)** on Linux via **Wine** and **Spice3x (Modified Spice2x)**.

## Features
* **Automatic Version Detection:** Identifies the exact IIDX version from the game folder name (`JAG`, `JAE`, `JAA`, `JAD`, and build date codes for `GOLD`, `DJ TROOPERS`, `EMPRESS`, and `SIRIUS`), including disambiguating `JAG` between **9th Style (`C02`)** and **DistorteD (`FDD`)**.
* **Isolated Wine Prefixes:** Creates a dedicated Wine prefix per style under `~/.wine-iidx/<GAME_ID>` so dependencies, codecs, and registry overrides never conflict across titles.
* **Automatic DirectX & BGA Codec Configuration:**
  * **Direct3D 8 Era (9th Style – DistorteD):** Installs `ffdshow` + `lavfilters`, configures `MPEG1`/`MPEG2` (`libavcodec`) registry keys, fetches `d3d8to9` automatically if 32-bit `d3d8.dll` is missing from system Wine (such as on modern WoW64 Wine builds), and applies `Discard = 1` via `d3d8.ini` to prevent 2D sprite ghosting.
  * **Direct3D 9 Era (GOLD – SIRIUS):** Installs `d3dx9` + `lavfilters` so Direct3D 9 meshes and DirectShow BGA videos render cleanly inside the game window without spawning external `ActiveMovie Window` popups.
* **Automatic Legacy Dump Fixes:**
  * Quarantines conflicting local `d3dx9_24.dll` wrappers to `.bak`.
  * Detects legacy packed `libavs-win32.dll` / `libavs-win32-ea3.dll` binaries (containing anti-VM stubs that crash under Wine) and swaps in clean unpacked versions from sibling build folders if present.
  * Automatically applies a safe, backed-up 1-byte `PROG CHKSUM` bypass on **IIDX 10th Style (`D01/JAE`)** so extra launcher files (`spice.exe`, `args.sh`, etc.) inside `JAE/` do not trigger `HDD DATA ERROR(PROG CHKSUM)`.
* **Full-Display Scaling & Strict 60Hz Locking:** Automatically detects your active display resolution (`1080p`, `1440p`, `4K`, etc.), launches Spice2x borderless across the full display via XWayland (`WAYLAND_DISPLAY=""` + `Decorated=N`), and locks refresh to 60Hz (`-graphics-force-refresh 60`, `libstrangle`, `MangoHud`, and VSync environment variables).
* **User-Editable Parameters (`args.sh`):** Generates `args.sh` on first run so you can customize Spice2x flags (`-ea`, `-url`, `-card0`, `-p`, etc.) without editing the launcher script.

## Supported Versions

| Version | Render API | Auto-Installed Dependencies | Expected Folder / Build Codes |
| :--- | :--- | :--- | :--- |
| **IIDX 09: 9th Style** | Direct3D 8 | `ffdshow`, `lavfilters`, `d3d8to9` | `JAG` (with `C02` / `9th` in path) |
| **IIDX 10: 10th Style** | Direct3D 8 | `ffdshow`, `lavfilters`, `d3d8to9` | `JAE` |
| **IIDX 11: IIDX RED** | Direct3D 8 | `ffdshow`, `lavfilters`, `d3d8to9` | `JAA` |
| **IIDX 12: HAPPY SKY** | Direct3D 8 | `ffdshow`, `lavfilters`, `d3d8to9` | `JAD` |
| **IIDX 13: DistorteD** | Direct3D 8 | `ffdshow`, `lavfilters`, `d3d8to9` | `JAG` (with `FDD` / `13` in path) |
| **IIDX 14: GOLD** | Direct3D 9 | `d3dx9`, `lavfilters` | `2006122900`, `2007022101`, `2007030700`, `2007040200`, `2007072301` |
| **IIDX 15: DJ TROOPERS** | Direct3D 9 | `d3dx9`, `lavfilters` | `2007112800`, `2007122500`, `2008020500`, `2008031100` |
| **IIDX 16: EMPRESS** | Direct3D 9 | `d3dx9`, `lavfilters` | `2008111900`, `2008112600`, `2008120800`, `2009010600`, `2009072200` |
| **IIDX 17: SIRIUS** | Direct3D 9 | `d3dx9`, `lavfilters` | `2009102100`, `2009102300`, `2009111700`, `2009122100`, `2010071200` |

## Prerequisites
* **Wine** (`wine-staging` or standard `wine` 9.0+)
* **`cabextract`** (required by Winetricks to extract DirectX and codec packages)
* **`python3`** (optional; used for the automatic 10th Style `PROG CHKSUM` check)
* *(Optional)* `winetricks` (downloaded automatically to `~/.wine-iidx/bin/` if not installed system-wide)
* *(Optional)* `libstrangle` or `mangohud` for external 60fps frame limiting

### Quick Install on Popular Distros
* **Fedora:** `sudo dnf install wine cabextract`
* **Arch / SteamOS:** `sudo pacman -S wine cabextract`
* **Ubuntu / Debian:** `sudo apt install wine cabextract`

## Usage

1. Place `Spice2x-Linux-Launcher.sh` directly inside the game's executable folder alongside `spice.exe` and `spicecfg.exe`.
2. Make the script executable:
   ```bash
   chmod +x Spice2x-Linux-Launcher.sh
   ```
3. **Configure Controls & Spice2x Options:**
   ```bash
   ./Spice2x-Linux-Launcher.sh -c
   ```
4. **Launch the Game:**
   ```bash
   ./Spice2x-Linux-Launcher.sh
   ```
5. **Debug Mode (Verbose Wine & Step Logs):**
   ```bash
   ./Spice2x-Linux-Launcher.sh -debug
   ```

## Customizing Parameters (`args.sh`)
On first launch, the script creates `args.sh` in the same directory:

```bash
#!/usr/bin/env bash
# Optional: Force a specific display resolution (e.g., "2560x1440").
# Leave empty ("") to automatically match your active monitor's resolution.
DESKTOP_RES=""

# Add custom Spice2x arguments below:
SPICE_ARGS=(
    -iidx
    -ea
    # -card0 0000000000000000
    # -p 0000000000000000
    # -url http://localhost:8080
)
```

## Troubleshooting & Notes
* **Game stuck on network / I/O check:** Add `-ea` (for Spice2x's built-in offline e-Amusement emulation) or your `-url` / `-card0` / `-p` flags to `SPICE_ARGS` in `args.sh`.
* **Audio timing / latency:** Run `./Spice2x-Linux-Launcher.sh -c`, open the **Options** tab, and select **WASAPI Shared** or **DirectSound**.
* **Resetting a Wine prefix:** To re-run first-time dependency installation for a specific title, delete its marker or prefix folder:
  ```bash
  wineserver -k
  rm -rf ~/.wine-iidx/<GAME_ID>
  ```
* **IIDX 17 SIRIUS (`osprey.bin` HDD Data Check):** Stock `JDJ` dumps require intact `osprey.bin` hash manifests inside `data/sd_data/`, `data/graph_data/`, and `data/movie/` (or a `bm2dx.exe` pre-patched with the community *Skip HDD Data Check* patch) to pass the boot-time drive integrity check.
* **Game resets all keybinds:** Every version of IIDX gets its own dedicated prefix folder and leads to spice2x to not find any configurations, please set them up if you're booting it for the first time.

## Known Bugs
* **Game freezes after enabling e-amusement services:** You must reset the entire game for e-amusement services to work.
* **DJ TROOPERS & EMPRESS showing "NETWORK WARNING":** There is no way to fix it at the moment and could just be a bug on spice3x's side, will update with a fix if there is in the future.
