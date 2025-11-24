# Idempotent Install Script - User Guide

## What Changed?

The script is now **idempotent** - safe to run multiple times. It checks the current state before making changes.

## Usage

### First Installation (Fresh RPi)
```bash
chmod +x setup.sh
./setup.sh
```

### Update Display Configuration
```bash
# Edit setup.properties (change display settings)
nano setup.properties

# Dry-run to see what would change
./setup.sh --dry-run

# Apply changes
./setup.sh
```

### Upgrade AirPlayer
```bash
# Replace AirPlayer zip with new version
cp AirPlayer-new.zip AirPlayer.zip

# Run installer (will extract new version)
./setup.sh
```

### Check Configuration Without Changes
```bash
./setup.sh --dry-run
```

### Force All Changes (Rebuild Everything)
```bash
./setup.sh --force
```

## Command Line Options

- `--dry-run` - Show what would change without making changes
- `--force` - Force all changes even if already configured

## What It Does Differently

### Checks Before Acting
```bash
# OLD: Always writes file
sudo tee /etc/file > /dev/null << EOF
content
EOF

# NEW: Checks if update needed first
if file_needs_update "/etc/file" "content"; then
    echo "→ Updating file"
    sudo tee /etc/file > /dev/null << EOF
content
EOF
else
    echo "✓ File already configured"
fi
```

### State Tracking
The script maintains state in `/var/lib/airplayer-appliance/state`:
```
network_ip=192.168.5.198
network_configured=20241122
packages_installed=20241122
last_run=20241122_143052
```

### Backups
All modified files are backed up to `/var/backups/airplayer-appliance/`:
```
/var/backups/airplayer-appliance/
├── config.txt.20241122_143052
├── sshd_config.20241122_143053
├── fstab.20241122_143055
└── ...
```

## Examples

### Dry-Run Before Making Changes
```bash
$ ./setup.sh --dry-run
╔═══════════════════════════════════════════════════════════════════╗
║     Air Player Appliance Builder - Raspberry Pi 5                 ║
║     Idempotent Configuration Management                           ║
╚═══════════════════════════════════════════════════════════════════╝

*** DRY RUN MODE - No changes will be made ***

[1/10] Checking Network Configuration...
  ✓ Network already configured correctly
  ✓ systemd-networkd already enabled

[2/10] Checking SSH Configuration...
  ✓ SSH already configured correctly

[3/10] Checking System Packages...
  ✓ All required packages already installed

[4/10] Checking Auto-Login Configuration...
  ✓ Auto-login already configured
  ✓ Auto-startx already in .profile

[5/10] Checking X11 Configuration...
  ✓ .xinitrc already configured
  ✓ Xorg already configured

[6/10] Checking Boot Configuration...
  ✓ GPU memory already set to 384MB
  ✓ WiFi already disabled
  ✓ Bluetooth already disabled
  ✓ IPv6 already disabled at boot

[7/10] Checking Air Player Installation...
  → Extracting/updating Air Player
    Would extract: AirPlayer.zip to /opt/AirPlayer
  ✓ udev rules already configured
  ✓ libzip symlink already exists

[8/10] Updating Display Configuration...
  → Regenerating Openbox autostart (display config from properties)
    Would write: /home/airman/.config/openbox/autostart
    Displays: 2

[9/10] Checking System Hardening...
  ✓ Volatile logging already configured
  ✓ Log directories already symlinked
  ✓ Log levels already configured
  ✓ noatime already in fstab
  ✓ Swap already disabled
  ✓ Swappiness already set to 0
  ✓ IPv6 already disabled via sysctl
  ✓ Firewall already configured
  ✓ System hardening checked

[10/10] Finalizing...

╔═══════════════════════════════════════════════════════════════════╗
║                   Configuration Complete!                          ║
╚═══════════════════════════════════════════════════════════════════╝

*** DRY RUN MODE - No changes were made ***
Run without --dry-run to apply changes
```

### Change Display Configuration
```bash
# Edit properties
$ nano setup.properties
# Change NUM_DISPLAYS=2 to NUM_DISPLAYS=3
# Add tertiary display settings

# See what would change
$ ./setup.sh --dry-run
[8/10] Updating Display Configuration...
  → Regenerating Openbox autostart (display config from properties)
    Would write: /home/airman/.config/openbox/autostart
    Displays: 3

# Apply changes
$ ./setup.sh
[8/10] Updating Display Configuration...
  → Regenerating Openbox autostart (display config from properties)
    Backed up: /home/airman/.config/openbox/autostart → ...
  ✓ Display configuration updated

Changes were made. A reboot is recommended...
```

