#!/bin/bash
# ============================================================================
# Air Player Appliance Builder - Raspberry Pi 5
# ============================================================================
# Builds a hardened, minimal Air Player appliance from fresh RPi OS Lite
# Run this once on a fresh Raspberry Pi OS Lite (64-bit) Trixie installation
# ============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable

# ============================================================================
# Configuration - Load from properties file
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROPERTIES_FILE="${SCRIPT_DIR}/install.properties"

# Check if properties file exists
if [[ ! -f "$PROPERTIES_FILE" ]]; then
    echo "ERROR: install.properties not found!"
    echo "Please create install.properties from install.properties.template"
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
NC='\033[0m'

echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║     Air Player Appliance Builder - Raspberry Pi 5                 ║
║     Hardened, Minimal, Secure Flight Simulator Display            ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Starting installation at $(date)"
echo "Configuration loaded from: $PROPERTIES_FILE"
echo ""

# ============================================================================
# 1. NETWORK CONFIGURATION
# ============================================================================
echo -e "${BLUE}[1/10] Configuring Static Network...${NC}"

sudo tee /etc/systemd/network/10-${NETWORK_INTERFACE}.network > /dev/null << EOF
[Match]
Name=${NETWORK_INTERFACE}

[Network]
Address=${NETWORK_IP}/${NETWORK_SUBNET}
Gateway=${NETWORK_GATEWAY}
DNS=${NETWORK_DNS}
IPv6AcceptRA=no
LinkLocalAddressing=no
IPv6SendRA=no
EOF

# Enable systemd-networkd but don't start it yet to avoid SSH disconnection
sudo systemctl enable systemd-networkd.service
sudo systemctl enable systemd-networkd-wait-online.service

echo -e "${GREEN}✓ Network configured: ${NETWORK_IP}/${NETWORK_SUBNET}${NC}"
echo -e "${YELLOW}  Note: Network will switch to static IP on reboot${NC}"

# ============================================================================
# 2. SSH HARDENING
# ============================================================================
echo -e "${BLUE}[2/10] Configuring SSH...${NC}"

sudo tee /etc/ssh/sshd_config > /dev/null << EOF
Include /etc/ssh/sshd_config.d/*.conf
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
AllowAgentForwarding yes
AllowTcpForwarding yes
X11Forwarding no
PrintMotd no
TCPKeepAlive yes
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

echo -e "${GREEN}✓ SSH hardened (key-only authentication)${NC}"

# ============================================================================
# 3. SYSTEM UPDATE & PACKAGE INSTALLATION
# ============================================================================
echo -e "${BLUE}[3/10] Updating system and installing packages...${NC}"

sudo apt -qq update -y
echo -e "${GREEN}✓ System updated${NC}"

sudo apt -qq install -y \
    xserver-xorg-core \
    xserver-xorg \
    xinit \
    x11-xserver-utils \
    libzip5 \
    libgtk-3-0 \
    libfreeimage3 \
    libcurl4 \
    libusb-1.0-0 \
    libcanberra-gtk3-module \
    libegl1 \
    libgles2 \
    openbox \
    xterm \
    unclutter \
    ufw

echo -e "${GREEN}✓ Packages installed${NC}"

sudo apt -qq full-upgrade -y
sudo apt -qq autoremove --purge -y

echo -e "${GREEN}✓ System upgraded and obsolete packages removed${NC}"

# ============================================================================
# 4. AUTO-LOGIN CONFIGURATION
# ============================================================================
echo -e "${BLUE}[4/10] Configuring auto-login...${NC}"

sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf > /dev/null << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${SYSTEM_USER} --noclear %I \$TERM
Type=idle
EOF

# Add auto-startx to .profile if not already present
if ! grep -q "Start X automatically" "${SYSTEM_USER_HOME}/.profile" 2>/dev/null; then
    cat >> "${SYSTEM_USER_HOME}/.profile" << 'EOF'

# Start X automatically on tty1
if [ "$(tty)" = "/dev/tty1" ] && [[ ! $DISPLAY ]]; then
    startx -- -nocursor
fi
EOF
fi

echo -e "${GREEN}✓ Auto-login configured${NC}"

# ============================================================================
# 5. X11 CONFIGURATION
# ============================================================================
echo -e "${BLUE}[5/10] Configuring X11...${NC}"

tee "${SYSTEM_USER_HOME}/.xinitrc" > /dev/null << EOF
#!/bin/sh

# Disable screen blanking
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor after ${CURSOR_IDLE_TIME} second
unclutter -idle ${CURSOR_IDLE_TIME} -root &

# Start openbox
exec openbox-session
EOF

chmod +x "${SYSTEM_USER_HOME}/.xinitrc"

sudo mkdir -p /etc/X11/xorg.conf.d

sudo tee /etc/X11/xorg.conf.d/10-vc4.conf > /dev/null << EOF
Section "Device"
    Identifier "VC4 Graphics"
    Driver "modesetting"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
    Option "Debug" "dmabuf_capable"
    Option "kmsdev" "/dev/dri/card1"
EndSection
EOF

echo -e "${GREEN}✓ X11 configured${NC}"

# ============================================================================
# 6. BOOT CONFIGURATION (GPU, DISABLE WIFI/BT)
# ============================================================================
echo -e "${BLUE}[6/10] Configuring boot options...${NC}"

# Add or update gpu_mem
if grep -q "^gpu_mem=" /boot/firmware/config.txt; then
    sudo sed -i "s/^gpu_mem=.*/gpu_mem=${GPU_MEMORY}/" /boot/firmware/config.txt
