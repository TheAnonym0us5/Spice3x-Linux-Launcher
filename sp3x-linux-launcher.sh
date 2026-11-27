#!/usr/bin/env bash
set -eE

DEBUG_MODE=0; CONFIG_MODE=0; PASS_ARGS=()
for arg in "$@"; do
    case "$arg" in
        -debug|--debug) DEBUG_MODE=1 ;;
        -c|--config) CONFIG_MODE=1 ;;
        *) PASS_ARGS+=("$arg") ;;
    esac
done

debug_log() { [ "$DEBUG_MODE" -eq 1 ] && echo "[DEBUG] $*"; }
CURRENT_STEP="Startup"; STEP_HINT="Check file permissions."
on_error() {
    local rc=$?
    echo -e "\n=== LAUNCHER ERROR ===\nStep: $CURRENT_STEP (line $1)\nCmd : $BASH_COMMAND\nHint: $STEP_HINT\n======================" >&2
    exit "$rc"
}
trap 'on_error $LINENO' ERR

CURRENT_STEP="Resolving directory"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
cd "$SCRIPT_DIR"
FOLDER_NAME="$(basename "$SCRIPT_DIR")"
UPPER_PATH="${SCRIPT_DIR^^}"
GAME_ID=""; RENDER_API="DX8"; WINETRICKS_PKGS="ffdshow lavfilters"

CURRENT_STEP="Identifying IIDX version"
STEP_HINT="Place this script in the game's root/executable folder (JAG, JAE, JAA, JAD, or *YYYYMMDD00*)."
case "$FOLDER_NAME" in
    *JAE*) GAME_ID="IIDX10_10th_Style" ;;
    *JAA*) GAME_ID="IIDX11_RED" ;;
    *JAD*) GAME_ID="IIDX12_HAPPY_SKY" ;;
    *JAG*)
        if [[ "$UPPER_PATH" == *"FDD"* || "$UPPER_PATH" == *"13"* || "$UPPER_PATH" == *"DISTORTED"* ]]; then
            GAME_ID="IIDX13_DistorteD"
        elif [[ "$UPPER_PATH" == *"C02"* || "$UPPER_PATH" == *"IIDX9"* || "$UPPER_PATH" == *"9TH"* ]]; then
            GAME_ID="IIDX09_9th_Style"
        else
            echo "ERROR: Ambiguous 'JAG' folder. Parent path must contain C02/9th or FDD/13." >&2; exit 1
        fi ;;
    *2006122900*|*2007022101*|*2007030700*|*2007040200*|*2007072301*) GAME_ID="IIDX14_GOLD"; RENDER_API="DX9"; WINETRICKS_PKGS="d3dx9 lavfilters" ;;
    *2008031100*|*2008020500*|*2007122500*|*2007112800*) GAME_ID="IIDX15_DJ_TROOPERS"; RENDER_API="DX9"; WINETRICKS_PKGS="d3dx9 lavfilters" ;;
    *2008111900*|*2008112600*|*2008120800*|*2009010600*|*2009072200*) GAME_ID="IIDX16_EMPRESS"; RENDER_API="DX9"; WINETRICKS_PKGS="d3dx9 lavfilters" ;;
    *2009102300*|*2009111700*|*2009102100*|*2009122100*|*2010071200*) GAME_ID="IIDX17_SIRIUS"; RENDER_API="DX9"; WINETRICKS_PKGS="d3dx9 lavfilters" ;;
    *) echo "ERROR: Unrecognized IIDX folder '$FOLDER_NAME' in $SCRIPT_DIR" >&2; exit 1 ;;
esac
echo "Detected $GAME_ID ($RENDER_API)..."

CURRENT_STEP="Checking Wine & files"
command -v wine >/dev/null 2>&1 || { echo "ERROR: 'wine' is not installed." >&2; exit 1; }
[ -f "$SCRIPT_DIR/spice.exe" ] || { echo "ERROR: 'spice.exe' not found." >&2; exit 1; }

