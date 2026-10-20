#!/bin/sh

# wget -qO - https://raw.githubusercontent.com/popking159/mywebuicontroller/refs/heads/main/myinstaller.sh | /bin/sh
# =========================================================================
# CONFIGURATION (Change these for different repositories)
# =========================================================================
PLUGIN_NAME="MyWebUIController"
USERNAME="popking159"
REPO="mywebuicontroller"

# 1. PYTHON DEPENDENCIES (Write only the core module names without prefixes)
# The script automatically adds 'python-' for Py2 or 'python3-' for Py3.
# Leave empty "" if the plugin doesn't need any Python dependencies.
PY_DEPENDS="requests core compression difflib json six twisted-web"

# 2. SYSTEM DEPENDENCIES (Binary utilities installed exactly as written, e.g., unrar)
# Leave empty "" if none are needed.
SYS_DEPENDS=""
# =========================================================================

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Dynamically construct the download link
PLUGIN_URL="https://github.com/${USERNAME}/${REPO}/raw/refs/heads/main/main.tar.gz"

# Workspace paths
TMP_DIR="/var/volatile/tmp"
[ -d "$TMP_DIR" ] || TMP_DIR="/tmp"
TMP_FILE="$TMP_DIR/main_install.tar.gz"

PKG_MANAGER=""
PYTHON_VERSION=""
FINAL_DEPENDS=""

log() {
    # Automatically colorize based on the log tag
    case "$1" in
        *\[INFO\]*) echo -e "${CYAN}$1${NC}" ;;
        *\[OK\]*) echo -e "${GREEN}$1${NC}" ;;
        *\[WARN\]*) echo -e "${YELLOW}$1${NC}" ;;
        *\[ERROR\]*) echo -e "${RED}$1${NC}" ;;
        *) echo -e "$1" ;;
    esac
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

is_pkg_installed() {
    pkg="$1"
    if [ "$PKG_MANAGER" = "opkg" ]; then
        if [ -f /var/lib/opkg/status ]; then
            grep -q "^Package: $pkg$" /var/lib/opkg/status && return 0
        fi
        opkg list-installed 2>/dev/null | grep -q "^$pkg[[:space:]-]" && return 0
        return 1
    fi

    if [ "$PKG_MANAGER" = "apt" ]; then
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" && return 0
        return 1
    fi
    return 1
}

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}         $PLUGIN_NAME INSTALLER UTILITY             ${NC}"
echo -e "${GREEN}====================================================${NC}"

# 1. Detect Environment & Python Version
if has_cmd opkg; then
    PKG_MANAGER="opkg"
elif has_cmd apt-get; then
    PKG_MANAGER="apt"
fi
log "[INFO] Package manager detected: ${PKG_MANAGER:-None}"

if has_cmd python3; then
    PYTHON_VERSION="3"
    PY_PREFIX="python3-"
elif has_cmd python; then
    PYTHON_VERSION="2"
    PY_PREFIX="python-"
fi
log "[INFO] Detected Python Environment: Python $PYTHON_VERSION"

# 2. Build the Final Dependency List based on Python version
for dep in $PY_DEPENDS; do
    FINAL_DEPENDS="$FINAL_DEPENDS ${PY_PREFIX}${dep}"
done
for dep in $SYS_DEPENDS; do
    FINAL_DEPENDS="$FINAL_DEPENDS $dep"
done

# 3. Check and Download Dependencies (Strict Mode)
if [ -n "$FINAL_DEPENDS" ]; then
    log "[INFO] Verifying required dependencies..."
    for pkg in $FINAL_DEPENDS; do
        if is_pkg_installed "$pkg"; then
            log "[OK] Already installed: $pkg"
        else
            log "[INFO] Downloading and installing: $pkg"
            if [ "$PKG_MANAGER" = "opkg" ]; then
                opkg install "$pkg" >/dev/null 2>&1
            elif [ "$PKG_MANAGER" = "apt" ]; then
                DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" >/dev/null 2>&1
            fi
            
            # Strict Verification: If it failed to install, abort immediately
            if is_pkg_installed "$pkg"; then
                log "[OK] Successfully installed: $pkg"
            else
                log "[ERROR] Required dependency '$pkg' could not be installed! Aborting setup."
                exit 1
            fi
        fi
    done
else
    log "[INFO] No dependencies specified in configuration. Skipping dependency phase."
fi

# 4. Download Plugin Archive
log "[INFO] Downloading main plugin tree archive..."
rm -f "$TMP_FILE"
wget -q --no-check-certificate "$PLUGIN_URL" -O "$TMP_FILE"

if [ ! -s "$TMP_FILE" ]; then
    log "[ERROR] Download failed or file is empty!"
    rm -f "$TMP_FILE"
    exit 1
fi

# 5. Extract directly to ROOT (/)
log "[INFO] Extracting payload contents to system paths..."
tar -xzf "$TMP_FILE" -C /
if [ $? -ne 0 ]; then
    log "[ERROR] Extraction failed!"
    rm -f "$TMP_FILE"
    exit 1
fi

rm -f "$TMP_FILE"
sync

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}          $PLUGIN_NAME INSTALLATION COMPLETE        ${NC}"
echo -e "${GREEN}====================================================${NC}"

exit 0