else
    echo "gpu_mem=${GPU_MEMORY}" | sudo tee -a /boot/firmware/config.txt > /dev/null
fi

# Disable WiFi and Bluetooth
if ! grep -q "^dtoverlay=disable-wifi" /boot/firmware/config.txt; then
    echo "dtoverlay=disable-wifi" | sudo tee -a /boot/firmware/config.txt > /dev/null
fi
if ! grep -q "^dtoverlay=disable-bt" /boot/firmware/config.txt; then
    echo "dtoverlay=disable-bt" | sudo tee -a /boot/firmware/config.txt > /dev/null
fi

# Disable IPv6 at boot
if ! grep -q "ipv6.disable=1" /boot/firmware/cmdline.txt; then
    sudo sed -i 's/$/ ipv6.disable=1/' /boot/firmware/cmdline.txt
fi

echo -e "${GREEN}✓ Boot options configured (GPU: ${GPU_MEMORY}MB)${NC}"

# ============================================================================
# 7. AIR PLAYER INSTALLATION
# ============================================================================
echo -e "${BLUE}[7/10] Installing Air Player...${NC}"

if [[ ! -f "${SCRIPT_DIR}/${AIRPLAYER_ZIP_NAME}" ]]; then
    echo -e "${RED}ERROR: Air Player zip not found: ${AIRPLAYER_ZIP_NAME}${NC}"
    exit 1
fi

sudo mkdir -p "${AIRPLAYER_INSTALL_DIR}"
sudo chown -R ${SYSTEM_USER}:${SYSTEM_USER} "${AIRPLAYER_INSTALL_DIR}"

unzip -o "${SCRIPT_DIR}/${AIRPLAYER_ZIP_NAME}" -d "${AIRPLAYER_INSTALL_DIR}/"