### Upgrade AirPlayer
```bash
# Copy new version
$ cp ~/Downloads/AirPlayer-5.1.zip AirPlayer.zip

# Update (will extract new version)
$ ./setup.sh

[7/10] Checking Air Player Installation...
  → Extracting/updating Air Player
Archive:  AirPlayer.zip
  inflating: /opt/AirPlayer/AirPlayer
  inflating: /opt/AirPlayer/Bootloader
  ...
  ✓ Air Player extracted

# Restart X to reload AirPlayer
# Or just reboot
```

## Behavior Changes

### Section 7: AirPlayer
**OLD:** Only extract if not present  
**NEW:** Always extract (handles upgrades, preserves license)

### Section 8: Display Configuration
**OLD:** Generate once on first install  
**NEW:** Always regenerate from current properties (easy updates)

### Section 9: System Hardening
**OLD:** Always apply settings  
**NEW:** Check first, only change if needed

### All Sections
**NEW:** Backup before modifying files  
**NEW:** Report what's happening (or would happen in dry-run)  
**NEW:** Skip if already configured correctly

## Use Cases

### 1. Initial Installation
```bash
./setup.sh
# Configures everything, reboots
```

### 2. Change Monitor Layout
```bash
# Edit display settings in setup.properties
./setup.sh --dry-run  # Check changes
./setup.sh            # Apply
# Reboot to apply display changes
```

### 3. Upgrade AirPlayer Software
```bash
# Replace zip file
./setup.sh  # Extracts new version
# Restart X or reboot
```

### 4. Change Network Settings
```bash
# Edit network settings in setup.properties
./setup.sh --dry-run  # Preview
./setup.sh            # Apply
# Reboot for network changes
```

### 5. Audit Current Configuration
```bash
./setup.sh --dry-run  # Shows current state
```

### 6. Fix Broken Config
```bash
./setup.sh --force  # Reconfigure everything
```

## State File

Location: `/var/lib/airplayer-appliance/state`

Example contents:
```
network_ip=192.168.5.198
network_configured=20241122
ssh_configured=20241122
packages_installed=20241122
autologin_configured=20241122
x11_configured=20241122
boot_configured=20241122
gpu_memory=384
airplayer_installed=20241122
num_displays=2
display_config=20241122
hardening_configured=20241122
last_run=20241122_143052
```

## Backup Directory

Location: `/var/backups/airplayer-appliance/`

Files backed up with timestamp:
```
config.txt.20241122_143052
sshd_config.20241122_143053
fstab.20241122_143055
10-eth0.network.20241122_143056
...
```

## Rollback

To restore a backed up file:
```bash
# List backups
ls -la /var/backups/airplayer-appliance/

# Restore specific file
sudo cp /var/backups/airplayer-appliance/fstab.20241122_143055 /etc/fstab
```

## Key Benefits

1. **License Preservation** - Same hardware UUID, license stays valid
2. **Easy Updates** - Change properties, rerun script
3. **Safe to Rerun** - Won't break working config
4. **Fast Execution** - Skips unchanged items
5. **Audit Trail** - Backups and state tracking
6. **Dry-Run Mode** - See changes before applying
7. **AirPlayer Upgrades** - Just replace zip and rerun

## Migration from Old Script

The old script can still be used for first installs, but the new script is recommended:

**Old workflow:**
```bash
# Change config
nano setup.properties
# Reimage SD card
# Reinstall everything
```

**New workflow:**
```bash
# Change config
nano setup.properties
# Rerun script
./setup.sh
# Reboot if needed
```

Much faster! No reimaging needed.

## Limitations

- Network changes require reboot to apply
- Display changes require X11 restart (or reboot)
- Some changes may need system reboot
- AirPlayer restart needed after upgrade

## Tips

1. Always `--dry-run` first when unsure
2. Keep `setup.properties` in version control
3. Note the backup directory for rollbacks
4. State file tracks what's been done
5. Use `--force` to reconfigure everything

## When to Use --force

- System was partially configured manually
- Want to ensure everything matches properties file
- Troubleshooting configuration issues
- Migrating from old script version

## Examples of What Gets Skipped

If already configured:
- Network files (unless IP changed in properties)
- SSH config (unless settings changed)
- Package installation (unless packages missing)
- Boot config (unless GPU memory changed)
- System hardening (unless not yet applied)

Always processed:
- AirPlayer extraction (handles upgrades)
- Display configuration (regenerated from properties)

## Summary

The idempotent version:
- ✅ Checks before changing
- ✅ Preserves AirPlayer license
- ✅ Allows easy configuration updates
- ✅ Handles AirPlayer upgrades
- ✅ Creates backups
- ✅ Tracks state
- ✅ Supports dry-run mode
- ✅ Fast when nothing changed
- ✅ Safe to run repeatedly
