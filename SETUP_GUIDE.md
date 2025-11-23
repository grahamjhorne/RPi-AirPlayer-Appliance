# Air Player Appliance - Setup Instructions

**Version 1.1** - Idempotent Configuration Management

## What's New in v1.1

This version adds **idempotent configuration management** - you can now update settings without reimaging!

**Key Features:**
- Update configurations in <1 minute (vs 17 minutes for reimaging)
- `--dry-run` flag to preview changes
- `--force` flag to rebuild everything
- Automatic state tracking and backups
- Preserves AirPlayer license across updates
- Fresh install workflow unchanged

## Choose Your Workflow

**Workflow 1: Fresh Installation** (~17 minutes)
- First time setup
- Want guaranteed clean state
- See: "Fresh Installation Workflow" below

**Workflow 2: Configuration Update** (<1 minute)
- Change settings on running system
- Update display config, network, GPU memory, etc.
- Upgrade AirPlayer version
- See: "Configuration Update Workflow" below

---

# Fresh Installation Workflow

Use this for first-time setup or when you want a guaranteed clean state.

## Quick Overview

1. Image microSD card with Raspberry Pi OS Lite (64-bit)
2. Boot Raspberry Pi, note IP address
3. Copy installation files via SCP
4. Run install.sh via SSH
5. Reboot - Done!

## Detailed Steps

### Step 1: Image the microSD Card

1. **Download Raspberry Pi Imager**
   - Get it from: https://www.raspberrypi.com/software/
   - Install on your computer

2. **Configure the Image**
   
   **Device:** Raspberry Pi 5
   
   **Operating System:** Raspberry Pi OS (other) → **Raspberry Pi OS Lite (64-bit)**
   - This is Debian Trixie
   - No desktop environment
   - Minimal footprint
   - X11-ready
   
   **Storage:** Your microSD card
   
   **Click "Next"** then **"Edit Settings"**

3. **OS Customization Settings**

   **General Tab:**
   - Hostname: `instruments`
   - Username: `airman`
   - Password: (your choice)
   - ☐ Configure wireless LAN (leave unchecked)
   - ☑ Set locale settings
     - Time zone: (your timezone)
     - Keyboard layout: (your keyboard)

   **Services Tab:**
   - ☑ Enable SSH
   - ☑ Allow public-key authentication only
   - Paste your SSH public key (see Appendix A)

4. **Write the Image**
   - Click "Yes" to apply settings
   - Wait for imaging to complete
   - Eject the card

### Step 2: First Boot

1. Insert microSD card into Raspberry Pi 5
2. Connect:
   - Ethernet cable
   - Power supply (5V 5A minimum)
   - Monitor (temporarily - to see IP address)
3. Power on
4. Watch boot messages
5. **Note the IP address** displayed on screen
   - OR check your DHCP server/router
6. The Pi will auto-login as `airman`

### Step 3: Prepare Installation Files

On your computer, in a directory:

```
airplayer-install/
├── install.sh
├── install.properties
└── Air Player 5.0 Linux ARM-64.zip
```

**Edit install.properties** if your network is different:
- NETWORK_IP (what you want the static IP to be)
- NETWORK_GATEWAY
- FIREWALL_AIRMANAGER_IP
- Display settings (NUM_DISPLAYS, resolutions, rotation)

### Step 4: Copy Files to Raspberry Pi

