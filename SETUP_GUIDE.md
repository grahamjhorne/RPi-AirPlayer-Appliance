# Air Player Appliance - Setup Instructions

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

```bash
# Connect via SSH
ssh airman@192.168.x.x

# Extract files
unzip airplayer-install.zip

# Make script executable
chmod +x install.sh

# Run installation
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
- Reboot

**Total time: ~10-15 minutes**

### Step 6: After Reboot

1. Wait 2-3 minutes for boot
2. Reconnect via SSH at static IP:
   ```bash
   ssh airman@192.168.5.198
   ```
3. Air Player should be running on your displays
4. Connect from Air Manager at 192.168.5.199

**Done!** Your Air Player appliance is ready.

## Verifying Installation

```bash
# Check displays
export DISPLAY=:0
xrandr

# Check Air Player processes
ps aux | grep AirPlayer

# Check network
ip addr show eth0

# Check firewall
sudo ufw status
```

## Configuration Changes

To change settings:

1. On your computer, edit `install.properties`
2. Reimage microSD card (takes 5 minutes)
3. Repeat Steps 2-5

This ensures clean, reproducible builds.

## Troubleshooting

### Can't SSH after first boot
- Check Ethernet cable
- Verify Pi IP address on screen or router
- Check SSH key (see Appendix A)

### Displays not working
- Verify connections (HDMI cables)
- Check `install.properties` display settings
- After reboot: `ssh airman@192.168.5.198` and run `export DISPLAY=:0 && xrandr`

### Air Player not starting
- Check if installed: `ls /opt/AirPlayer`
- Check autostart: `cat ~/.config/openbox/autostart`
- Check processes: `ps aux | grep AirPlayer`

### Power issues
- Use 5V 5A power supply
- Check: `vcgencmd get_throttled` (should be 0x0)

## Adding DSI Screen (Future)

When your DSI screen arrives:

1. Connect DSI cable to Pi
2. Edit `install.properties`:
   ```
   NUM_DISPLAYS=3
   TERTIARY_DISPLAY_ENABLED=yes
   ```
3. Reimage and reinstall

---

## Appendices

### Appendix A: Creating SSH Keys

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

### Appendix B: Finding Raspberry Pi IP Address

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

### Appendix C: Power Supply Setup

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

### Appendix D: Example Panel Configuration

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

**Physical Construction:**
- Base: 6mm birch plywood
- Face: 1mm aluminum veneer
- Control wiring: Embedded in ply
- Back: Melamine veneer (anti-warp)
- Protection: Felt backing on screens
- Cutouts: Round holes for instrument visibility

### Appendix E: Network Configuration

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

### Appendix F: File Checklist

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

---

**That's it!** Simple, clean, repeatable. No keyboard needed after initial boot. Just SSH and go.