PARENT_DIR="$(dirname "$SCRIPT_DIR")"
for target_dir in "$SCRIPT_DIR" "$SCRIPT_DIR"/* "$PARENT_DIR"/*; do
    [ -d "$target_dir" ] || continue
    [ -f "$target_dir/d3dx9_24.dll" ] && mv -f "$target_dir/d3dx9_24.dll" "$target_dir/d3dx9_24.dll.bak" && debug_log "Backed up $target_dir/d3dx9_24.dll"
    [ ! -f "$target_dir/d3d8.dll" ] && [ -f "$target_dir/d3d8.dll.bak" ] && mv -f "$target_dir/d3d8.dll.bak" "$target_dir/d3d8.dll"
done

for avs_dll in libavs-win32.dll libavs-win32-ea3.dll; do
    if [ -f "$SCRIPT_DIR/$avs_dll" ] && grep -q "HtpecDll" "$SCRIPT_DIR/$avs_dll" 2>/dev/null; then
        CLEAN_AVS=""
        for search_dir in "$SCRIPT_DIR"/* "$PARENT_DIR"/*; do
            [ -d "$search_dir" ] && [ "$search_dir" != "$SCRIPT_DIR" ] && [ -f "$search_dir/$avs_dll" ] && ! grep -q "HtpecDll" "$search_dir/$avs_dll" 2>/dev/null && CLEAN_AVS="$search_dir/$avs_dll" && break
        done
        if [ -n "$CLEAN_AVS" ]; then
            echo "Replacing packed $avs_dll with clean version..."
            mv -f "$SCRIPT_DIR/$avs_dll" "$SCRIPT_DIR/${avs_dll}.bak"
            cp "$CLEAN_AVS" "$SCRIPT_DIR/$avs_dll"
        fi
    fi
done

if [ "$GAME_ID" = "IIDX10_10th_Style" ] && [ -f "$SCRIPT_DIR/bm2dx.exe" ] && command -v python3 >/dev/null 2>&1; then
    python3 -c '
import shutil
p = bytearray(open("bm2dx.exe", "rb").read())
orig = bytes.fromhex("e8c72cffff85c0740f68c0964b00")
if p.count(orig) == 1:
    shutil.copy2("bm2dx.exe", "bm2dx.exe.bak")
    off = p.index(orig)
    p[off + 7] = 0xeb
    open("bm2dx.exe", "wb").write(p)
    print("Applied 10th Style PROG CHKSUM bypass patch (backup: bm2dx.exe.bak)")
'
fi

ARGS_FILE="$SCRIPT_DIR/args.sh"
if [ ! -f "$ARGS_FILE" ]; then
    printf '#!/usr/bin/env bash\nDESKTOP_RES=""\nSPICE_ARGS=(\n    -iidx\n)\n' > "$ARGS_FILE"
    chmod +x "$ARGS_FILE" 2>/dev/null || true
    echo "Created default parameter file at: $ARGS_FILE"
fi
DESKTOP_RES=""; SPICE_ARGS=()
# shellcheck source=/dev/null
source "$ARGS_FILE"

if [ -z "$DESKTOP_RES" ]; then
    command -v xrandr >/dev/null 2>&1 && DESKTOP_RES=$(xrandr --query 2>/dev/null | awk '/ primary / {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+x[0-9]+\+/) {sub(/\+.*/,"",$i); print $i; exit}}')
    [ -z "$DESKTOP_RES" ] && command -v xrandr >/dev/null 2>&1 && DESKTOP_RES=$(xrandr --query 2>/dev/null | awk '/\*/ {print $1; exit}')
    [ -z "$DESKTOP_RES" ] && command -v kscreen-doctor >/dev/null 2>&1 && DESKTOP_RES=$(kscreen-doctor -o 2>/dev/null | grep -oE '[0-9]+x[0-9]+@[0-9]+' | head -n1 | cut -d'@' -f1)
    [ -z "$DESKTOP_RES" ] && command -v wlr-randr >/dev/null 2>&1 && DESKTOP_RES=$(wlr-randr 2>/dev/null | awk '/current/ {print $1; exit}')
    [ -z "$DESKTOP_RES" ] && DESKTOP_RES=$(cat /sys/class/drm/card*-*/modes 2>/dev/null | grep -E '^[0-9]+x[0-9]+$' | head -n1)
    DESKTOP_RES="${DESKTOP_RES:-1920x1080}"
fi
DESKTOP_W="${DESKTOP_RES%x*}"; DESKTOP_H="${DESKTOP_RES#*x}"
echo "Using display resolution: ${DESKTOP_W}x${DESKTOP_H}"

