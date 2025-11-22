# Contributing to Air Player Appliance Builder

## About This Project

This is the **Air Player Appliance Builder** - a production-ready script for building hardened Air Player appliances on Raspberry Pi 5.

**Status:** Version 1.0 - Initial release  
**Purpose:** Flight simulator instrument displays  
**Built for:** Security-conscious, long-term deployments

## Current Features

- Hardened security (SSH keys only, firewall, minimal services)
- SD card longevity optimization (noatime, no swap, volatile logging)
- Multi-display support (1-3 displays via HDMI/DSI)
- Network configuration (static IP, IPv6 disabled)
- Clean, repeatable builds (~17 minutes)

## Making Changes

### Before Submitting

1. **Test thoroughly** on actual Raspberry Pi 5 hardware
2. **Document changes** clearly in commit messages
3. **Update documentation** if behavior changes
4. **Maintain security** - don't weaken the hardening

### Testing Checklist

- [ ] Fresh Raspberry Pi OS Lite (64-bit) installation
- [ ] Script completes without errors
- [ ] Network configuration applies correctly on reboot
- [ ] AirPlayer launches and detects displays
- [ ] Verification commands all pass
- [ ] SSH stays connected during installation (with screen/tmux)

### Documentation Updates

If you change functionality, update:
- `README.txt` - If workflow or features change
- `SETUP_GUIDE.md` - If installation steps change
- `QUICK_REFERENCE.txt` - If commands change
- `install.sh` comments - Keep code well-documented

## Code Style

### Shell Script Guidelines

- Use `set -e` and `set -u`
- Comment each major section
- Use descriptive variable names
- Add progress indicators for long operations
- Handle errors gracefully

### Example:
```bash
# Good
echo -e "${BLUE}[X/10] Configuring feature...${NC}"
if [[ -f "$CONFIG_FILE" ]]; then
    sudo cp "$CONFIG_FILE" "$DEST" 2>/dev/null || true
else
    echo -e "${YELLOW}  Warning: Config file not found${NC}"
fi
echo -e "${GREEN}✓ Feature configured${NC}"

# Avoid
cp $file $dest  # No error handling, unclear variables
```

## Security Considerations

This is a **security-hardened** build. Changes should maintain or improve security:

✓ **Keep:** SSH key-only authentication  
✓ **Keep:** Firewall default-deny  
✓ **Keep:** Minimal services  
✓ **Keep:** IPv6 disabled  
✓ **Keep:** No swap (security)

✗ **Don't:** Add password authentication  
✗ **Don't:** Enable unnecessary services  
✗ **Don't:** Weaken firewall rules

## Performance Optimizations

SD card longevity is a priority:

✓ **Keep:** noatime on all mounts  
✓ **Keep:** Swap disabled  
✓ **Keep:** Volatile logging  
✓ **Keep:** Minimal writes

If adding features that increase writes, document the impact.

## Reporting Issues

### Good Issue Reports Include:

1. **Hardware:** Raspberry Pi model, RAM, displays
2. **Steps to reproduce:** Exact commands run
3. **Expected vs actual behavior:** What should happen vs what did
4. **Verification output:** Results of verification commands
5. **Logs:** Relevant journalctl or script output

### Example:

```
**Issue:** AirPlayer not starting after installation

**Hardware:** 
- Raspberry Pi 5 (8GB)
- 2x HDMI displays (1920x1080, 800x600)

**Steps:**
1. Fresh RPi OS Lite install
2. Ran install.sh with screen
3. Rebooted after prompt
4. No AirPlayer process running

**Expected:** Single ./AirPlayer process
**Actual:** No AirPlayer process

**Verification:**
$ ps aux | grep AirPlayer
(no output)

$ cat ~/.config/openbox/autostart
(shows ./AirPlayer & command)

$ ls -la /opt/AirPlayer
(AirPlayer binary exists, executable)
```

## Feature Requests

We're open to enhancements that:
- Improve security
- Reduce SD card writes
- Support additional hardware
- Simplify installation
- Enhance reliability

Please open an issue to discuss before implementing large changes.

## What We Won't Accept

- Changes that reduce security
- Features requiring GUI/desktop
- Support for wireless-only setups
- In-place update mechanisms (we prefer clean builds)
- Unnecessary dependencies

## License

See LICENSE file for details.

## Questions?

Review the documentation first:
- `README.txt` - Overview
- `SETUP_GUIDE.md` - Detailed guide
- `QUICK_REFERENCE.txt` - Commands

Still have questions? Open an issue!

---

**Thank you for contributing to making this project better!**