sudo chmod +x ${AIRPLAYER_INSTALL_DIR}/Bootloader \
    ${AIRPLAYER_INSTALL_DIR}/AirPlayer \
    ${AIRPLAYER_INSTALL_DIR}/*.sh

sudo mkdir -p /etc/udev/rules.d
sudo tee /etc/udev/rules.d/42-knobster.rules > /dev/null << EOF
SUBSYSTEM=="usb_device", ATTRS{idVendor}=="16d0", ATTRS{idProduct}=="0e8a", MODE="0666"
SUBSYSTEM=="hidraw", SUBSYSTEMS=="usb", ENV{VID_PID}="16d0:0e8a", MODE="0666"
EOF

# Fix libzip compatibility
if [[ ! -L /usr/lib/aarch64-linux-gnu/libzip.so.4 ]]; then
    sudo ln -s /usr/lib/aarch64-linux-gnu/libzip.so.5 /usr/lib/aarch64-linux-gnu/libzip.so.4
fi

echo -e "${GREEN}✓ Air Player installed${NC}"

# ============================================================================
# 8. DISPLAY CONFIGURATION
# ============================================================================
echo -e "${BLUE}[8/10] Configuring displays (${NUM_DISPLAYS} display(s))...${NC}"

mkdir -p "${SYSTEM_USER_HOME}/.config/openbox"

# Build display configuration
cat > "${SYSTEM_USER_HOME}/.config/openbox/autostart" << 'AUTOSTART_START'
#!/bin/bash
#
# Air Player Display Configuration
# Generated by Air Player Appliance Builder
#

AUTOSTART_START

# Primary Display
if [[ "${PRIMARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Primary Display - Main Panel
xrandr --output ${PRIMARY_DISPLAY} --mode ${PRIMARY_RESOLUTION} --rotate ${PRIMARY_ROTATION} --primary

EOF
else
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Primary Display - DISABLED
# xrandr --output ${PRIMARY_DISPLAY} --mode ${PRIMARY_RESOLUTION} --rotate ${PRIMARY_ROTATION} --primary

EOF
fi

# Secondary Display
if [[ ${NUM_DISPLAYS} -ge 2 ]] && [[ "${SECONDARY_DISPLAY_ENABLED:-yes}" == "yes" ]]; then
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Secondary Display - Additional Panel
xrandr --output ${SECONDARY_DISPLAY} --mode ${SECONDARY_RESOLUTION} --rotate ${SECONDARY_ROTATION} --${SECONDARY_POSITION} ${PRIMARY_DISPLAY}

EOF
else
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Secondary Display - DISABLED
# xrandr --output ${SECONDARY_DISPLAY} --mode ${SECONDARY_RESOLUTION} --rotate ${SECONDARY_ROTATION} --${SECONDARY_POSITION} ${PRIMARY_DISPLAY}

EOF
fi

# Tertiary Display (DSI)
if [[ ${NUM_DISPLAYS} -ge 3 ]] && [[ "${TERTIARY_DISPLAY_ENABLED:-no}" == "yes" ]]; then
    local ref_display="${SECONDARY_DISPLAY}"
    [[ "${TERTIARY_POSITION_REFERENCE}" == "PRIMARY" ]] && ref_display="${PRIMARY_DISPLAY}"
    
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Tertiary Display - DSI Screen
xrandr --output ${TERTIARY_DISPLAY} --mode ${TERTIARY_RESOLUTION} --rotate ${TERTIARY_ROTATION} --${TERTIARY_POSITION} ${ref_display}

EOF
else
    cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Tertiary Display - DISABLED (Future: DSI Screen)
# xrandr --output ${TERTIARY_DISPLAY} --mode ${TERTIARY_RESOLUTION} --rotate ${TERTIARY_ROTATION} --${TERTIARY_POSITION} ${SECONDARY_DISPLAY}

EOF
fi

# Launch Air Player
cat >> "${SYSTEM_USER_HOME}/.config/openbox/autostart" << EOF
# Wait for displays to stabilize
sleep 2

# Launch Air Player (automatically detects and uses all displays)
cd ${AIRPLAYER_INSTALL_DIR}
./AirPlayer &
EOF

chmod +x "${SYSTEM_USER_HOME}/.config/openbox/autostart"

echo -e "${GREEN}✓ Display configuration created${NC}"

# ============================================================================
# 9. SYSTEM HARDENING & OPTIMIZATION
# ============================================================================
echo -e "${BLUE}[9/10] System hardening and optimization...${NC}"

# Volatile logging
echo -e "${YELLOW}  → Configuring volatile logging...${NC}"
sudo sed -i 's/^#\?Storage=.*/Storage=volatile/' /etc/systemd/journald.conf
sudo sed -i 's/^#\?RuntimeMaxUse=.*/RuntimeMaxUse=32M/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald

sudo rm -rf /var/log/apt /var/log/dpkg 2>/dev/null || true
sudo ln -sf /tmp /var/log/apt 2>/dev/null || true
sudo ln -sf /tmp /var/log/dpkg 2>/dev/null || true

sudo sed -i 's/^#\?LogLevel=.*/LogLevel=warning/' /etc/systemd/system.conf
sudo sed -i 's/^#\?LogLevel=.*/LogLevel=warning/' /etc/systemd/user.conf

