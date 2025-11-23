╔═══════════════════════════════════════════════════════════════════════╗
║   AIR PLAYER APPLIANCE SETUP & CONFIGURATION FOR RASPBERRY PI 5                    ║
╚═══════════════════════════════════════════════════════════════════════╝

WHAT IS THIS?
═════════════

A configuration management system that builds and maintains hardened Air Player
appliances on Raspberry Pi 5 for flight simulator instrument displays.

**NEW in Version 1.1:** Idempotent configuration management
- Safe to run multiple times
- Update configuration without reimaging
- Upgrade AirPlayer without starting over
- Dry-run mode to preview changes
- Automatic state tracking and backups

PHILOSOPHY
══════════

- Minimal OS (RPi OS Lite, no desktop)
- Hardened security (SSH keys only, firewall, minimal services)
- Single setup script
- SSH-only operation (no keyboard needed)
- **NEW: Maintain configuration over time without reimaging**
- Repeatable and reliable
- Optimized for SD card longevity



TWO WORKFLOWS
═════════════

**Workflow 1: Initial Setup (Fresh Install)**
  - Image microSD card
  - Boot and note IP
  - Copy files via SCP
  - Run ./setup.sh
  - Reboot
  Time: ~17 minutes

**Workflow 2: Configuration Updates (Version 1.1 NEW!)**
  - Edit install.properties on running system
  - Run ./setup.sh --dry-run (preview changes)
  - Run ./setup.sh (apply changes)
  - Reboot if needed (only for network/display changes)
  Time: ~1-3 minutes for most changes

SECURITY FEATURES
═════════════════

✓ SSH hardened (public key only, no passwords)
✓ Firewall configured (UFW, default deny)
✓ IPv6 completely disabled (kernel, sysctl, firewall)
✓ Minimal attack surface (no unnecessary services)
✓ WiFi and Bluetooth disabled at hardware level
✓ Volatile logging (RAM only, reduces writes)
✓ Air Manager access restricted to specific IP
✓ No swap (prevents sensitive data from being written to disk)

PERFORMANCE OPTIMIZATIONS
═════════════════════════

