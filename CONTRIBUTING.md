# Contributing to Air Player Appliance Builder

## About This Project

This is the **Air Player Appliance Builder** - a production-ready script for building and maintaining hardened Air Player appliances on Raspberry Pi 5.

**Status:** Version 1.1 - Idempotent Configuration Management  
**Purpose:** Flight simulator instrument displays  
**Built for:** Security-conscious, long-term deployments

## Current Features

**Version 1.1 Additions:**
- Idempotent configuration management
- --dry-run and --force modes
- State tracking and automatic backups
- Configuration updates without reimaging
- AirPlayer upgrade support
- Preserves license across updates

**Core Features:**
- Hardened security (SSH keys only, firewall, minimal services)
- SD card longevity optimization (noatime, no swap, volatile logging)
- Multi-display support (1-3 displays via HDMI/DSI)
- Network configuration (static IP, IPv6 disabled)
- Clean, repeatable builds (~17 minutes)
- Fast configuration updates (<1 minute)

## Making Changes

### Before Submitting

1. **Test thoroughly** on actual Raspberry Pi 5 hardware
2. **Test both workflows:**
   - Fresh installation (full reimage)
   - Configuration update (on running system)
3. **Document changes** clearly in commit messages
4. **Update documentation** if behavior changes
5. **Maintain security** - don't weaken the hardening
6. **Preserve idempotency** - ensure safe to rerun

### Testing Checklist

Fresh Installation:
- [ ] Fresh Raspberry Pi OS Lite (64-bit) installation
- [ ] Script completes without errors
- [ ] Network configuration applies correctly on reboot
- [ ] AirPlayer launches and detects displays
- [ ] Verification commands all pass
- [ ] SSH stays connected during installation (with screen/tmux)

Configuration Updates:
- [ ] Edit install.properties on running system
- [ ] --dry-run shows correct preview
- [ ] Script applies only necessary changes
- [ ] Backups created before modifications
- [ ] State file updated correctly
- [ ] Configuration actually applies after reboot
- [ ] AirPlayer license preserved

Idempotent Behavior:
- [ ] Running twice doesn't cause errors
- [ ] Second run skips already-configured items
- [ ] --force rebuilds everything
- [ ] --dry-run never makes changes

### Documentation Updates

If you change functionality, update:
- `README.txt` - If workflow or features change
- `SETUP_GUIDE.md` - If installation/update steps change
- `QUICK_REFERENCE.txt` - If commands change
- `IDEMPOTENT_GUIDE.md` - If idempotent behavior changes
- `install.sh` comments - Keep code well-documented

## Code Style

### Shell Script Guidelines

- Use `set -e` and `set -u`
- Comment each major section
- Use descriptive variable names
- Add progress indicators for long operations
- Handle errors gracefully
- Check state before making changes
- Back up files before modifying
- Update state file after changes

### Example - Idempotent Section:
```bash
# Good - Checks before acting
echo -e "${BLUE}[X/10] Checking configuration...${NC}"

if state_value_matches "setting" "value"; then
    echo -e "${GREEN}  ✓ Setting already configured${NC}"
else
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}  → Would configure setting${NC}"
    else
        echo -e "${YELLOW}  → Configuring setting${NC}"
        backup_file "/etc/config"
        # Make changes
        sudo cp "$CONFIG" "$DEST" 2>/dev/null || true
        update_state "setting" "value"
        update_state "setting_configured" "$(date +%Y%m%d)"
        CHANGES_MADE=true
        echo -e "${GREEN}  ✓ Setting configured${NC}"
    fi
fi
```

### State Management

Always use helper functions:
```bash
# Check if value matches
state_value_matches "key" "value"

# Update state
update_state "key" "value"

# Backup before modifying
backup_file "/path/to/file"
```

## Security Considerations

This is a **security-hardened** build. Changes should maintain or improve security:

✅ **Keep:** SSH key-only authentication  
✅ **Keep:** Firewall default-deny  
✅ **Keep:** Minimal services  
✅ **Keep:** IPv6 disabled  
✅ **Keep:** No swap (security)

❌ **Don't:** Add password authentication  
❌ **Don't:** Enable unnecessary services  
❌ **Don't:** Weaken firewall rules