# Modify fstab to add noatime
echo -e "${YELLOW}  → Adding noatime to /etc/fstab...${NC}"
sudo cp /etc/fstab /etc/fstab.backup

# Add noatime to all ext4 and vfat mounts that don't already have it
sudo sed -i '/^[^#]/ s/\([ \t]ext4[ \t][ \t]*\)\(defaults\)/\1defaults,noatime/' /etc/fstab
sudo sed -i '/^[^#]/ s/\([ \t]vfat[ \t][ \t]*\)\(defaults\)/\1defaults,noatime/' /etc/fstab

# Remove duplicate noatime if any were added
sudo sed -i 's/noatime,noatime/noatime/g' /etc/fstab

echo -e "${GREEN}    ✓ noatime added to filesystem mounts${NC}"

# Disable swap and set swappiness to 0
echo -e "${YELLOW}  → Disabling swap...${NC}"

# Turn off current swap
sudo swapoff -a 2>/dev/null || true

# Comment out swap entries in fstab
sudo sed -i '/^[^#].*swap/ s/^/#/' /etc/fstab

# Disable dphys-swapfile service if present
if systemctl list-unit-files | grep -q dphys-swapfile; then
    sudo systemctl disable dphys-swapfile.service 2>/dev/null || true
    sudo systemctl stop dphys-swapfile.service 2>/dev/null || true
fi

# Remove swap file if it exists
if [[ -f /var/swap ]]; then
    sudo rm -f /var/swap
fi

# Set swappiness to 0
sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null << EOF
# Minimize swap usage (set to 0 to disable swapping)
vm.swappiness=0
EOF

sudo sysctl -w vm.swappiness=0 2>/dev/null || true

echo -e "${GREEN}    ✓ Swap disabled and swappiness set to 0${NC}"

# Disable IPv6
echo -e "${YELLOW}  → Disabling IPv6...${NC}"
sudo tee /etc/sysctl.d/99-disable-ipv6.conf > /dev/null << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# Configure firewall
echo -e "${YELLOW}  → Configuring firewall...${NC}"
sudo sed -i 's/^IPV6=.*/IPV6=no/' /etc/ufw/ufw.conf

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

# Disable unnecessary services
echo -e "${YELLOW}  → Disabling unnecessary services...${NC}"
for service in avahi-daemon cups triggerhappy ModemManager alsa-restore apt-daily.timer apt-daily-upgrade.timer keyboard-setup bluetooth systemd-timesyncd hciuart wpa_supplicant; do
    sudo systemctl disable --now $service 2>/dev/null || true
done

sudo systemctl mask NetworkManager.service 2>/dev/null || true

echo -e "${GREEN}✓ System hardened and optimized${NC}"

# ============================================================================
# 10. FINAL STEPS
# ============================================================================
echo -e "${BLUE}[10/10] Finalizing installation...${NC}"

# Create installation marker
echo "Installation completed: $(date)" > "${SYSTEM_USER_HOME}/.airplayer-installed"
echo "Configuration: ${NUM_DISPLAYS} display(s)" >> "${SYSTEM_USER_HOME}/.airplayer-installed"
echo "Swap: Disabled" >> "${SYSTEM_USER_HOME}/.airplayer-installed"
echo "Swappiness: 0" >> "${SYSTEM_USER_HOME}/.airplayer-installed"
echo "Filesystem: noatime enabled" >> "${SYSTEM_USER_HOME}/.airplayer-installed"

echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                   Installation Complete!                          ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo "Configuration Summary:"
echo "  Network: ${NETWORK_IP}/${NETWORK_SUBNET}"
echo "  Displays: ${NUM_DISPLAYS}"
echo "  Air Manager: ${FIREWALL_AIRMANAGER_IP}"
echo "  Swap: DISABLED (swappiness=0)"
echo "  Filesystem: noatime enabled for reduced writes"
echo ""
echo "The system will now reboot."
echo "After reboot, Air Player will start automatically on your displays."
echo ""
echo "You can reconnect via SSH at: ssh ${SSH_ALLOWED_USER}@${NETWORK_IP}"
echo ""

read -p "Press Enter to reboot now, or Ctrl+C to cancel..."
sudo reboot