✓ noatime on all filesystems (reduces write operations)
✓ Swap disabled (no thrashing, predictable performance)
✓ Swappiness set to 0 (kernel won't try to swap)
✓ Volatile logging (no log writes to SD card)
✓ Minimal services (more resources for AirPlayer)
✓ GPU memory optimized for displays

SD CARD LONGEVITY
═════════════════

This build is optimized to extend SD card life:

✓ noatime mount option (10-30% fewer writes)
✓ No swap file (eliminates swap writes)
✓ Volatile journaling (logs in RAM only)
✓ Minimal system writes

Expected SD card lifespan: 5-10+ years under normal use

PERFECT FOR
════════════

- Flight simulator instrument panels
- Multi-display Air Player setups
- Security-conscious environments
- Dedicated appliance builds
- Reproducible deployments
- Long-term reliable installations

FILES
═════

Essential (3 files):
  ✓ setup.sh              - Setup and configuration script
  ✓ install.properties      - Your configuration
  ✓ Air Player 5.0 Linux ARM-64.zip (you provide)

Documentation:
  ✓ README.txt              - This file
  ✓ SETUP_GUIDE.md          - Complete step-by-step instructions
  ✓ QUICK_REFERENCE.txt     - Quick reference card
  ✓ LICENSE                 - License information

QUICK START
═══════════

1. IMAGE MICROSD
   - Use Raspberry Pi Imager
   - OS: Raspberry Pi OS Lite (64-bit)
   - Edit settings: hostname, user (airman), SSH public key
   - DO NOT configure wireless LAN

2. BOOT & GET IP
   - Connect Ethernet and power
   - Note IP address from screen (or check router)

3. COPY FILES
   zip airplayer-setup.zip setup.sh install.properties "Air Player 5.0 Linux ARM-64.zip"
   scp airplayer-setup.zip airman@<DHCP-IP>:.

4. RUN INSTALLER (Use screen or tmux for safety)
   ssh airman@<DHCP-IP>
   screen -S setup          # Creates persistent session
   unzip airplayer-setup.zip
   chmod +x setup.sh
   ./setup.sh

   # If SSH disconnects, reconnect with:
   # ssh airman@<DHCP-IP>
   # screen -r setup

5. REBOOT WHEN PROMPTED
   Press Enter when installation completes

6. DONE
   After reboot: ssh airman@192.168.5.198 (or your configured IP)

INSTALLATION METHODS
════════════════════

METHOD 1: Screen Session (RECOMMENDED for remote)
   ssh airman@<IP>
   screen -S setup
   unzip airplayer-setup.zip && chmod +x setup.sh && ./setup.sh
   # If disconnected: ssh back in and run: screen -r setup

METHOD 2: Tmux Session (Alternative)
   ssh airman@<IP>
   tmux new -s setup
   unzip airplayer-setup.zip && chmod +x setup.sh && ./setup.sh
   # If disconnected: ssh back in and run: tmux attach -t setup

METHOD 3: Direct Console (Most reliable)
   # Use keyboard and monitor directly
   # Login at console
   unzip airplayer-setup.zip && chmod +x setup.sh && ./setup.sh

METHOD 4: Nohup with Logging (For automation)
   ssh airman@<IP> 'cd ~ && unzip airplayer-setup.zip && chmod +x setup.sh && nohup ./setup.sh > setup.log 2>&1 &'
   # Monitor: ssh airman@<IP> 'tail -f setup.log'

WHY USE SCREEN/TMUX?
   - Installation completes even if SSH disconnects
   - You can reconnect and see progress
   - More reliable for remote installations

CONFIGURATION
═════════════

Edit install.properties before deployment:

Network:
  NETWORK_IP=192.168.5.198           # Your static IP
  NETWORK_GATEWAY=192.168.4.1        # Your router
  NETWORK_DNS=192.168.4.1            # DNS server
  FIREWALL_AIRMANAGER_IP=192.168.5.199  # Air Manager host

Displays:
  NUM_DISPLAYS=2                     # 1, 2, or 3
  PRIMARY_RESOLUTION=1920x1080
  SECONDARY_RESOLUTION=800x600
  SECONDARY_ROTATION=left            # Portrait mode

Security:
  SSH_PORT=22
  SSH_ALLOWED_USER=airman
  FIREWALL_ALLOWED_NETWORK=192.168.4.0/22

GPU:
  GPU_MEMORY=384                     # 512 for 3 displays

DISPLAY SUPPORT
═══════════════

Supports 1-3 displays:
  - HDMI-1 (primary) - Always landscape
  - HDMI-2 (secondary) - Can be portrait or landscape
  - DSI-1 (tertiary) - Optional, for small screens

Flexible configuration:
  - Any resolution supported by your displays
  - Rotation (normal, left, right, inverted)
  - Positioning (left-of, right-of, above, below)

Example: Portrait secondary display:
  SECONDARY_ROTATION=left (or right)

MAKING CHANGES
══════════════

To change any configuration:

1. Edit install.properties on your computer
2. Reimage microSD card (5 minutes)
3. Boot Pi and run setup script (10 minutes)
4. Done!

Clean build every time = no issues, no cruft, no surprises.

Why not edit in place?
  - Risk of configuration conflicts
  - Harder to troubleshoot
  - Clean builds are faster than debugging
  - Perfect reproducibility

TIME REQUIRED
═════════════

Imaging microSD:      ~5 minutes
First boot:           ~1 minute
Copy files:           ~30 seconds
Install (script):     ~10 minutes
Reboot:               ~1 minute
──────────────────────────────────
Total:                ~17 minutes

After reboot: Fully functional, hardened Air Player appliance

HOW IT WORKS
════════════

The setup script does 10 main steps:

1. Configure static network (applies on reboot)
2. Harden SSH (key-only authentication)
3. Update system and install minimal packages
4. Configure auto-login
5. Configure X11 for displays
6. Configure boot options (GPU, disable WiFi/BT)
7. Install Air Player
8. Configure display layout and launch
9. System hardening (firewall, logging, swap, fstab)
10. Finalize and prepare for reboot

Network changes apply cleanly on reboot (no SSH disruption)
AirPlayer launches via Openbox autostart (single instance)

SECURITY NOTES
══════════════

This is a hardened build suitable for security-conscious environments:

✓ All access via SSH with public key authentication only
✓ Firewall restricts access to local network and specific IPs
✓ Minimal services = minimal attack surface
✓ No unnecessary packages or daemons
✓ IPv6 fully disabled (kernel, sysctl, firewall)
✓ Volatile logging (no persistent logs that could leak info)
✓ No WiFi or Bluetooth (disabled at hardware level)
✓ No swap (prevents sensitive data from being written to disk)

NOT just a "convenience" build - this is a properly secured appliance
built by a cybersecurity professional.

POWER REQUIREMENTS
══════════════════

Raspberry Pi 5 needs stable 5V @ 5A (25W) minimum

Recommended PSUs:
  ✓ Mean Well LRS-150F-5 (5V 30A, industrial grade)
  ✓ Official Raspberry Pi 27W USB-C PSU

NOT recommended:
  ✗ MacBook USB-C chargers (unreliable under load)
  ✗ Generic USB phone chargers
  ✗ Underpowered adapters

Test your power:
  vcgencmd pmic_read_adc EXT5V_V  # Should be ~5.0V
  vcgencmd get_throttled           # Should be 0x0

Under-voltage = crashes, throttling, corruption, instability

See SETUP_GUIDE.md Appendix C for detailed PSU setup.

TROUBLESHOOTING
═══════════════

Can't SSH after first boot:
  ✓ Check Ethernet cable is connected
  ✓ Verify Pi IP address (shown on screen or check router)
  ✓ Test SSH key: ssh -v airman@<IP>
  ✓ Ensure you used the correct public key in RPi Imager

Can't SSH at static IP after installation:
  ✓ Wait 2-3 minutes for full boot
  ✓ Use the IP from install.properties (default: 192.168.5.198)
  ✓ Check gateway and network settings
  ✓ Verify you're on the correct network

Displays not working:
  ✓ Check HDMI cables are firmly connected
  ✓ SSH in and run: export DISPLAY=:0 && xrandr (shows detected displays)
  ✓ Check install.properties display configuration
  ✓ Verify display IDs match (HDMI-1, HDMI-2, etc.)

Air Player not running:
  ✓ Check if installed: ls /opt/AirPlayer
  ✓ Check openbox config: cat ~/.config/openbox/autostart
  ✓ Check processes: ps aux | grep AirPlayer
  ✓ Should see single ./AirPlayer process (auto-detects all displays)
  ✓ Should NOT see /opt/AirPlayer/Bootloader

Installation stopped mid-way:
  ✓ Did you use screen or tmux? Reconnect with: screen -r setup
  ✓ Check setup.log if using nohup: tail -f setup.log
  ✓ If necessary, reimage SD card and start fresh

Under-voltage warning:
  ✓ Use proper 5V 5A power supply
  ✓ See SETUP_GUIDE.md Appendix C
  ✓ Check voltage: vcgencmd pmic_read_adc EXT5V_V

Wrong display orientation:
  ✓ Edit install.properties:
    SECONDARY_ROTATION=left (or right, inverted, normal)
  ✓ Reimage and reinstall

VERIFICATION
════════════

After installation, verify everything works:

ssh airman@192.168.5.198

# Check displays are active
export DISPLAY=:0
xrandr --listmonitors
# Should show all configured displays

# Check Air Player is running
ps aux | grep AirPlayer
# Should show single ./AirPlayer process

# Check network is static
ip addr show eth0
# Should show your configured static IP

# Check firewall is active
sudo ufw status
# Should show: Status: active

# Check swap is disabled
sudo swapon --show
# Should show nothing (no swap)

# Check swappiness
cat /proc/sys/vm/swappiness
# Should show: 0

# Check fstab has noatime
cat /etc/fstab | grep -v "^#"
# Should show noatime on all mounts

# Check power is good
vcgencmd get_throttled
# Should show: throttled=0x0

vcgencmd pmic_read_adc EXT5V_V
# Should show: ~5.0V

# Check system is stable
uptime
journalctl -xe  # Check for errors

TIPS
════

✓ Always use screen or tmux for remote installations
✓ Keep install.properties backed up with version control
✓ Test with 1 display first before adding more
✓ Use proper power supply from the start
✓ Document your working configuration
✓ Keep a backup microSD with working setup
✓ Rebuilds are fast (15 min) - don't hesitate to start fresh
✓ No keyboard needed after initial setup
✓ Everything is done via SSH
✓ Take notes of what works for your specific displays

DISPLAY CONFIGURATION EXAMPLES
══════════════════════════════

Single display (G5 PFD):
  NUM_DISPLAYS=1
  PRIMARY_DISPLAY=HDMI-1
  PRIMARY_RESOLUTION=1920x1080
  PRIMARY_ROTATION=normal
  PRIMARY_DISPLAY_ENABLED=yes
  SECONDARY_DISPLAY_ENABLED=no

Two displays (PFD + Engine):
  NUM_DISPLAYS=2
  PRIMARY: HDMI-1, 1920x1080, normal (landscape)
  SECONDARY: HDMI-2, 800x600, left (portrait)

Three displays (PFD + Engine + Tach):
  NUM_DISPLAYS=3
  PRIMARY: HDMI-1, 1920x1080, normal
  SECONDARY: HDMI-2, 800x600, left
  TERTIARY: DSI-1, 800x800, normal
  GPU_MEMORY=512  # Need more GPU RAM for 3 displays

SUPPORT & DOCUMENTATION
═══════════════════════

For detailed step-by-step:   See SETUP_GUIDE.md
For quick reference:          See QUICK_REFERENCE.txt
For this overview:            You're reading it!

All documentation is included in the distribution.

BUILDING FROM SCRATCH
════════════════════

Total time from blank SD card to working system: ~17 minutes

Materials needed:
  ✓ Raspberry Pi 5 (4GB or 8GB)
  ✓ MicroSD card (16GB minimum, 32GB recommended)
  ✓ 5V 5A power supply (proper one!)
  ✓ Ethernet cable and network access
  ✓ Displays (HDMI or DSI)
  ✓ Computer with Raspberry Pi Imager
  ✓ SSH key pair (see SETUP_GUIDE.md Appendix A)
  ✓ Air Player Linux ARM-64 zip file

Optional:
  ✓ Monitor for first boot (to see IP address)
  ✓ USB keyboard (for console access if needed)

MAINTENANCE
═══════════

This is an appliance - no maintenance required.

If updates needed:
  - Edit install.properties
  - Reimage SD card
  - Reinstall (15 minutes)

No in-place updates needed.
Clean builds prevent configuration drift.

BACKUP STRATEGY
═══════════════

Recommended:
  ✓ Keep install.properties in version control
  ✓ Keep a working SD card image
  ✓ Keep a spare SD card with working config

Recovery time if SD card fails: 17 minutes to rebuild

LICENSE
═══════

See LICENSE file for details.

Built by cybersecurity professionals for secure, reliable deployments.

═══════════════════════════════════════════════════════════════════════

Start with SETUP_GUIDE.md for complete step-by-step instructions!

Questions? Check QUICK_REFERENCE.txt for common commands and tips.

═══════════════════════════════════════════════════════════════════════
