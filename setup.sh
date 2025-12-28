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
# Error handling and cleanup
# ============================================================================
cleanup_and_log() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_message "!!! SCRIPT FAILED WITH EXIT CODE: $exit_code !!!"
        log_message "Last successful section may be visible above"
        echo -e "${RED}Setup failed! Check log: $SETUP_LOG_LINK${NC}"
    fi
}

trap cleanup_and_log EXIT

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
# Logging Configuration
# ============================================================================
SETUP_LOG="/tmp/airplayer-setup-$(date +%Y%m%d-%H%M%S).log"
SETUP_LOG_LINK="/tmp/airplayer-setup-latest.log"

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$SETUP_LOG"
}

# Function to log and display
log_and_echo() {
    local message="$1"
    echo -e "$message"
    # Strip color codes for log file
    local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    log_message "$clean_message"
}

# Create symlink to latest log
ln -sf "$SETUP_LOG" "$SETUP_LOG_LINK"

# Log script start
log_message "========================================="
log_message "Air Player Appliance Builder - Setup Log"
log_message "========================================="
log_message "Script started"
log_message "Dry run: $DRY_RUN"
log_message "Force mode: $FORCE"
log_message "Log file: $SETUP_LOG"

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
    log_and_echo "${YELLOW}*** DRY RUN MODE - No changes will be made ***${NC}"
fi

log_and_echo "Starting at $(date)"
log_and_echo "Configuration: $PROPERTIES_FILE"
log_and_echo "Setup log: $SETUP_LOG"
echo ""

init_state

CHANGES_MADE=false

# ============================================================================
# 1. NETWORK CONFIGURATION
# ============================================================================
log_message "=== SECTION 1: Network Configuration ==="
echo -e "${BLUE}[1/10] Checking Network Configuration...${NC}"
log_message "Checking network configuration"

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
log_message "=== SECTION 2: SSH Hardening ==="
echo -e "${BLUE}[2/10] Checking SSH Configuration...${NC}"

SSH_CONFIG="/etc/ssh/sshd_config"

# Remove cloud-init SSH config overrides that conflict with our configuration
if [[ "$DRY_RUN" == "false" ]]; then
    sudo rm -f /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
    log_message "Removed cloud-init SSH config overrides"
fi

SSH_CONTENT="
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
UsePAM yes
TCPKeepAlive yes
Subsystem sftp /usr/lib/openssh/sftp-server"

if file_needs_update "$SSH_CONFIG" "$SSH_CONTENT" || [[ "$FORCE" == "true" ]]; then
    echo -e "${YELLOW}  → SSH configuration needs update${NC}"
    backup_file "$SSH_CONFIG"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        echo "$SSH_CONTENT" | sudo tee "$SSH_CONFIG" > /dev/null
        
        # Ensure SSH privilege separation directory exists (required for sshd to start)
        sudo mkdir -p /run/sshd
        sudo chmod 755 /run/sshd
        log_message "Created /run/sshd directory"
        
        # Test SSH configuration before proceeding
        if sudo /usr/sbin/sshd -t 2>/dev/null; then
            log_message "SSH configuration validated successfully"
        else
            log_message "ERROR: SSH configuration validation failed!"
            echo -e "${RED}  ✗ SSH config validation failed - restoring backup${NC}"
            backup_file="${SSH_CONFIG}.bak"
            if [[ -f "$backup_file" ]]; then
                sudo cp "$backup_file" "$SSH_CONFIG" 2>/dev/null || true
            fi
            exit 1
        fi
        
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
log_message "=== SECTION 3: System Packages ==="
echo -e "${BLUE}[3/10] Checking System Packages...${NC}"