## Performance Optimizations

SD card longevity is a priority:

✅ **Keep:** noatime on all mounts  
✅ **Keep:** Swap disabled  
✅ **Keep:** Volatile logging  
✅ **Keep:** Minimal writes

If adding features that increase writes, document the impact.

## Idempotency Requirements (v1.1)

All configuration changes must be idempotent:

✅ **Must:** Check current state before acting  
✅ **Must:** Skip if already configured  
✅ **Must:** Support --dry-run mode  
✅ **Must:** Back up before modifying  
✅ **Must:** Update state file  
✅ **Must:** Report what changed

❌ **Don't:** Assume fresh system  
❌ **Don't:** Modify files without checking  
❌ **Don't:** Ignore current state  
❌ **Don't:** Make changes in dry-run mode

## Reporting Issues

### Good Issue Reports Include:

1. **Hardware:** Raspberry Pi model, RAM, displays
2. **Version:** Script version (1.1, etc.)
3. **Workflow:** Fresh install or configuration update?
4. **Steps to reproduce:** Exact commands run
5. **Expected vs actual behavior:** What should happen vs what did
6. **Verification output:** Results of verification commands
7. **State file:** Contents of /var/lib/airplayer-appliance/state
8. **Logs:** Relevant journalctl or script output

### Example:

```
**Issue:** Display configuration not applying

**Version:** 1.1

**Workflow:** Configuration update on running system

**Hardware:** 
- Raspberry Pi 5 (8GB)
- 2x HDMI displays (1920x1080, 800x600)

**Steps:**
1. Edited install.properties: SECONDARY_ROTATION=left
2. Ran: ./install.sh --dry-run (showed would update)
3. Ran: ./install.sh (completed successfully)
4. Rebooted system
5. Display still landscape orientation

**Expected:** Secondary display rotated to portrait
**Actual:** Secondary display still landscape

**State file:**
$ cat /var/lib/airplayer-appliance/state
display_config=20241122
num_displays=2
...

**Verification:**
$ export DISPLAY=:0 && xrandr
HDMI-2 connected 800x600+0+0 (normal left right inverted) 0mm x 0mm
(shows normal, not left)

$ cat ~/.config/openbox/autostart
(shows xrandr commands - they include --rotate left)
```

## Feature Requests

We're open to enhancements that:
- Improve security
- Reduce SD card writes
- Support additional hardware
- Simplify installation or updates
- Enhance reliability
- Improve idempotent behavior
- Add useful state tracking

Please open an issue to discuss before implementing large changes.

## What We Won't Accept

- Changes that reduce security
- Features requiring GUI/desktop
- Support for wireless-only setups
- Changes that break idempotency
- Unnecessary dependencies
- Features that increase SD card writes significantly

## Version History

**Version 1.1:**
- Added idempotent configuration management
- State tracking and automatic backups
- --dry-run and --force modes
- Configuration updates without reimaging
- AirPlayer upgrade support
- Preserves license across updates

**Version 1.0:**
- Initial release
- Fresh installation workflow
- Security hardening
- Multi-display support

## Testing New Features

For new features, test:

**Fresh Installation:**
1. Image fresh SD card
2. Run full installation
3. Verify all functionality

**Configuration Updates:**
1. Install on test system
2. Make configuration change
3. Run with --dry-run (verify preview)
4. Run normally (verify applies)
5. Verify state file updated
6. Verify backup created
7. Run again (verify skips already-done)
8. Test rollback if applicable

**Idempotency:**
1. Run script
2. Run again immediately
3. Should skip all already-configured
4. No errors or warnings

**Edge Cases:**
1. Manually modify a config file
2. Run script - should detect and fix
3. Delete state file, run script
4. Should reconfigure everything

## License

See LICENSE file for details.

## Questions?

Review the documentation first:
- `README.txt` - Overview
- `SETUP_GUIDE.md` - Detailed guide with both workflows
- `QUICK_REFERENCE.txt` - Commands and examples
- `IDEMPOTENT_GUIDE.md` - Idempotent features

Still have questions? Open an issue!

---

**Thank you for contributing to making this project better!**