From your computer (replace 192.168.x.x with Pi's current DHCP IP):

```bash
# Create a zip with all files
zip airplayer-install.zip install.sh install.properties "Air Player 5.0 Linux ARM-64.zip"

# Copy to Pi
scp airplayer-install.zip airman@192.168.x.x:.

# That's it!
```

### Step 5: Run Installation

#### Recommended: Use Screen or Tmux

```bash
# Connect via SSH
ssh airman@192.168.x.x

# Start screen session (recommended for stability)
screen -S install

# Extract files
unzip airplayer-install.zip

# Make script executable
chmod +x install.sh

# Run installation
./install.sh
```

If SSH disconnects during installation:
```bash
ssh airman@192.168.x.x
screen -r install    # Reconnect to see progress
```

#### Alternative: Direct Console

If you have keyboard and monitor connected:
```bash
# Login at console as airman
unzip airplayer-install.zip
chmod +x install.sh
./install.sh
```

The script will:
- Configure static networking
- Harden SSH
- Install required packages
- Configure X11 and displays
- Install Air Player
- Setup firewall
- Optimize system
- Prompt for reboot

**Total time: ~10 minutes**

### Step 6: After Reboot

1. Wait 2-3 minutes for boot
2. Reconnect via SSH at static IP:
   ```bash
   ssh airman@192.168.5.198
   ```
3. Air Player should be running on your displays
4. Connect from Air Manager at 192.168.5.199

**Done!** Your Air Player appliance is ready.

---

# Configuration Update Workflow

**NEW in v1.1** - Update settings without reimaging!

Use this to change configurations on a running system.

## When to Use This

- Change display layout (resolution, rotation, position)
- Add or remove displays
- Adjust GPU memory
- Update network settings
- Upgrade AirPlayer version
- Modify firewall rules
- Any configuration change in install.properties

## Benefits

- **Fast:** <1 minute (vs 17 minutes for full reimage)
- **Preserves license:** Same hardware UUID = AirPlayer license stays valid
- **Safe:** Backs up before changing, state tracked
- **Preview:** --dry-run shows changes before applying

## Steps

### 1. Edit Configuration

SSH into your Pi and edit the properties file:

```bash
ssh airman@192.168.5.198
nano install.properties
```

Make your changes, save and exit (Ctrl+O, Enter, Ctrl+X).

### 2. Preview Changes (Optional)

See what would change without applying:

```bash
./install.sh --dry-run
```

The output shows:
- ✓ Items already configured correctly (no change needed)
- → Items that would be updated
- What values would change

Example output:
```
[6/10] Checking Boot Configuration...
  → Would update GPU memory: 384MB → 512MB
  
[8/10] Updating Display Configuration...
  → Regenerating Openbox autostart (display config from properties)
    Would write: /home/airman/.config/openbox/autostart
    Displays: 2
```

### 3. Apply Changes

Run the script to apply changes:

```bash
./install.sh
```

The script will:
- Check current state
- Apply only what changed
- Back up files before modifying
- Report what it did
- Tell you if reboot needed

### 4. Reboot If Needed

The script tells you if a reboot is required:

```bash
sudo reboot
```

**When reboot is required:**
- Network changes (new IP, gateway, DNS)
- Boot configuration (GPU memory)
- Display changes (or restart X instead: `sudo systemctl restart lightdm`)

**When reboot is NOT required:**
- AirPlayer upgrade (restart X instead)
- Firewall rule updates
- SSH configuration changes

## Examples

### Example 1: Change Display Rotation

```bash
# Edit configuration
nano install.properties
# Change: SECONDARY_ROTATION=left

# Preview
./install.sh --dry-run

# Apply
./install.sh

# Reboot for display changes
sudo reboot
```

### Example 2: Upgrade AirPlayer

```bash
# Copy new version
cp ~/Downloads/AirPlayer-5.1.zip ~/AirPlayer.zip

# Update (extracts new version)
./install.sh

# Restart X to reload
sudo systemctl restart lightdm
```

### Example 3: Increase GPU Memory

```bash
# Edit configuration
nano install.properties
# Change: GPU_MEMORY=512

# Preview
./install.sh --dry-run

# Apply
./install.sh

# Reboot for boot config
sudo reboot
```

### Example 4: Add Third Display

```bash
# Edit configuration
nano install.properties
# Change: NUM_DISPLAYS=3
# Configure TERTIARY_DISPLAY settings
# Set GPU_MEMORY=512

# Preview
./install.sh --dry-run

# Apply
./install.sh

# Reboot
sudo reboot
```

### Example 5: Audit Current Configuration

```bash
# See current state without changes
./install.sh --dry-run
```

### Example 6: Force Rebuild

If something seems wrong, force a complete reconfiguration:

```bash
./install.sh --force
```

---

# Verifying Installation

After installation (fresh or update), verify everything works:

```bash
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

# Check GPU memory
vcgencmd get_mem gpu
# Should match install.properties

# Check power is good
vcgencmd get_throttled
# Should show: throttled=0x0

vcgencmd pmic_read_adc EXT5V_V
# Should show: ~5.0V

# Check state tracking (v1.1)
cat /var/lib/airplayer-appliance/state
# Shows configuration dates and values

# Check backups exist (v1.1)
ls -la /var/backups/airplayer-appliance/
# Shows timestamped backup files
```

---

# Troubleshooting

## Can't SSH after first boot
- Check Ethernet cable
- Verify Pi IP address on screen or router
- Check SSH key (see Appendix A)

## Displays not working
- Verify connections (HDMI cables)
- Check `install.properties` display settings
- After reboot: `ssh airman@192.168.5.198` and run `export DISPLAY=:0 && xrandr`
- Try: `./install.sh --force`

## Air Player not starting
- Check if installed: `ls /opt/AirPlayer`
- Check autostart: `cat ~/.config/openbox/autostart`
- Check processes: `ps aux | grep AirPlayer`
- Restart X: `sudo systemctl restart lightdm`

## Configuration not applying
- Did you run `./install.sh` after editing?
- Did you reboot if prompted?
- Try: `./install.sh --force`
- Check state: `cat /var/lib/airplayer-appliance/state`

## Script says "already configured"
- This is NORMAL - it means that setting is already correct
- Use `--dry-run` to see current state
- Use `--force` to rebuild everything anyway
- Edit install.properties if you want different settings

## AirPlayer license invalid after update
- Update workflow (v1.1) preserves hardware UUID
- License should stay valid
- If license invalid: You may have done fresh install (new UUID)
- Fresh installs need new license activation

## Power issues
- Use 5V 5A power supply
- Check: `vcgencmd get_throttled` (should be 0x0)
- Check voltage: `vcgencmd pmic_read_adc EXT5V_V` (should be ~5.0V)
- See Appendix C for power supply details

## Rolling Back Changes

If an update caused problems:

```bash
# Check available backups
ls -la /var/backups/airplayer-appliance/

# Restore a specific file
sudo cp /var/backups/airplayer-appliance/config.txt.20241122_143052 /boot/firmware/config.txt

# Or force rebuild from install.properties
./install.sh --force

# Or do fresh install for guaranteed clean state
```

---

# Appendices

## Appendix A: Creating SSH Keys

On your computer (Ubuntu/Mac/Linux):

```bash
# Generate ed25519 key pair
ssh-keygen -t ed25519 -C "your_email@example.com"

# Default location: ~/.ssh/id_ed25519
# Just press Enter for all prompts

# View your public key
cat ~/.ssh/id_ed25519.pub
```

Copy the entire output (starts with `ssh-ed25519 ...`)
Paste this into Raspberry Pi Imager → Services → SSH public key

**On Windows:**
- Use PuTTYgen to generate ed25519 key
- Export OpenSSH public key
- Paste into Raspberry Pi Imager

## Appendix B: Finding Raspberry Pi IP Address

**Method 1: On the Pi screen**
- During boot, watch for IP address display
- OR after login, run: `ip addr show eth0`

**Method 2: From your router**
- Check DHCP leases for hostname `instruments`

**Method 3: Network scan**
```bash
# On your computer
nmap -sn 192.168.x.0/24 | grep instruments
# OR
arp -a | grep instruments
```

## Appendix C: Power Supply Setup

**Current Issue:**
MacBook USB-C adapters don't provide consistent 5V @ 5A

**Solution:**
Mean Well LRS-150F-5 PSU with USB-C pigtail cable

**Connection:**
```
Mean Well LRS-150F-5:
  V+  (Red)    → USB-C VBUS pins (A4, A9, B4, B9)
  V-  (Black)  → USB-C GND pins (A1, A12, B1, B12)
  Ground       → Earth (safety)
```

**Cable Requirements:**
- 16-18 AWG wire
- Proper crimps or solder joints
- May need 5.1kΩ resistors on CC pins to GND
- OR use pre-made USB-C PD trigger board set to 5V

**Testing:**
```bash
# Check voltage
vcgencmd pmic_read_adc EXT5V_V
# Should be ~5.0V

# Check throttling
vcgencmd get_throttled
# Should show 0x0
```

## Appendix D: Example Panel Configuration

**Display Layout:**
```
     [RPM]         [Main Console]
     800x800       1920x1080
     DSI-1         HDMI-1
     (Future)      (Primary)
        ↓             ↓
     [Engine]    ←──┘
     800x600
     HDMI-2
     (Portrait)
```

**Primary Display Instruments:**
- Six-pack: ASI, ALT, VSI, TC, DG, TC
- VOR1 and VOR2

**Secondary Display Instruments:**
- Engine gauges: EGT, CHT, Oil, Fuel
- Annunciator panel (warning lights)

**Tertiary Display (Future):**
- Tachometer (RPM) - single round instrument

## Appendix E: Network Configuration

**Default Settings:**
- Pi IP: 192.168.5.198/22
- Gateway: 192.168.4.1
- DNS: 192.168.4.1
- Air Manager: 192.168.5.199

**Allowed Network:** 192.168.4.0/22
- This is 192.168.4.1 through 192.168.7.254
- 1022 usable addresses

**Firewall Rules:**
- SSH (22): Only from local network
- Air Manager ports: Only from 192.168.5.199
- All other incoming: Blocked
- Outgoing: DNS (53) and NTP (123) allowed

## Appendix F: File Checklist

Before starting, ensure you have:

- [ ] install.sh (the installation script)
- [ ] install.properties (your configuration)
- [ ] Air Player 5.0 Linux ARM-64.zip
- [ ] SSH keys generated (Appendix A)
- [ ] Raspberry Pi Imager installed
- [ ] MicroSD card (16GB+ recommended)
- [ ] Raspberry Pi 5
- [ ] Adequate power supply (5V 5A)
- [ ] Ethernet cable
- [ ] Displays (HDMI)

## Appendix G: State and Backup Locations (NEW v1.1)

**State File:**
- Location: `/var/lib/airplayer-appliance/state`
- Contents: Configuration dates and current values
- Purpose: Track what's been configured

Example:
```
network_ip=192.168.5.198
network_configured=20241122
num_displays=2
display_config=20241122
gpu_memory=384
last_run=20241122_143052
```

**Backup Directory:**
- Location: `/var/backups/airplayer-appliance/`
- Contents: Timestamped backups of modified files
- Purpose: Enable rollback if needed

Example:
```
config.txt.20241122_143052
sshd_config.20241122_143053
fstab.20241122_143055
10-eth0.network.20241122_143056
```

To restore a backup:
```bash
sudo cp /var/backups/airplayer-appliance/file.timestamp /path/to/original/file
```

## Appendix H: Command Line Options (NEW v1.1)

**--dry-run**
- Preview what would change without making modifications
- Shows ✓ (already configured) and → (would update)
- Safe to run anytime
- Example: `./install.sh --dry-run`

**--force**
- Force all changes even if already configured
- Useful for troubleshooting or ensuring clean state
- Reconfigures everything from install.properties
- Example: `./install.sh --force`

**No arguments**
- Normal operation: Apply changes as needed
- Checks state, only updates what changed
- Example: `./install.sh`

## Appendix I: Version Comparison

**Version 1.0 → Version 1.1 Changes:**

| Feature | v1.0 | v1.1 |
|---------|------|------|
| Fresh installation | ✓ ~17 min | ✓ ~17 min |
| Configuration updates | ✗ Full reimage only | ✓ <1 min |
| State tracking | ✗ | ✓ /var/lib/airplayer-appliance/ |
| Automatic backups | ✗ | ✓ /var/backups/airplayer-appliance/ |
| Dry-run mode | ✗ | ✓ --dry-run flag |
| Force rebuild | ✗ | ✓ --force flag |
| Idempotent | ✗ | ✓ Safe to rerun |
| AirPlayer upgrades | Reimage required | Just replace zip & rerun |
| License preservation | New UUID each install | Preserves UUID on update |

---

**That's it!** You now have two powerful workflows:
- **Fresh installation** for clean builds (17 minutes)
- **Configuration updates** for quick changes (<1 minute)

Choose the right tool for the job!