export WINEPREFIX="$HOME/.wine-iidx/$GAME_ID"
export MESA_VK_WSI_PRESENT_MODE=fifo DXVK_FRAME_RATE=60 vblank_mode=1 __GL_SYNC_TO_VBLANK=1
[ -n "${DISPLAY:-}" ] && export WAYLAND_DISPLAY=""
[ "$DEBUG_MODE" -eq 0 ] && export WINEDEBUG="-all"

if [ ! -f "$WINEPREFIX/.iidx_ready" ]; then
    echo "Initializing dedicated Wine prefix for $GAME_ID ($WINETRICKS_PKGS)..."
    CURRENT_STEP="Preparing winetricks"; STEP_HINT="Check internet or install winetricks & cabextract."
    mkdir -p "$HOME/.wine-iidx/bin"
    WINETRICKS_BIN="$(command -v winetricks 2>/dev/null || echo "$HOME/.wine-iidx/bin/winetricks")"
    if [ ! -x "$WINETRICKS_BIN" ]; then
        echo "Downloading standalone winetricks..."
        curl -fsSL https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks -o "$WINETRICKS_BIN" 2>/dev/null || wget -qO "$WINETRICKS_BIN" https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
        chmod +x "$WINETRICKS_BIN"
    fi
    CURRENT_STEP="Running wineboot & winetricks ($WINETRICKS_PKGS)"
    wineboot --init
    # shellcheck disable=SC2086
    "$WINETRICKS_BIN" -q $WINETRICKS_PKGS
    if [ "$RENDER_API" = "DX8" ]; then
        D3D8_DIR="$WINEPREFIX/drive_c/windows/system32"
        [ -d "$WINEPREFIX/drive_c/windows/syswow64" ] && D3D8_DIR="$WINEPREFIX/drive_c/windows/syswow64"
        if [ ! -f "$SCRIPT_DIR/d3d8.dll" ] && [ ! -f "$D3D8_DIR/d3d8.dll" ]; then
            echo "32-bit d3d8.dll missing from system Wine; fetching d3d8to9 fallback..."
            curl -fsSL "https://github.com/crosire/d3d8to9/releases/download/v1.16.0/d3d8.dll" -o "$D3D8_DIR/d3d8.dll" 2>/dev/null || wget -qO "$D3D8_DIR/d3d8.dll" "https://github.com/crosire/d3d8to9/releases/download/v1.16.0/d3d8.dll"
        fi
        printf '[D3D8]\nDiscard = 1\n' > "$D3D8_DIR/d3d8.ini"
        [ ! -f "$SCRIPT_DIR/d3d8.ini" ] && printf '[D3D8]\nDiscard = 1\n' > "$SCRIPT_DIR/d3d8.ini"
        wine reg add "HKCU\Software\Wine\DllOverrides" /v d3d8 /t REG_SZ /d "native,builtin" /f
        wine reg add "HKCU\Software\GNU\ffdshow" /v mpeg1 /t REG_DWORD /d 1 /f
        wine reg add "HKCU\Software\GNU\ffdshow" /v mpeg2 /t REG_DWORD /d 1 /f
        wine reg add "HKCU\Software\GNU\ffdshow" /v isBlacklist /t REG_DWORD /d 0 /f
    fi
    touch "$WINEPREFIX/.iidx_ready"
    echo "Setup for $GAME_ID complete!"
fi

[ "$CONFIG_MODE" -eq 1 ] && exec wine spicecfg.exe "${SPICE_ARGS[@]}" "${PASS_ARGS[@]}"

wine reg add "HKCU\Software\Wine\X11 Driver" /v Decorated /t REG_SZ /d "N" /f >/dev/null 2>&1 || true

CMD=(wine spice.exe -w -windowborder 0 -windowsize "${DESKTOP_W},${DESKTOP_H}" -graphics-force-refresh 60 "${SPICE_ARGS[@]}" "${PASS_ARGS[@]}")
if command -v strangle >/dev/null 2>&1; then
    exec strangle 60 "${CMD[@]}"
elif command -v mangohud >/dev/null 2>&1; then
    MANGOHUD_CONFIG="fps_limit=60,no_display" exec mangohud "${CMD[@]}"
else
    exec "${CMD[@]}"
fi
