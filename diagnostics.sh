#!/bin/bash
# ============================================================================
# Air Player Appliance - System Diagnostics Report
# ============================================================================
# Collects all system information for verification
# Usage: ./diagnostics.sh
# Output: diagnostics-report-YYYYMMDD-HHMMSS.txt
# ============================================================================

REPORT_FILE="diagnostics-report-$(date +%Y%m%d-%H%M%S).txt"

# ============================================================================
# Helper function to add section headers
# ============================================================================
section() {
    echo "" >> "$REPORT_FILE"
    echo "============================================================================" >> "$REPORT_FILE"
    echo "$1" >> "$REPORT_FILE"
    echo "============================================================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

subsection() {
    echo "" >> "$REPORT_FILE"
    echo "--- $1 ---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# ============================================================================
# Start Report
# ============================================================================
echo "Air Player Appliance - System Diagnostics Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Hostname: $(hostname)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# ============================================================================
# 1. SWAP CONFIGURATION
# ============================================================================
section "1. SWAP CONFIGURATION"

subsection "Swap Status (should be empty/disabled)"
sudo swapon --show >> "$REPORT_FILE" 2>&1
if [[ -z "$(sudo swapon --show)" ]]; then
    echo "✓ Swap is disabled (no active swap)" >> "$REPORT_FILE"
else
    echo "✗ WARNING: Swap is active!" >> "$REPORT_FILE"
fi

subsection "Memory Information"
free -h >> "$REPORT_FILE"

subsection "Swappiness Setting (should be 0)"
SWAPPINESS=$(cat /proc/sys/vm/swappiness)
echo "vm.swappiness = $SWAPPINESS" >> "$REPORT_FILE"
if [[ "$SWAPPINESS" == "0" ]]; then
    echo "✓ Swappiness correctly set to 0" >> "$REPORT_FILE"
else
    echo "✗ WARNING: Swappiness is $SWAPPINESS (should be 0)" >> "$REPORT_FILE"
fi

subsection "Swappiness Configuration File"
if [[ -f /etc/sysctl.d/99-swappiness.conf ]]; then
    cat /etc/sysctl.d/99-swappiness.conf >> "$REPORT_FILE"
else
    echo "✗ File not found: /etc/sysctl.d/99-swappiness.conf" >> "$REPORT_FILE"
fi

subsection "dphys-swapfile Service Status"
if systemctl list-unit-files 2>/dev/null | grep -q dphys-swapfile; then
    systemctl status dphys-swapfile.service --no-pager >> "$REPORT_FILE" 2>&1
    systemctl is-enabled dphys-swapfile.service >> "$REPORT_FILE" 2>&1
else
    echo "✓ dphys-swapfile service not present" >> "$REPORT_FILE"
fi

subsection "Swap Files on Disk"
if [[ -f /var/swap ]] || [[ -f /swap ]] || [[ -f /swapfile ]]; then
    ls -lh /var/swap /swap /swapfile 2>/dev/null >> "$REPORT_FILE"
    echo "✗ WARNING: Swap files found on disk!" >> "$REPORT_FILE"
else
    echo "✓ No swap files found" >> "$REPORT_FILE"
fi

subsection "fstab Swap Entries"
grep -i swap /etc/fstab >> "$REPORT_FILE" 2>&1
if grep -q "^[^#].*swap" /etc/fstab 2>/dev/null; then
    echo "✗ WARNING: Uncommented swap entries in fstab!" >> "$REPORT_FILE"
else
    echo "✓ No active swap entries in fstab" >> "$REPORT_FILE"
fi

# ============================================================================
# 2. GPU MEMORY CONFIGURATION
# ============================================================================
section "2. GPU MEMORY CONFIGURATION"

subsection "Current GPU Memory Allocation"
GPU_MEM=$(vcgencmd get_mem gpu)
echo "$GPU_MEM" >> "$REPORT_FILE"
GPU_VALUE=$(echo "$GPU_MEM" | cut -d= -f2 | tr -d 'M')
if [[ "$GPU_VALUE" == "384" ]]; then
    echo "✓ GPU memory correctly set to 384M" >> "$REPORT_FILE"
elif [[ "$GPU_VALUE" -ge "256" ]]; then
    echo "⚠ GPU memory is ${GPU_VALUE}M (recommended: 384M)" >> "$REPORT_FILE"
else
    echo "✗ WARNING: GPU memory is ${GPU_VALUE}M (should be 384M)" >> "$REPORT_FILE"
fi

subsection "Boot Config GPU Setting"
if [[ -f /boot/firmware/config.txt ]]; then
    grep "^gpu_mem" /boot/firmware/config.txt >> "$REPORT_FILE" 2>&1
    if grep -q "^gpu_mem=384" /boot/firmware/config.txt; then
        echo "✓ config.txt has gpu_mem=384" >> "$REPORT_FILE"
    else
        echo "✗ WARNING: config.txt does not have gpu_mem=384" >> "$REPORT_FILE"
    fi
else
    echo "✗ File not found: /boot/firmware/config.txt" >> "$REPORT_FILE"
fi

# ============================================================================
# 3. SYSTEM PERFORMANCE
# ============================================================================
section "3. SYSTEM PERFORMANCE"

subsection "CPU Temperature"
TEMP=$(vcgencmd measure_temp)
echo "$TEMP" >> "$REPORT_FILE"
TEMP_VALUE=$(echo "$TEMP" | grep -oP '\d+\.\d+' | head -1)
if (( $(echo "$TEMP_VALUE < 70" | bc -l) )); then
    echo "✓ Temperature is good (< 70°C)" >> "$REPORT_FILE"
elif (( $(echo "$TEMP_VALUE < 80" | bc -l) )); then
    echo "⚠ Temperature is elevated (70-80°C)" >> "$REPORT_FILE"
else
    echo "✗ WARNING: Temperature is high (> 80°C)" >> "$REPORT_FILE"
fi

subsection "Throttling Status"
THROTTLED=$(vcgencmd get_throttled)
echo "$THROTTLED" >> "$REPORT_FILE"
if [[ "$THROTTLED" == "throttled=0x0" ]]; then
    echo "✓ No throttling detected" >> "$REPORT_FILE"
else
    echo "✗ WARNING: Throttling detected!" >> "$REPORT_FILE"
fi

subsection "CPU Information"
lscpu | grep -E "Model name|Architecture|CPU\(s\)|MHz" >> "$REPORT_FILE"

subsection "Memory Usage"
free -h >> "$REPORT_FILE"

subsection "Load Average"
uptime >> "$REPORT_FILE"

# ============================================================================
# 4. NETWORK CONFIGURATION
# ============================================================================
section "4. NETWORK CONFIGURATION"

subsection "Network Interfaces"
ip addr show >> "$REPORT_FILE"

subsection "Netplan Configuration"
if [[ -f /etc/netplan/50-cloud-init.yaml ]]; then
    cat /etc/netplan/50-cloud-init.yaml >> "$REPORT_FILE"
else
    echo "File not found: /etc/netplan/50-cloud-init.yaml" >> "$REPORT_FILE"
fi

subsection "Default Route"
ip route show default >> "$REPORT_FILE"

subsection "DNS Configuration"
cat /etc/resolv.conf >> "$REPORT_FILE"

subsection "Hostname"
hostname >> "$REPORT_FILE"
cat /etc/hostname >> "$REPORT_FILE"

subsection "/etc/hosts"
cat /etc/hosts >> "$REPORT_FILE"

# ============================================================================
# 5. FIREWALL CONFIGURATION
# ============================================================================
section "5. FIREWALL CONFIGURATION"

subsection "UFW Status"
sudo ufw status verbose >> "$REPORT_FILE"

subsection "UFW Rules (Numbered)"
sudo ufw status numbered >> "$REPORT_FILE"

subsection "UFW Configuration"
if [[ -f /etc/ufw/ufw.conf ]]; then
    grep -v "^#" /etc/ufw/ufw.conf | grep -v "^$" >> "$REPORT_FILE"
fi

subsection "Active iptables Rules"
sudo iptables -L -n -v >> "$REPORT_FILE"

# ============================================================================
# 6. SSH CONFIGURATION
# ============================================================================
section "6. SSH CONFIGURATION"

subsection "SSH Service Status"
systemctl status ssh --no-pager >> "$REPORT_FILE"

subsection "SSH Daemon Configuration"
grep -v "^#" /etc/ssh/sshd_config | grep -v "^$" >> "$REPORT_FILE"

subsection "SSH Listening Ports"
sudo ss -tlnp | grep ssh >> "$REPORT_FILE"

subsection "Authorized Keys"
if [[ -f ~/.ssh/authorized_keys ]]; then
    echo "Authorized keys exist:" >> "$REPORT_FILE"
    wc -l ~/.ssh/authorized_keys >> "$REPORT_FILE"
    echo "First key:" >> "$REPORT_FILE"
    head -1 ~/.ssh/authorized_keys | cut -c1-80 >> "$REPORT_FILE"
else
    echo "✗ No authorized_keys file found" >> "$REPORT_FILE"
fi

# ============================================================================
# 7. FAIL2BAN CONFIGURATION
# ============================================================================
section "7. FAIL2BAN CONFIGURATION"

subsection "fail2ban Service Status"
systemctl status fail2ban --no-pager >> "$REPORT_FILE" 2>&1

subsection "fail2ban Configuration"
if [[ -f /etc/fail2ban/jail.local ]]; then
    cat /etc/fail2ban/jail.local >> "$REPORT_FILE"
else
    echo "File not found: /etc/fail2ban/jail.local" >> "$REPORT_FILE"
fi

subsection "fail2ban Current Bans"
sudo fail2ban-client status sshd >> "$REPORT_FILE" 2>&1

# ============================================================================
# 8. DISPLAY CONFIGURATION
# ============================================================================
section "8. DISPLAY CONFIGURATION"

subsection "X Server Status"
systemctl status airplayer-xserver --no-pager >> "$REPORT_FILE" 2>&1

subsection "Display Detection"
DISPLAY=:0 xrandr >> "$REPORT_FILE" 2>&1

subsection "Xorg Log (Last 50 lines)"
if [[ -f /var/log/Xorg.0.log ]]; then
    tail -50 /var/log/Xorg.0.log >> "$REPORT_FILE"
else
    echo "File not found: /var/log/Xorg.0.log" >> "$REPORT_FILE"
fi

# ============================================================================
# 9. AIR PLAYER INSTALLATION
# ============================================================================
section "9. AIR PLAYER INSTALLATION"

subsection "Air Player Service Status"
systemctl status airplayer --no-pager >> "$REPORT_FILE" 2>&1

subsection "Air Player Installation"
if [[ -d /opt/AirPlayer ]]; then
    echo "✓ Air Player directory exists" >> "$REPORT_FILE"
    ls -lh /opt/AirPlayer >> "$REPORT_FILE"
else
    echo "✗ Air Player directory not found" >> "$REPORT_FILE"
fi

subsection "Air Player Process"
ps aux | grep -i airplayer | grep -v grep >> "$REPORT_FILE" 2>&1

# ============================================================================
# 10. SYSTEM INFORMATION
# ============================================================================
section "10. SYSTEM INFORMATION"

subsection "OS Information"
cat /etc/os-release >> "$REPORT_FILE"

subsection "Kernel Version"
uname -a >> "$REPORT_FILE"

subsection "Uptime"
uptime >> "$REPORT_FILE"

subsection "Disk Usage"
df -h >> "$REPORT_FILE"

subsection "Installed Packages (Key)"
dpkg -l | grep -E "openssh|ufw|fail2ban|xorg|openbox" >> "$REPORT_FILE"

subsection "Systemd Services (Failed)"
systemctl --failed >> "$REPORT_FILE"

subsection "Recent Boot Messages (Last 50 lines)"
sudo journalctl -b | tail -50 >> "$REPORT_FILE"

# ============================================================================
# 11. SETUP STATE
# ============================================================================
section "11. SETUP STATE"

subsection "Air Player Appliance State File"
if [[ -f /var/lib/airplayer-appliance/state ]]; then
    cat /var/lib/airplayer-appliance/state >> "$REPORT_FILE"
else
    echo "File not found: /var/lib/airplayer-appliance/state" >> "$REPORT_FILE"
fi

subsection "Setup Log (Last 100 lines)"
if [[ -f /tmp/airplayer-setup-latest.log ]]; then
    tail -100 /tmp/airplayer-setup-latest.log >> "$REPORT_FILE"
else
    echo "File not found: /tmp/airplayer-setup-latest.log" >> "$REPORT_FILE"
fi

# ============================================================================
# 12. SUMMARY
# ============================================================================
section "12. DIAGNOSTIC SUMMARY"

echo "Critical Checks:" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Swap check
if [[ -z "$(sudo swapon --show)" ]] && [[ "$(cat /proc/sys/vm/swappiness)" == "0" ]]; then
    echo "✓ SWAP: Disabled and swappiness=0" >> "$REPORT_FILE"
else
    echo "✗ SWAP: Issues detected - see section 1" >> "$REPORT_FILE"
fi

# GPU check
GPU_VALUE=$(vcgencmd get_mem gpu | cut -d= -f2 | tr -d 'M')
if [[ "$GPU_VALUE" == "384" ]]; then
    echo "✓ GPU: Memory set to 384M" >> "$REPORT_FILE"
else
    echo "✗ GPU: Memory is ${GPU_VALUE}M (should be 384M)" >> "$REPORT_FILE"
fi

# Temperature check
TEMP_VALUE=$(vcgencmd measure_temp | grep -oP '\d+\.\d+' | head -1)
if (( $(echo "$TEMP_VALUE < 70" | bc -l) )); then
    echo "✓ TEMP: ${TEMP_VALUE}°C (good)" >> "$REPORT_FILE"
else
    echo "⚠ TEMP: ${TEMP_VALUE}°C (check cooling)" >> "$REPORT_FILE"
fi

# Throttling check
if [[ "$(vcgencmd get_throttled)" == "throttled=0x0" ]]; then
    echo "✓ THROTTLE: No throttling detected" >> "$REPORT_FILE"
else
    echo "✗ THROTTLE: Throttling detected!" >> "$REPORT_FILE"
fi

# SSH check
if systemctl is-active --quiet ssh; then
    echo "✓ SSH: Service running" >> "$REPORT_FILE"
else
    echo "✗ SSH: Service not running" >> "$REPORT_FILE"
fi

# Firewall check
if sudo ufw status | grep -q "Status: active"; then
    echo "✓ FIREWALL: Active and configured" >> "$REPORT_FILE"
else
    echo "✗ FIREWALL: Not active" >> "$REPORT_FILE"
fi

# Air Player check
if systemctl is-active --quiet airplayer; then
    echo "✓ AIR PLAYER: Service running" >> "$REPORT_FILE"
else
    echo "⚠ AIR PLAYER: Service not running (may be normal if not started yet)" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "============================================================================" >> "$REPORT_FILE"
echo "Report Complete: $REPORT_FILE" >> "$REPORT_FILE"
echo "============================================================================" >> "$REPORT_FILE"

# ============================================================================
# Finish
# ============================================================================
echo ""
echo "Diagnostics complete!"
echo "Report saved to: $REPORT_FILE"
echo ""
echo "To copy to your computer:"
echo "  scp airman@192.168.5.198:~/$REPORT_FILE ."
echo ""