REQUIRED_PACKAGES=(
    xserver-xorg-core xserver-xorg xinit x11-xserver-utils
    libzip5 libgtk-3-0t64 libfreeimage3 libcurl4t64 libusb-1.0-0
    libcanberra-gtk3-module libegl1 libgles2
    openbox xterm unclutter ufw fail2ban bc
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
log_message "=== SECTION 4: Auto-Login Configuration ==="
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
log_message "=== SECTION 5: X11 Configuration ==="
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
log_message "=== SECTION 6: Boot Configuration ==="
echo -e "${BLUE}[6/10] Checking Boot Configuration...${NC}"

BOOT_CONFIG="/boot/firmware/config.txt"
backup_file "$BOOT_CONFIG"

# ============================================================================
# GPU / CMA MEMORY CONFIGURATION (Pi 4 and Pi 5 compatible)
# ============================================================================
# Raspberry Pi 4: Uses gpu_mem parameter (fixed allocation)
# Raspberry Pi 5: Uses CMA overlay (dynamic allocation via dtoverlay=cma,cma-XXX)
# ============================================================================

# Detect Pi model if not specified in properties
if [[ -z "$RASPI_MODEL" ]] || [[ "$RASPI_MODEL" != "4" && "$RASPI_MODEL" != "5" ]]; then
    PI_MODEL_STRING=$(cat /proc/device-tree/model 2>/dev/null || echo "")
    if [[ "$PI_MODEL_STRING" == *"Raspberry Pi 5"* ]]; then
        RASPI_MODEL=5
        echo -e "${YELLOW}  → Auto-detected: Raspberry Pi 5${NC}"
        log_message "Auto-detected Raspberry Pi 5"
    else
        RASPI_MODEL=4
        echo -e "${YELLOW}  → Auto-detected: Raspberry Pi 4 (or earlier)${NC}"
        log_message "Auto-detected Raspberry Pi 4 or earlier"
    fi
fi

if [[ "$RASPI_MODEL" == "5" ]]; then
    # ========================================================================
    # RASPBERRY PI 5: Use CMA instead of gpu_mem
    # ========================================================================
    echo -e "${YELLOW}  → Configuring GPU memory for Raspberry Pi 5 (CMA)${NC}"
    log_message "Raspberry Pi 5 detected - using CMA instead of gpu_mem"
    
    # Remove obsolete gpu_mem setting (Pi 5 ignores it)
    if grep -q "^gpu_mem=" "$BOOT_CONFIG"; then
        echo -e "${YELLOW}  → Removing obsolete gpu_mem setting (not used on Pi 5)${NC}"
        log_message "Removing gpu_mem from config.txt (obsolete on Pi 5)"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo sed -i '/^gpu_mem=/d' "$BOOT_CONFIG"
        fi
    fi
    
    # Add or update CMA overlay
    CMA_SETTING="dtoverlay=cma,cma-${GPU_MEMORY}"
    
    if ! grep -q "^dtoverlay=cma,cma-${GPU_MEMORY}" "$BOOT_CONFIG" || [[ "$FORCE" == "true" ]]; then
        echo -e "${YELLOW}  → Setting CMA pool to ${GPU_MEMORY}MB for Air Player${NC}"
        log_message "Adding ${CMA_SETTING} to config.txt"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Remove any existing CMA overlay
            sudo sed -i '/^dtoverlay=cma/d' "$BOOT_CONFIG"
            
            # Add CMA overlay after [all] section
            if grep -q "^\[all\]" "$BOOT_CONFIG"; then
                sudo sed -i "/^\[all\]/a $CMA_SETTING" "$BOOT_CONFIG"
            else
                echo "$CMA_SETTING" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            fi
            
            log_message "CMA overlay configured: ${GPU_MEMORY}MB pool"
            CHANGES_MADE=true
        else
            echo -e "${CYAN}    Would add: $CMA_SETTING${NC}"
        fi
    else
        echo -e "${GREEN}  ✓ CMA already configured for Pi 5 (${GPU_MEMORY}MB)${NC}"
        log_message "CMA already configured"
    fi
    
else
    # ========================================================================
    # RASPBERRY PI 4 (and earlier): Use traditional gpu_mem
    # ========================================================================
    echo -e "${YELLOW}  → Configuring GPU memory for Raspberry Pi 4 (gpu_mem)${NC}"
    log_message "Raspberry Pi 4 or earlier detected - using gpu_mem"
    
    # Check current gpu_mem value
    CURRENT_GPU_MEM=$(grep "^gpu_mem=" "$BOOT_CONFIG" 2>/dev/null | cut -d= -f2 || echo "")
    
    if [[ "$CURRENT_GPU_MEM" != "$GPU_MEMORY" ]] || [[ "$FORCE" == "true" ]]; then
        echo -e "${YELLOW}  → Setting GPU memory to ${GPU_MEMORY}MB${NC}"
        log_message "Setting gpu_mem=${GPU_MEMORY} in config.txt"
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Remove all existing gpu_mem entries
            sudo sed -i '/^gpu_mem=/d' "$BOOT_CONFIG"
            
            # Add gpu_mem after [all] section
            if grep -q "^\[all\]" "$BOOT_CONFIG"; then
                sudo sed -i "/^\[all\]/a gpu_mem=${GPU_MEMORY}" "$BOOT_CONFIG"
            else
                echo "gpu_mem=${GPU_MEMORY}" | sudo tee -a "$BOOT_CONFIG" > /dev/null
            fi
            
            log_message "GPU memory configured: ${GPU_MEMORY}MB"
            CHANGES_MADE=true
        else
            echo -e "${CYAN}    Would set gpu_mem=${GPU_MEMORY}${NC}"
        fi
    else
        echo -e "${GREEN}  ✓ GPU memory already set to ${GPU_MEMORY}MB${NC}"
        log_message "GPU memory already configured"
    fi
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
log_message "=== SECTION 7: Air Player Installation ==="
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
log_message "=== SECTION 8: Display Configuration ==="
echo -e "${BLUE}[8/10] Updating Display Configuration...${NC}"

OPENBOX_DIR="${SYSTEM_USER_HOME}/.config/openbox"
AUTOSTART_FILE="$OPENBOX_DIR/autostart"

echo -e "${YELLOW}  → Checking Openbox autostart configuration${NC}"

mkdir -p "$OPENBOX_DIR"

# Generate display configuration from current properties
AUTOSTART_CONTENT="#!/bin/bash
#
# Air Player Display Configuration
# Generated by Air Player Appliance Builder
# Generated: $(date)
#

# Wait for displays to be detected
sleep 2

# Detect which displays are actually connected
export DISPLAY=:0
CONNECTED_DISPLAYS=\$(xrandr | grep ' connected' | awk '{print \$1}')

echo \"Detected displays: \$CONNECTED_DISPLAYS\" >> /tmp/display-config.log

"

# Primary Display
if [[ "${PRIMARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    AUTOSTART_CONTENT+="# Primary Display - Main Panel
if echo \"\$CONNECTED_DISPLAYS\" | grep -q \"${PRIMARY_DISPLAY}\"; then
    xrandr --output ${PRIMARY_DISPLAY} --mode ${PRIMARY_RESOLUTION} --rotate ${PRIMARY_ROTATION} --primary
    echo \"Configured ${PRIMARY_DISPLAY}\" >> /tmp/display-config.log
else
    echo \"WARNING: ${PRIMARY_DISPLAY} not connected\" >> /tmp/display-config.log
fi

"
fi

# Secondary Display
if [[ ${NUM_DISPLAYS} -ge 2 ]] && [[ "${SECONDARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    AUTOSTART_CONTENT+="# Secondary Display
if echo \"\$CONNECTED_DISPLAYS\" | grep -q \"${SECONDARY_DISPLAY}\"; then
    xrandr --output ${SECONDARY_DISPLAY} --mode ${SECONDARY_RESOLUTION} --rotate ${SECONDARY_ROTATION} --${SECONDARY_POSITION} ${PRIMARY_DISPLAY}
    echo \"Configured ${SECONDARY_DISPLAY}\" >> /tmp/display-config.log
else
    echo \"WARNING: ${SECONDARY_DISPLAY} not connected\" >> /tmp/display-config.log
fi

"
fi

# Tertiary Display
if [[ ${NUM_DISPLAYS} -ge 3 ]] && [[ "${TERTIARY_DISPLAY_ENABLED:-no}" == "yes" ]]; then
    local ref_display="${SECONDARY_DISPLAY}"
    [[ "${TERTIARY_POSITION_REFERENCE}" == "PRIMARY" ]] && ref_display="${PRIMARY_DISPLAY}"
    
    AUTOSTART_CONTENT+="# Tertiary Display - DSI Screen
if echo \"\$CONNECTED_DISPLAYS\" | grep -q \"${TERTIARY_DISPLAY}\"; then
    xrandr --output ${TERTIARY_DISPLAY} --mode ${TERTIARY_RESOLUTION} --rotate ${TERTIARY_ROTATION} --${TERTIARY_POSITION} ${ref_display}
    echo \"Configured ${TERTIARY_DISPLAY}\" >> /tmp/display-config.log
else
    echo \"WARNING: ${TERTIARY_DISPLAY} not connected\" >> /tmp/display-config.log
fi

"
fi

# Launch Air Player
AUTOSTART_CONTENT+="# Wait for display configuration to complete
sleep 1

# Launch Air Player (automatically detects and uses all displays)
cd ${AIRPLAYER_INSTALL_DIR}
./AirPlayer &"

# Check if file needs update
if file_needs_update "$AUTOSTART_FILE" "$AUTOSTART_CONTENT" || [[ "$FORCE" == "true" ]]; then
    if [[ "$DRY_RUN" == "false" ]]; then
        backup_file "$AUTOSTART_FILE"
        echo "$AUTOSTART_CONTENT" > "$AUTOSTART_FILE"
        chmod +x "$AUTOSTART_FILE"
        CHANGES_MADE=true
        echo -e "${GREEN}  ✓ Display configuration updated${NC}"
    else
        echo -e "${CYAN}    Would write: $AUTOSTART_FILE${NC}"
    fi
else
    echo -e "${GREEN}  ✓ Display configuration already correct${NC}"
fi

echo -e "${CYAN}    Displays: ${NUM_DISPLAYS}${NC}"

update_state "num_displays" "$NUM_DISPLAYS"
update_state "display_config" "$(date +%Y%m%d)"

# ============================================================================
# 9. SYSTEM HARDENING & OPTIMIZATION
# ============================================================================
log_message "=== SECTION 9: System Hardening ==="
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

# ============================================================================
# DISABLE SWAP COMPLETELY (including zram for Ubuntu Server 24.04)
# ============================================================================
log_message "Checking swap configuration"
echo -e "${YELLOW}  → Checking swap configuration${NC}"

SWAP_ACTIVE=false
SWAP_CONFIGURED=false
ZRAM_ACTIVE=false

# Check if swap is currently active
if [[ -n "$(sudo swapon --show)" ]]; then
    SWAP_ACTIVE=true
    # Check specifically for zram
    if sudo swapon --show | grep -q zram; then
        ZRAM_ACTIVE=true
    fi
fi

# Check if swap is configured in fstab
if grep -q "^[^#].*swap" "$FSTAB" 2>/dev/null; then
    SWAP_CONFIGURED=true
fi

# Check if dphys-swapfile exists and is enabled
DPHYS_EXISTS=false
if systemctl list-unit-files 2>/dev/null | grep -q dphys-swapfile; then
    DPHYS_EXISTS=true
fi

# Check if swap file exists
SWAP_FILE_EXISTS=false
if [[ -f /var/swap ]] || [[ -f /swap ]] || [[ -f /swapfile ]]; then
    SWAP_FILE_EXISTS=true
fi

# Check for zram-related services/packages
ZRAM_EXISTS=false
if systemctl list-unit-files 2>/dev/null | grep -q zramswap; then
    ZRAM_EXISTS=true
fi
if dpkg -l 2>/dev/null | grep -q zram-config; then
    ZRAM_EXISTS=true
fi

# Check if zram is properly disabled (blacklisted)
ZRAM_BLACKLISTED=false
if [[ -f /etc/modprobe.d/blacklist-zram.conf ]] && grep -q "blacklist zram" /etc/modprobe.d/blacklist-zram.conf 2>/dev/null; then
    ZRAM_BLACKLISTED=true
fi

# Check if zram module is loaded (not necessarily a problem if blacklisted)
ZRAM_MODULE_LOADED=false
if lsmod | grep -q "^zram "; then
    ZRAM_MODULE_LOADED=true
fi

# Determine if swap actually needs disabling
NEEDS_SWAP_DISABLE=false

if [[ "$SWAP_ACTIVE" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: swap is active"
elif [[ "$SWAP_CONFIGURED" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: configured in fstab"
elif [[ "$DPHYS_EXISTS" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: dphys-swapfile service exists"
elif [[ "$SWAP_FILE_EXISTS" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: swap files exist"
elif [[ "$ZRAM_ACTIVE" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: zram swap is active"
elif [[ "$ZRAM_MODULE_LOADED" == "true" ]] && [[ "$ZRAM_BLACKLISTED" == "false" ]]; then
    # Module loaded but not blacklisted = needs proper disabling
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: zram module loaded but not blacklisted"
elif [[ "$FORCE" == "true" ]]; then
    NEEDS_SWAP_DISABLE=true
    log_message "Swap disable needed: force mode"
fi

if [[ "$NEEDS_SWAP_DISABLE" == "true" ]]; then
    echo -e "${YELLOW}  → Disabling swap completely (including zram)${NC}"
    log_message "Disabling swap (active=$SWAP_ACTIVE, configured=$SWAP_CONFIGURED, dphys=$DPHYS_EXISTS, files=$SWAP_FILE_EXISTS, zram=$ZRAM_ACTIVE)"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Turn off any active swap immediately
        log_message "Running: swapoff -a"
        sudo swapoff -a 2>/dev/null || true
        
        # Disable zram specifically (Ubuntu Server 24.04 uses this)
        if [[ "$ZRAM_ACTIVE" == "true" ]] || [[ "$ZRAM_EXISTS" == "true" ]]; then
            echo -e "${YELLOW}  → Disabling zram swap (Ubuntu Server 24.04)${NC}"
            log_message "Disabling zram swap"
            
            # Turn off zram swap
            sudo swapoff /dev/zram0 2>/dev/null || true
            
            # Stop and mask zramswap service
            sudo systemctl stop zramswap.service 2>/dev/null || true
            sudo systemctl disable zramswap.service 2>/dev/null || true
            sudo systemctl mask zramswap.service 2>/dev/null || true
            
            # Remove zram-config package if present
            if dpkg -l 2>/dev/null | grep -q zram-config; then
                log_message "Removing zram-config package"
                sudo apt-get remove -y --purge zram-config 2>/dev/null || true
                sudo apt-get autoremove -y 2>/dev/null || true
            fi
            
            # Blacklist zram kernel module
            if [[ ! -f /etc/modprobe.d/blacklist-zram.conf ]]; then
                echo "blacklist zram" | sudo tee /etc/modprobe.d/blacklist-zram.conf > /dev/null
                log_message "Blacklisted zram kernel module"
            fi
            
            # Remove zram module if currently loaded
            sudo modprobe -r zram 2>/dev/null || true
            
            # Mask systemd swap targets
            sudo systemctl mask swap.target 2>/dev/null || true
            sudo systemctl mask dev-zram0.swap 2>/dev/null || true
            
            log_message "zram swap disabled and blacklisted"
        fi
        
        # Comment out swap entries in fstab
        backup_file "$FSTAB"
        sudo sed -i '/^[^#].*swap/ s/^/#/' "$FSTAB"
        
        # Disable and mask dphys-swapfile service (prevents re-enabling)
        if [[ "$DPHYS_EXISTS" == "true" ]]; then
            sudo systemctl stop dphys-swapfile.service 2>/dev/null || true
            sudo systemctl disable dphys-swapfile.service 2>/dev/null || true
            sudo systemctl mask dphys-swapfile.service 2>/dev/null || true
        fi
        
        # Disable swap configuration file
        if [[ -f /etc/dphys-swapfile ]]; then
            sudo sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=0/' /etc/dphys-swapfile
        fi
        
        # Remove swap files
        sudo rm -f /var/swap /swap /swapfile 2>/dev/null || true
        
        # Double-check it's off
        if [[ -n "$(sudo swapon --show)" ]]; then
            echo -e "${RED}  ✗ Warning: Swap still active after disable attempt${NC}"
            log_message "WARNING: Swap still active after disable"
        else
            echo -e "${GREEN}  ✓ All swap disabled (including zram)${NC}"
            log_message "All swap successfully disabled"
        fi
        
        CHANGES_MADE=true
    else
        echo -e "${CYAN}    Would disable swap completely${NC}"
        echo -e "${CYAN}    Would disable zram (Ubuntu Server 24.04)${NC}"
        echo -e "${CYAN}    Would mask dphys-swapfile service${NC}"
        echo -e "${CYAN}    Would remove swap files${NC}"
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
        sudo tee "$IPV6_CONF" > /dev/null << 'IPV6EOF'
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
echo -e "${YELLOW}  → Checking firewall configuration${NC}"

# Check if firewall is already configured correctly
UFW_NEEDS_CONFIG=false

# Check if UFW is enabled
if ! sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    UFW_NEEDS_CONFIG=true
    log_message "Firewall needs config: not active"
fi

# Check if IPv6 is disabled in ufw.conf
UFW_CONF="/etc/ufw/ufw.conf"
if [[ "$UFW_NEEDS_CONFIG" == "false" ]]; then
    if ! grep -q "^IPV6=no" "$UFW_CONF" 2>/dev/null; then
        UFW_NEEDS_CONFIG=true
        log_message "Firewall needs config: IPv6 not disabled"
    fi
fi

# Check if critical rules exist
if [[ "$UFW_NEEDS_CONFIG" == "false" ]]; then
    UFW_STATUS=$(sudo ufw status numbered 2>/dev/null)
    
    # Check SSH rule
    if ! echo "$UFW_STATUS" | grep -q "${SSH_PORT}/tcp.*ALLOW.*${FIREWALL_ALLOWED_NETWORK}"; then
        UFW_NEEDS_CONFIG=true
        log_message "Firewall needs config: SSH rule missing or incorrect"
    fi
    
    # Check DNS rule
    if ! echo "$UFW_STATUS" | grep -q "53/udp.*ALLOW OUT"; then
        UFW_NEEDS_CONFIG=true
        log_message "Firewall needs config: DNS rule missing"
    fi
    
    # Check NTP rule
    if ! echo "$UFW_STATUS" | grep -q "123/udp.*ALLOW OUT"; then
        UFW_NEEDS_CONFIG=true
        log_message "Firewall needs config: NTP rule missing"
    fi
fi

if [[ "$UFW_NEEDS_CONFIG" == "true" ]] || [[ "$FORCE" == "true" ]]; then
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
        sudo tee "$FAIL2BAN_CONF" > /dev/null << EOF
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
log_message "=== SECTION 10: Finalization ==="
echo -e "${BLUE}[10/10] Finalizing...${NC}"

# Verify critical settings
echo -e "${YELLOW}  → Verifying critical settings${NC}"

# Verify swap is actually off
if [[ "$DRY_RUN" == "false" ]]; then
    SWAP_CHECK=$(sudo swapon --show)
    if [[ -n "$SWAP_CHECK" ]]; then
        echo -e "${RED}  ✗ WARNING: Swap is still active!${NC}"
        echo -e "${YELLOW}    Active swap: $SWAP_CHECK${NC}"
        echo -e "${YELLOW}    You may need to reboot for changes to take effect${NC}"
    else
        echo -e "${GREEN}  ✓ Swap verified disabled${NC}"
    fi
    
    # Verify swappiness
    SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    if [[ "$SWAPPINESS" != "0" ]]; then
        echo -e "${YELLOW}  ⚠ Swappiness is $SWAPPINESS (should be 0, will apply on reboot)${NC}"
    else
        echo -e "${GREEN}  ✓ Swappiness verified: 0${NC}"
    fi
fi

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

log_message "=== SETUP COMPLETED ==="
log_message "Changes made: $CHANGES_MADE"
log_message "Completed at: $(date)"

echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                   Configuration Complete!                         ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Show log file location
echo -e "${CYAN}Setup log saved to: $SETUP_LOG${NC}"
echo -e "${CYAN}Latest log link: $SETUP_LOG_LINK${NC}"
echo ""

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
    log_message "Changes were made - reboot required"
    log_message "Waiting for user confirmation or timeout (10 seconds)"
    
    # Use read with timeout to prevent hanging
    echo "Rebooting in 10 seconds... (Press Ctrl+C to cancel)"
    
    # Try read with timeout (bash 4+)
    if read -t 10 -p "Press Enter to reboot immediately, or wait..."; then
        echo ""
        echo "Rebooting now..."
        log_message "User pressed Enter - rebooting immediately"
    else
        echo ""
        echo "Timeout - rebooting automatically..."
        log_message "Timeout reached - rebooting automatically"
    fi
    
    sleep 2
    log_message "Executing: sudo reboot"
    sudo reboot
else
    log_message "No changes needed - system already configured"
    echo "No changes were needed - system already configured correctly."
    echo ""
    echo "Current configuration:"
    echo "  Network: ${NETWORK_IP}/${NETWORK_SUBNET}"
    echo "  Displays: ${NUM_DISPLAYS}"
    echo "  Air Manager: ${FIREWALL_AIRMANAGER_IP}"
    echo ""
    echo "System is ready. No reboot required."
fi
