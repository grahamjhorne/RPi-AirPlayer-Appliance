#!/bin/bash
# ============================================================================
# Air Player Appliance Builder - Raspberry Pi 5 (Idempotent Version)
# ============================================================================
# Builds/updates a hardened Air Player appliance - safe to run multiple times
# Can be used for initial installation or configuration updates
# ============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable

# ============================================================================
# Parse command line arguments
# ============================================================================
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run] [--force]"
            echo "  --dry-run  Show what would change without making changes"
            echo "  --force    Force all changes even if already configured"
            exit 1
            ;;
    esac
done

# ============================================================================
# Configuration - Load from properties file
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROPERTIES_FILE="${SCRIPT_DIR}/setup.properties"
BACKUP_DIR="/var/backups/airplayer-appliance"
STATE_FILE="/var/lib/airplayer-appliance/state"

# Check if properties file exists
if [[ ! -f "$PROPERTIES_FILE" ]]; then
    echo "ERROR: setup.properties not found!"
    echo "Please create setup.properties file"
    exit 1
fi

# Load properties
source "$PROPERTIES_FILE"

# ============================================================================
# Colors for output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# Utility Functions
# ============================================================================

# Backup a file before modifying it
backup_file() {
    local file=$1
    if [[ -f "$file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="${BACKUP_DIR}/$(basename $file).${timestamp}"
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo mkdir -p "$BACKUP_DIR"
            sudo cp -a "$file" "$backup_path"
            echo -e "${CYAN}    Backed up: $file → $backup_path${NC}"
        else
            echo -e "${CYAN}    Would backup: $file → $backup_path${NC}"
        fi
    fi
}

# Check if file content matches expected content
file_needs_update() {
    local file=$1
    local expected_content=$2
    
    if [[ ! -f "$file" ]]; then
        return 0  # File doesn't exist, needs update
    fi
    
    local current_content=$(cat "$file" 2>/dev/null || echo "")
    if [[ "$current_content" == "$expected_content" ]]; then
        return 1  # Content matches, no update needed
    else
        return 0  # Content differs, needs update
    fi
}

# Check if a line exists in a file
line_exists_in_file() {
    local file=$1
    local line=$2
    
    if [[ ! -f "$file" ]]; then
        return 1  # File doesn't exist
    fi
    
    if grep -Fxq "$line" "$file" 2>/dev/null; then
        return 0  # Line exists
    else
        return 1  # Line doesn't exist
    fi
}

# Check if systemd service is enabled
service_is_enabled() {
    local service=$1
    systemctl is-enabled "$service" &>/dev/null
}

# Check if systemd service is active
service_is_active() {
    local service=$1
    systemctl is-active "$service" &>/dev/null
}

# Initialize state directory
init_state() {
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo mkdir -p "$(dirname $STATE_FILE)"
        sudo touch "$STATE_FILE"
    fi
}

# Update state file with key=value
update_state() {
    local key=$1
    local value=$2
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Remove old value if exists, add new value
        sudo sed -i "/^${key}=/d" "$STATE_FILE" 2>/dev/null || true
        echo "${key}=${value}" | sudo tee -a "$STATE_FILE" > /dev/null
    fi
}

# Get value from state file
get_state() {
    local key=$1
    local default=${2:-""}
    
    if [[ -f "$STATE_FILE" ]]; then
        grep "^${key}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2- || echo "$default"
    else
        echo "$default"
    fi
}

# ============================================================================
# Main Script
# ============================================================================

echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║     Air Player Appliance Builder - Raspberry Pi 5                 ║
║     Idempotent Configuration Management                           ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}*** DRY RUN MODE - No changes will be made ***${NC}"
fi

echo "Starting at $(date)"
echo "Configuration: $PROPERTIES_FILE"
echo ""

init_state

CHANGES_MADE=false

# ============================================================================
# 1. NETWORK CONFIGURATION
# ============================================================================
echo -e "${BLUE}[1/10] Checking Network Configuration...${NC}"

NETWORK_FILE="/etc/systemd/network/10-${NETWORK_INTERFACE}.network"
NETWORK_CONTENT="[Match]
Name=${NETWORK_INTERFACE}

[Network]
Address=${NETWORK_IP}/${NETWORK_SUBNET}
Gateway=${NETWORK_GATEWAY}
DNS=${NETWORK_DNS}
IPv6AcceptRA=no
LinkLocalAddressing=no
IPv6SendRA=no"

if file_needs_update "$NETWORK_FILE" "$NETWORK_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Network configuration needs update${NC}"
    backup_file "$NETWORK_FILE"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$NETWORK_CONTENT" | sudo tee "$NETWORK_FILE" > /dev/null
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $NETWORK_FILE${NC}"
    fi
    echo -e "${GREEN}  ✓ Network configuration updated${NC}"
else
    echo -e "${GREEN}  ✓ Network already configured correctly${NC}"
fi

# Enable networkd services
if ! service_is_enabled "systemd-networkd.service" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Enabling systemd-networkd${NC}"
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo systemctl enable systemd-networkd.service
        sudo systemctl enable systemd-networkd-wait-online.service
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would enable: systemd-networkd services${NC}"
    fi
else
    echo -e "${GREEN}  ✓ systemd-networkd already enabled${NC}"
fi

update_state "network_ip" "${NETWORK_IP}"
update_state "network_configured" "$(date +%Y%m%d)"

# ============================================================================
# 2. SSH HARDENING
# ============================================================================
echo -e "${BLUE}[2/10] Checking SSH Configuration...${NC}"

SSH_CONFIG="/etc/ssh/sshd_config"
SSH_CONTENT="Include /etc/ssh/sshd_config.d/*.conf
Port ${SSH_PORT}
AddressFamily inet
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
AllowUsers ${SSH_ALLOWED_USER}
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys .ssh/authorized_keys2
IgnoreRhosts yes
PasswordAuthentication no
KerberosAuthentication no
AllowAgentForwarding no
AllowTcpForwarding no
X11Forwarding no
PrintMotd no
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no
TCPKeepAlive yes
Subsystem sftp /usr/lib/openssh/sftp-server"

if file_needs_update "$SSH_CONFIG" "$SSH_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → SSH configuration needs update${NC}"
    backup_file "$SSH_CONFIG"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$SSH_CONTENT" | sudo tee "$SSH_CONFIG" > /dev/null
        # Don't restart SSH if we're connected via SSH - will apply on next reboot
        echo -e "${CYAN}    Note: SSH config will apply on next reboot/restart${NC}"
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $SSH_CONFIG${NC}"
    fi
    echo -e "${GREEN}  ✓ SSH configuration updated${NC}"
else
    echo -e "${GREEN}  ✓ SSH already configured correctly${NC}"
fi

update_state "ssh_configured" "$(date +%Y%m%d)"

# ============================================================================
# 3. SYSTEM UPDATE & PACKAGE INSTALLATION
# ============================================================================
echo -e "${BLUE}[3/10] Checking System Packages...${NC}"

REQUIRED_PACKAGES=(
    xserver-xorg-core xserver-xorg xinit x11-xserver-utils
    libzip5 libgtk-3-0 libfreeimage3 libcurl4 libusb-1.0-0
    libcanberra-gtk3-module libegl1 libgles2
    openbox xterm unclutter ufw fail2ban
)

MISSING_PACKAGES=()
for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Installing/updating packages...${NC}"
    echo -e "${CYAN}    Missing packages: ${MISSING_PACKAGES[*]:-none (force mode)}${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo apt -qq update -y
        sudo apt -qq install -y "${REQUIRED_PACKAGES[@]}"
        sudo apt -qq full-upgrade -y
        sudo apt -qq autoremove --purge -y
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would run: apt update && apt install${NC}"
    fi
    echo -e "${GREEN}  ✓ Packages installed/updated${NC}"
else
    echo -e "${GREEN}  ✓ All required packages already installed${NC}"
fi

update_state "packages_installed" "$(date +%Y%m%d)"

# ============================================================================
# 4. AUTO-LOGIN CONFIGURATION
# ============================================================================
echo -e "${BLUE}[4/10] Checking Auto-Login Configuration...${NC}"

AUTOLOGIN_DIR="/etc/systemd/system/getty@tty1.service.d"
AUTOLOGIN_FILE="$AUTOLOGIN_DIR/autologin.conf"
AUTOLOGIN_CONTENT="[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${SYSTEM_USER} --noclear %I \$TERM
Type=idle"

sudo mkdir -p "$AUTOLOGIN_DIR"

if file_needs_update "$AUTOLOGIN_FILE" "$AUTOLOGIN_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Configuring auto-login${NC}"
    backup_file "$AUTOLOGIN_FILE"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$AUTOLOGIN_CONTENT" | sudo tee "$AUTOLOGIN_FILE" > /dev/null
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $AUTOLOGIN_FILE${NC}"
    fi
    echo -e "${GREEN}  ✓ Auto-login configured${NC}"
else
    echo -e "${GREEN}  ✓ Auto-login already configured${NC}"
fi

# Check .profile for startx
if ! grep -q "Start X automatically" "${SYSTEM_USER_HOME}/.profile" 2>/dev/null; then
    echo -e "${YELLOW}  → Adding auto-startx to .profile${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat >> "${SYSTEM_USER_HOME}/.profile" << 'PROFILE_EOF'

# Start X automatically on tty1
if [ "$(tty)" = "/dev/tty1" ] && [[ ! $DISPLAY ]]; then
    startx -- -nocursor
fi
PROFILE_EOF
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would append to: ${SYSTEM_USER_HOME}/.profile${NC}"
    fi
    echo -e "${GREEN}  ✓ Auto-startx added to .profile${NC}"
else
    echo -e "${GREEN}  ✓ Auto-startx already in .profile${NC}"
fi

update_state "autologin_configured" "$(date +%Y%m%d)"

# ============================================================================
# 5. X11 CONFIGURATION
# ============================================================================
echo -e "${BLUE}[5/10] Checking X11 Configuration...${NC}"

XINITRC_FILE="${SYSTEM_USER_HOME}/.xinitrc"
XINITRC_CONTENT="#!/bin/sh

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after ${CURSOR_IDLE_TIME} second
unclutter -idle ${CURSOR_IDLE_TIME} -root &

# Start openbox
exec openbox-session"

if file_needs_update "$XINITRC_FILE" "$XINITRC_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Updating .xinitrc${NC}"
    backup_file "$XINITRC_FILE"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$XINITRC_CONTENT" > "$XINITRC_FILE"
        chmod +x "$XINITRC_FILE"
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $XINITRC_FILE${NC}"
    fi
    echo -e "${GREEN}  ✓ .xinitrc updated${NC}"
else
    echo -e "${GREEN}  ✓ .xinitrc already configured${NC}"
fi

# Xorg configuration
XORG_CONF_DIR="/etc/X11/xorg.conf.d"
XORG_CONF_FILE="$XORG_CONF_DIR/10-vc4.conf"
XORG_CONTENT='Section "Device"
    Identifier "VC4 Graphics"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
    Option "Debug" "dmabuf_capable"
    Option "kmsdev" "/dev/dri/card1"
EndSection'

sudo mkdir -p "$XORG_CONF_DIR"

if file_needs_update "$XORG_CONF_FILE" "$XORG_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Updating Xorg configuration${NC}"
    backup_file "$XORG_CONF_FILE"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$XORG_CONTENT" | sudo tee "$XORG_CONF_FILE" > /dev/null
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $XORG_CONF_FILE${NC}"
    fi
    echo -e "${GREEN}  ✓ Xorg configuration updated${NC}"
else
    echo -e "${GREEN}  ✓ Xorg already configured${NC}"
fi

update_state "x11_configured" "$(date +%Y%m%d)"

# ============================================================================
# 6. BOOT CONFIGURATION (GPU, DISABLE WIFI/BT)
# ============================================================================
echo -e "${BLUE}[6/10] Checking Boot Configuration...${NC}"

BOOT_CONFIG="/boot/firmware/config.txt"
backup_file "$BOOT_CONFIG"

# Check/update gpu_mem
CURRENT_GPU_MEM=$(grep "^gpu_mem=" "$BOOT_CONFIG" 2>/dev/null | cut -d= -f2 || echo "")
if [[ "$CURRENT_GPU_MEM" != "$GPU_MEMORY" ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Setting GPU memory to ${GPU_MEMORY}MB${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        if grep -q "^gpu_mem=" "$BOOT_CONFIG"; then
            sudo sed -i "s/^gpu_mem=.*/gpu_mem=${GPU_MEMORY}/" "$BOOT_CONFIG"
        else
            echo "gpu_mem=${GPU_MEMORY}" | sudo tee -a "$BOOT_CONFIG" > /dev/null
        fi
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would set: gpu_mem=${GPU_MEMORY}${NC}"
    fi
else
    echo -e "${GREEN}  ✓ GPU memory already set to ${GPU_MEMORY}MB${NC}"
fi

# Check/add disable-wifi
if ! grep -q "^dtoverlay=disable-wifi" "$BOOT_CONFIG"; then
    echo -e "${YELLOW}  → Disabling WiFi${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "dtoverlay=disable-wifi" | sudo tee -a "$BOOT_CONFIG" > /dev/null
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would add: dtoverlay=disable-wifi${NC}"
    fi
else
    echo -e "${GREEN}  ✓ WiFi already disabled${NC}"
fi

# Check/add disable-bt
if ! grep -q "^dtoverlay=disable-bt" "$BOOT_CONFIG"; then
    echo -e "${YELLOW}  → Disabling Bluetooth${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "dtoverlay=disable-bt" | sudo tee -a "$BOOT_CONFIG" > /dev/null
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would add: dtoverlay=disable-bt${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Bluetooth already disabled${NC}"
fi

# Check/add IPv6 disable in cmdline
CMDLINE_FILE="/boot/firmware/cmdline.txt"
if ! grep -q "ipv6.disable=1" "$CMDLINE_FILE"; then
    echo -e "${YELLOW}  → Disabling IPv6 at boot${NC}"
    backup_file "$CMDLINE_FILE"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo sed -i 's/$/ ipv6.disable=1/' "$CMDLINE_FILE"
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would add ipv6.disable=1 to: $CMDLINE_FILE${NC}"
    fi
else
    echo -e "${GREEN}  ✓ IPv6 already disabled at boot${NC}"
fi

update_state "boot_configured" "$(date +%Y%m%d)"
update_state "gpu_memory" "$GPU_MEMORY"

# ============================================================================
# 7. AIR PLAYER INSTALLATION
# ============================================================================
echo -e "${BLUE}[7/10] Checking Air Player Installation...${NC}"

if [[ ! -f "${SCRIPT_DIR}/${AIRPLAYER_ZIP_NAME}" ]]; then
    echo -e "${RED}ERROR: Air Player zip not found: ${AIRPLAYER_ZIP_NAME}${NC}"
    exit 1
fi

# Always extract AirPlayer (handles upgrades)
echo -e "${YELLOW}  → Extracting/updating Air Player${NC}"

if [[ "$DRY_RUN" == "false" ]]; then
    sudo mkdir -p "${AIRPLAYER_INSTALL_DIR}"
    sudo chown -R ${SYSTEM_USER}:${SYSTEM_USER} "${AIRPLAYER_INSTALL_DIR}"
    
    unzip -o "${SCRIPT_DIR}/${AIRPLAYER_ZIP_NAME}" -d "${AIRPLAYER_INSTALL_DIR}/"
    
    sudo chmod +x ${AIRPLAYER_INSTALL_DIR}/Bootloader \
        ${AIRPLAYER_INSTALL_DIR}/AirPlayer \
        ${AIRPLAYER_INSTALL_DIR}/*.sh 2>/dev/null || true
    
    CHANGES_MADE=true
else
    echo -e "${CYAN}    Would extract: ${AIRPLAYER_ZIP_NAME} to ${AIRPLAYER_INSTALL_DIR}${NC}"
fi

echo -e "${GREEN}  ✓ Air Player extracted${NC}"

# udev rules for Knobster
UDEV_RULES="/etc/udev/rules.d/42-knobster.rules"
UDEV_CONTENT='SUBSYSTEM=="usb_device", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0e8a", MODE="0666"
SUBSYSTEM=="hidraw", SUBSYSTEMS=="usb", ENV{VID_PID}="16d0:0e8a", MODE="0666"'

if file_needs_update "$UDEV_RULES" "$UDEV_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Updating udev rules${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo mkdir -p /etc/udev/rules.d
        echo "$UDEV_CONTENT" | sudo tee "$UDEV_RULES" > /dev/null
        sudo udevadm control --reload-rules 2>/dev/null || true
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $UDEV_RULES${NC}"
    fi
else
    echo -e "${GREEN}  ✓ udev rules already configured${NC}"
fi

# Fix libzip compatibility
if [[ ! -L /usr/lib/aarch64-linux-gnu/libzip.so.4 ]]; then
    echo -e "${YELLOW}  → Creating libzip symlink${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo ln -sf /usr/lib/aarch64-linux-gnu/libzip.so.5 /usr/lib/aarch64-linux-gnu/libzip.so.4
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would create symlink: libzip.so.4 → libzip.so.5${NC}"
    fi
else
    echo -e "${GREEN}  ✓ libzip symlink already exists${NC}"
fi

update_state "airplayer_installed" "$(date +%Y%m%d)"

# ============================================================================
# 8. DISPLAY CONFIGURATION
# ============================================================================
echo -e "${BLUE}[8/10] Updating Display Configuration...${NC}"

OPENBOX_DIR="${SYSTEM_USER_HOME}/.config/openbox"
AUTOSTART_FILE="$OPENBOX_DIR/autostart"

echo -e "${YELLOW}  → Regenerating Openbox autostart (display config from properties)${NC}"

mkdir -p "$OPENBOX_DIR"

# Always regenerate display configuration from current properties
AUTOSTART_CONTENT="#!/bin/bash
#
# Air Player Display Configuration
# Generated by Air Player Appliance Builder
# Generated: $(date)
#
"

# Primary Display
if [[ "${PRIMARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    AUTOSTART_CONTENT+="# Primary Display - Main Panel
xrandr --output ${PRIMARY_DISPLAY} --mode ${PRIMARY_RESOLUTION} --rotate ${PRIMARY_ROTATION} --primary

"
fi

# Secondary Display
if [[ ${NUM_DISPLAYS} -ge 2 ]] && [[ "${SECONDARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    AUTOSTART_CONTENT+="# Secondary Display
xrandr --output ${SECONDARY_DISPLAY} --mode ${SECONDARY_RESOLUTION} --rotate ${SECONDARY_ROTATION} --${SECONDARY_POSITION} ${PRIMARY_DISPLAY}

"
fi

# Tertiary Display
if [[ ${NUM_DISPLAYS} -ge 3 ]] && [[ "${TERTIARY_DISPLAY_ENABLED:-no}" == "yes" ]]; then
    local ref_display="${SECONDARY_DISPLAY}"
    [[ "${TERTIARY_POSITION_REFERENCE}" == "PRIMARY" ]] && ref_display="${PRIMARY_DISPLAY}"
    
    AUTOSTART_CONTENT+="# Tertiary Display - DSI Screen
xrandr --output ${TERTIARY_DISPLAY} --mode ${TERTIARY_RESOLUTION} --rotate ${TERTIARY_ROTATION} --${TERTIARY_POSITION} ${ref_display}

"
fi

# Launch Air Player
AUTOSTART_CONTENT+="# Wait for displays to stabilize
sleep 2

# Launch Air Player (automatically detects and uses all displays)
cd ${AIRPLAYER_INSTALL_DIR}
./AirPlayer &"

if [[ "$DRY_RUN" == "false" ]]; then
    backup_file "$AUTOSTART_FILE"
    echo "$AUTOSTART_CONTENT" > "$AUTOSTART_FILE"
    chmod +x "$AUTOSTART_FILE"
    CHANGES_MADE=true
    echo -e "${GREEN}  ✓ Display configuration updated${NC}"
else
    echo -e "${CYAN}    Would write: $AUTOSTART_FILE${NC}"
    echo -e "${CYAN}    Displays: ${NUM_DISPLAYS}${NC}"
fi

update_state "num_displays" "$NUM_DISPLAYS"
update_state "display_config" "$(date +%Y%m%d)"

# ============================================================================
# 9. SYSTEM HARDENING & OPTIMIZATION
# ============================================================================
echo -e "${BLUE}[9/10] Checking System Hardening...${NC}"

# Volatile logging
JOURNALD_CONF="/etc/systemd/journald.conf"
if ! grep -q "^Storage=volatile" "$JOURNALD_CONF" || ! grep -q "^RuntimeMaxUse=32M" "$JOURNALD_CONF" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Configuring volatile logging${NC}"
    backup_file "$JOURNALD_CONF"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo sed -i 's/^#\?Storage=.*/Storage=volatile/' "$JOURNALD_CONF"
        sudo sed -i 's/^#\?RuntimeMaxUse=.*/RuntimeMaxUse=32M/' "$JOURNALD_CONF"
        sudo systemctl restart systemd-journald
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would configure volatile logging${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Volatile logging already configured${NC}"
fi

# Symlink /var/log apt and dpkg to /tmp
if [[ ! -L /var/log/apt ]] || [[ ! -L /var/log/dpkg ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Symlinking log directories to tmpfs${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo rm -rf /var/log/apt /var/log/dpkg 2>/dev/null || true
        sudo ln -sf /tmp /var/log/apt 2>/dev/null || true
        sudo ln -sf /tmp /var/log/dpkg 2>/dev/null || true
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would symlink: /var/log/apt and /var/log/dpkg to /tmp${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Log directories already symlinked${NC}"
fi

# System log levels
SYSTEM_CONF="/etc/systemd/system.conf"
if ! grep -q "^LogLevel=warning" "$SYSTEM_CONF" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Setting system log levels${NC}"
    backup_file "$SYSTEM_CONF"
    backup_file "/etc/systemd/user.conf"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo sed -i 's/^#\?LogLevel=.*/LogLevel=warning/' /etc/systemd/system.conf
        sudo sed -i 's/^#\?LogLevel=.*/LogLevel=warning/' /etc/systemd/user.conf
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would set LogLevel=warning${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Log levels already configured${NC}"
fi

# Modify fstab to add noatime
FSTAB="/etc/fstab"
if ! grep -q "noatime" "$FSTAB" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Adding noatime to filesystem mounts${NC}"
    backup_file "$FSTAB"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Add noatime to ext4 and vfat mounts that don't have it
        sudo sed -i '/^[^#]/ s/\([ \t]ext4[ \t][ \t]*\)\(defaults\)/\1defaults,noatime/' "$FSTAB"
        sudo sed -i '/^[^#]/ s/\([ \t]vfat[ \t][ \t]*\)\(defaults\)/\1defaults,noatime/' "$FSTAB"
        # Remove duplicates
        sudo sed -i 's/noatime,noatime/noatime/g' "$FSTAB"
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would add noatime to: $FSTAB${NC}"
    fi
else
    echo -e "${GREEN}  ✓ noatime already in fstab${NC}"
fi

# Disable swap
if [[ -n "$(sudo swapon --show)" ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Disabling swap${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo swapoff -a 2>/dev/null || true
        backup_file "$FSTAB"
        sudo sed -i '/^[^#].*swap/ s/^/#/' "$FSTAB"
        
        # Disable dphys-swapfile if present
        if systemctl list-unit-files | grep -q dphys-swapfile; then
            sudo systemctl disable dphys-swapfile.service 2>/dev/null || true
            sudo systemctl stop dphys-swapfile.service 2>/dev/null || true
        fi
        
        # Remove swap file
        sudo rm -f /var/swap 2>/dev/null || true
        
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would disable swap${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Swap already disabled${NC}"
fi

# Set swappiness to 0
SWAPPINESS_CONF="/etc/sysctl.d/99-swappiness.conf"
if [[ ! -f "$SWAPPINESS_CONF" ]] || ! grep -q "vm.swappiness=0" "$SWAPPINESS_CONF" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Setting swappiness to 0${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "vm.swappiness=0" | sudo tee "$SWAPPINESS_CONF" > /dev/null
        sudo sysctl -w vm.swappiness=0 2>/dev/null || true
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $SWAPPINESS_CONF${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Swappiness already set to 0${NC}"
fi

# Disable IPv6 via sysctl
IPV6_CONF="/etc/sysctl.d/99-disable-ipv6.conf"
if [[ ! -f "$IPV6_CONF" ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Disabling IPv6 via sysctl${NC}"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat | sudo tee "$IPV6_CONF" > /dev/null << 'IPV6EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
IPV6EOF
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $IPV6_CONF${NC}"
    fi
else
    echo -e "${GREEN}  ✓ IPv6 already disabled via sysctl${NC}"
fi

# Configure firewall
UFW_CONF="/etc/ufw/ufw.conf"
if ! grep -q "^IPV6=no" "$UFW_CONF" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Configuring firewall${NC}"
    backup_file "$UFW_CONF"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo sed -i 's/^IPV6=.*/IPV6=no/' "$UFW_CONF"
        
        sudo ufw --force default deny incoming
        sudo ufw --force default allow outgoing
        sudo ufw allow from ${FIREWALL_ALLOWED_NETWORK} to any port ${SSH_PORT} proto tcp
        sudo ufw allow out to any port 53 proto udp
        sudo ufw allow out to any port 123 proto udp
        sudo ufw allow from ${FIREWALL_AIRMANAGER_IP} to any port ${FIREWALL_PORT_HTTP} proto tcp
        sudo ufw allow from ${FIREWALL_AIRMANAGER_IP} to any port ${FIREWALL_PORT_API} proto tcp
        sudo ufw allow from ${FIREWALL_AIRMANAGER_IP} to any port ${FIREWALL_PORT_AIRPLAYER} proto tcp
        sudo ufw allow from ${FIREWALL_AIRMANAGER_IP} to any proto tcp
        sudo ufw allow from ${FIREWALL_AIRMANAGER_IP} to any proto udp
        sudo ufw --force enable
        
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would configure UFW firewall rules${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Firewall already configured${NC}"
fi

# Configure fail2ban
FAIL2BAN_CONF="/etc/fail2ban/jail.local"
if [[ ! -f "$FAIL2BAN_CONF" ]] || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → Configuring fail2ban${NC}"
    backup_file "$FAIL2BAN_CONF"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        cat | sudo tee "$FAIL2BAN_CONF" > /dev/null << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd
banaction = ufw

[sshd]
enabled = true
port = ${SSH_PORT}
logpath = /var/log/auth.log
EOF
        sudo systemctl enable fail2ban
        sudo systemctl restart fail2ban 2>/dev/null || true
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would write: $FAIL2BAN_CONF${NC}"
        echo -e "${CYAN}    Would enable and start fail2ban${NC}"
    fi
    echo -e "${GREEN}  ✓ fail2ban configured${NC}"
else
    echo -e "${GREEN}  ✓ fail2ban already configured${NC}"
fi

update_state "fail2ban_configured" "$(date +%Y%m%d)"

# Disable unnecessary services
echo -e "${YELLOW}  → Checking unnecessary services${NC}"
SERVICES_TO_DISABLE=(
    avahi-daemon cups triggerhappy ModemManager alsa-restore
    apt-daily.timer apt-daily-upgrade.timer keyboard-setup
    bluetooth systemd-timesyncd hciuart wpa_supplicant
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl list-unit-files | grep -q "^${service}"; then
        if service_is_enabled "$service" || service_is_active "$service"; then
            if [[ "$DRY_RUN" == "false" ]]; then
                sudo systemctl disable --now "$service" 2>/dev/null || true
            else
                echo -e "${CYAN}    Would disable: $service${NC}"
            fi
        fi
    fi
done

# Mask NetworkManager
if ! systemctl is-masked NetworkManager.service &>/dev/null; then
    if [[ "$DRY_RUN" == "false" ]]; then
        sudo systemctl mask NetworkManager.service 2>/dev/null || true
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would mask: NetworkManager${NC}"
    fi
fi

update_state "hardening_configured" "$(date +%Y%m%d)"

echo -e "${GREEN}  ✓ System hardening checked${NC}"

# ============================================================================
# 10. FINAL STEPS
# ============================================================================
echo -e "${BLUE}[10/10] Finalizing...${NC}"

# Create installation marker
MARKER_FILE="${SYSTEM_USER_HOME}/.airplayer-installed"
MARKER_CONTENT="Last updated: $(date)
Configuration: ${NUM_DISPLAYS} display(s)
Network: ${NETWORK_IP}/${NETWORK_SUBNET}
Swap: Disabled
Swappiness: 0
Filesystem: noatime enabled"

if [[ "$DRY_RUN" == "false" ]]; then
    echo "$MARKER_CONTENT" > "$MARKER_FILE"
fi

update_state "last_run" "$(date '+%Y%m%d_%H%M%S')"

echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                   Configuration Complete!                          ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}*** DRY RUN MODE - No changes were made ***${NC}"
    echo -e "${CYAN}Run without --dry-run to apply changes${NC}"
elif [[ "$CHANGES_MADE" == "true" ]]; then
    echo "Configuration Summary:"
    echo "  Network: ${NETWORK_IP}/${NETWORK_SUBNET}"
    echo "  Displays: ${NUM_DISPLAYS}"
    echo "  Air Manager: ${FIREWALL_AIRMANAGER_IP}"
    echo "  Swap: DISABLED (swappiness=0)"
    echo "  Filesystem: noatime enabled"
    echo ""
    echo "Changes were made. A reboot is recommended for all changes to take effect."
    echo ""
    echo "After reboot:"
    echo "  - Network will be at: ${NETWORK_IP}"
    echo "  - Air Player will start automatically"
    echo "  - Connect via: ssh ${SSH_ALLOWED_USER}@${NETWORK_IP}"
    echo ""
    read -p "Press Enter to reboot now, or Ctrl+C to reboot later..."
    sudo reboot
else
    echo "No changes were needed - system already configured correctly."
    echo ""
    echo "Current configuration:"
    echo "  Network: ${NETWORK_IP}/${NETWORK_SUBNET}"
    echo "  Displays: ${NUM_DISPLAYS}"
    echo "  Air Manager: ${FIREWALL_AIRMANAGER_IP}"
    echo ""
    echo "System is ready. No reboot required."
fi