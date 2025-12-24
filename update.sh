#!/bin/bash
# ============================================================================
# Air Player Appliance - System Update Script
# ============================================================================
# Performs safe system updates with repository validation
# Run this manually when you want to update the appliance
# ============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable

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
# Log File Configuration
# ============================================================================
LOG_FILE="$HOME/update.log"

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Function to log and display
log_and_display() {
    local message="$1"
    echo -e "$message"
    # Strip color codes for log file
    local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    log_message "$clean_message"
}

# ============================================================================
# Banner
# ============================================================================
log_message "========================================="
log_message "Air Player Appliance - System Update"
log_message "========================================="
echo -e "${BLUE}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║     Air Player Appliance - System Update                          ║
║     Safe Manual Updates with Repository Validation                ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# ============================================================================
# Check if running as root
# ============================================================================
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}ERROR: Do not run this script as root${NC}"
   echo "Run as your normal user (e.g., airman)"
   exit 1
fi

# ============================================================================
# 1. Validate Repository Configuration
# ============================================================================
log_and_display "${BLUE}[1/5] Validating repository configuration...${NC}"

# Check for official Raspberry Pi repository
if ! grep -q "raspbian.raspberrypi.com\|archive.raspberrypi.com" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    log_and_display "${YELLOW}  ⚠ Warning: Official Raspberry Pi repository not found${NC}"
fi

# Check for Debian security repository
if ! grep -q "deb.debian.org.*security" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    log_and_display "${YELLOW}  ⚠ Warning: Debian security repository not found${NC}"
fi

# Display configured repositories
echo -e "${CYAN}Configured repositories:${NC}"
echo ""
grep "^deb " /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null | grep -v "^#" | tee -a "$LOG_FILE" || true
echo ""

read -p "Do repositories look correct? (yes/no): " repo_confirm
log_message "Repository confirmation: $repo_confirm"
if [[ "$repo_confirm" != "yes" ]]; then
    log_and_display "${RED}Update cancelled by user${NC}"
    exit 1
fi

log_and_display "${GREEN}  ✓ Repository configuration validated${NC}"

# ============================================================================
# 2. Update Package Lists
# ============================================================================
echo ""
log_and_display "${BLUE}[2/5] Updating package lists...${NC}"

if sudo apt update 2>&1 | tee -a "$LOG_FILE"; then
    log_and_display "${GREEN}  ✓ Package lists updated${NC}"
else
    log_and_display "${RED}  ✗ Failed to update package lists${NC}"
    exit 1
fi

# ============================================================================
# 3. Show Available Updates
# ============================================================================
echo ""
log_and_display "${BLUE}[3/5] Checking for available updates...${NC}"

# Get list of upgradeable packages
UPGRADABLE=$(apt list --upgradeable 2>/dev/null | grep -v "^Listing" | wc -l)

if [[ $UPGRADABLE -eq 0 ]]; then
    log_and_display "${GREEN}  ✓ System is already up to date!${NC}"
    echo ""
    echo "No updates available. Your system is current."
    log_message "No updates available"
    exit 0
fi

log_and_display "${YELLOW}  → $UPGRADABLE package(s) can be upgraded${NC}"
echo ""
echo -e "${CYAN}Available updates:${NC}"
apt list --upgradeable 2>/dev/null | grep -v "^Listing" | tee -a "$LOG_FILE"

# Separate security updates
echo ""
echo -e "${CYAN}Security updates:${NC}"
SECURITY_UPDATES=$(apt list --upgradeable 2>/dev/null | grep -i security)
if [[ -n "$SECURITY_UPDATES" ]]; then
    echo "$SECURITY_UPDATES" | tee -a "$LOG_FILE"
    log_message "Security updates available"
else
    echo "  (none marked as security)"
    log_message "No security updates marked"
fi

echo ""
read -p "Review the updates above. Continue? (yes/no): " update_confirm
log_message "Update confirmation: $update_confirm"
if [[ "$update_confirm" != "yes" ]]; then
    log_and_display "${YELLOW}Update cancelled by user${NC}"
    exit 0
fi

# ============================================================================
# 4. Perform Updates
# ============================================================================
echo ""
log_and_display "${BLUE}[4/5] Installing updates...${NC}"

# Upgrade packages
log_message "Starting apt upgrade"
if sudo apt upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
    log_and_display "${GREEN}  ✓ Packages upgraded${NC}"
else
    log_and_display "${RED}  ✗ Package upgrade failed${NC}"
    exit 1
fi

# Full upgrade (handles dependency changes)
echo ""
echo -e "${CYAN}Checking for additional dependency updates...${NC}"
log_message "Starting apt full-upgrade"
if sudo apt full-upgrade -y 2>&1 | tee -a "$LOG_FILE"; then
    log_and_display "${GREEN}  ✓ Full upgrade completed${NC}"
else
    log_and_display "${YELLOW}  ⚠ Full upgrade had issues (may be safe to ignore)${NC}"
fi

# ============================================================================
# 5. Cleanup
# ============================================================================
echo ""
log_and_display "${BLUE}[5/5] Cleaning up...${NC}"

# Remove unnecessary packages
AUTOREMOVE_COUNT=$(apt autoremove --dry-run 2>/dev/null | grep "^Remv " | wc -l)
if [[ $AUTOREMOVE_COUNT -gt 0 ]]; then
    log_and_display "${CYAN}  → Removing $AUTOREMOVE_COUNT unnecessary package(s)${NC}"
    sudo apt autoremove --purge -y 2>&1 | tee -a "$LOG_FILE"
    log_and_display "${GREEN}  ✓ Unnecessary packages removed${NC}"
else
    log_and_display "${GREEN}  ✓ No unnecessary packages to remove${NC}"
fi

# Clean package cache
log_message "Cleaning package cache"
echo -e "${CYAN}  → Cleaning package cache${NC}"
sudo apt clean
log_and_display "${GREEN}  ✓ Package cache cleaned${NC}"

# ============================================================================
# Summary
# ============================================================================
echo ""
log_message "Update process completed"
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                   Update Complete!                                 ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if reboot required
if [[ -f /var/run/reboot-required ]]; then
    log_and_display "${YELLOW}⚠ REBOOT REQUIRED${NC}"
    echo ""
    echo "Some updates require a reboot to take effect."
    echo ""
    
    # Show what requires reboot
    if [[ -f /var/run/reboot-required.pkgs ]]; then
        echo "Packages requiring reboot:"
        cat /var/run/reboot-required.pkgs | tee -a "$LOG_FILE"
        echo ""
    fi
    
    read -p "Reboot now? (yes/no): " reboot_confirm
    log_message "Reboot confirmation: $reboot_confirm"
    if [[ "$reboot_confirm" == "yes" ]]; then
        log_message "Rebooting system"
        echo "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    else
        log_message "Reboot deferred by user"
        echo ""
        echo "Remember to reboot when convenient:"
        echo "  sudo reboot"
    fi
else
    log_and_display "✓ No reboot required"
    log_and_display "✓ System is up to date"
fi

echo ""
COMPLETION_MSG="Update completed at $(date)"
echo "$COMPLETION_MSG"
log_message "$COMPLETION_MSG"
log_message "Log file: $LOG_FILE"