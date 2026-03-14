# Sim-Bridge Integration — Discussion Document

**Status:** For discussion only. Not an implementation plan.
**Date:** 2026-03-14
**Author:** Derived from engineering interview

---

## 1. Context & Scope

The RPi 5 AirPlayer appliance is being extended to also run the sim-bridge daemon. Sim-bridge bridges physical cockpit hardware (Arduino Mega 2560 R3 and up to three ESP32-WROOM-32 instrument displays) to X-Plane via UDP.

All configuration and installation is performed by `setup.sh`. Operator access to the Pi is exclusively via SSH. Operator input during setup is minimised.

This document covers:
- How sim-bridge software is distributed and downloaded
- Security: signature verification and device licensing
- Service installation and configuration
- USB hardware: udev rules and firmware flashing
- bridge.json ownership
- Firewall rules
- New scripts required
- Open questions and deferred decisions

---

## 2. Architecture Changes to Existing setup.sh

### 2.1 Knobster udev rule — REMOVED

The existing Knobster (AirPlayer USB device) udev rule is removed from `setup.sh`. This Pi does not use a Knobster. This is an architectural correction, not just a sim-bridge change.

### 2.2 Section numbering

Current sections run `[1/10]` through `[10/10]`. Adding a sim-bridge section between system hardening and finalisation changes this to `[1/11]` through `[11/11]`:

| Section | Content |
|---------|---------|
| 1–9 | Unchanged (renumbered to `/11`) |
| 10 | **NEW — Sim-Bridge Installation** |
| 11 | Finalisation (currently section 10) |

### 2.3 Conditional installation

Sim-bridge installation is entirely conditional on a single property:

```
SIMBRIDGE_ENABLED=yes|no
```

When `no`: no bridge software, no udev rules, no firewall rules, no `avrdude`, no `esptool` are installed. A non-bridge appliance is completely unaffected.

---

## 3. Bootstrap & Distribution Model

### 3.1 Manual bootstrap (unchanged)

The only files that must be manually SCP'd to the Pi before running `setup.sh`:

- `setup.sh`
- `setup.properties`

Everything else is downloaded by `setup.sh` at runtime.

### 3.2 Downloaded components

| Component | Source | Notes |
|-----------|--------|-------|
| sim-bridge binary | Operator-controlled HTTPS server | Versioned, GPG signed |
| Firmware package | Operator-controlled HTTPS server | Mega `.hex` + ESP32 `.bin` + `manifest.json` |
| AirPlayer | Sim Innovations (direct) | **TBD** — see section 3.4 |

### 3.3 Version pinning — no blind updates

`setup.properties` holds the pinned approved version and GPG signature reference for each component. `setup.sh` downloads exactly that version and refuses to proceed if verification fails. The operator controls when a new version is approved and updates `setup.properties` accordingly.

### 3.4 Fallback to bundled base copy

If a download fails or the server is unreachable, `setup.sh` falls back to a bundled base copy included in the setup package. The base copy is the last known-good tested version. Download of a newer version is always attempted first.

### 3.5 AirPlayer distribution — TBD

**Open question:** Whether Sim Innovations permits redistribution of their binary as a bundled fallback copy requires confirmation. If not permitted, the fallback strategy for AirPlayer must differ (fail with a clear operator message rather than use a cached copy).

---

## 4. Security

### 4.1 GPG signature verification

All downloaded components are verified against a GPG signature before installation. The CI pipeline that builds and packages sim-bridge signs the tarball and uploads both the tarball and detached signature file to the download server. `setup.properties` holds the GPG key reference for verification.

Verification applies to every download regardless of source. The fallback bundled copy is also pre-verified at package time.

### 4.2 Download protocol

| Phase | Protocol | Authentication |
|-------|----------|---------------|
| Development | HTTPS GET | None |
| Production | HTTPS POST | Device key + hardware UUID in request headers |

The production server validates the device binding before returning the requested file.

### 4.3 Device licensing — Option 2: Key + Hardware Fingerprint Binding

Each appliance is issued a UUID-style device key. The key is provided by the operator at install time:

```bash
./setup.sh --device-key a3f7c812-9b4e-4d21-bc3a-7f1e2d890abc
```

**First use:** The server receives the key + Pi hardware UUID. It records the binding. Subsequent requests must present both the matching key and the same hardware UUID. A key from one device will not work on different hardware.

**Key storage on device:** `/etc/airplayer-appliance/device.key` — root-readable only.

**Rebuild:** The key file is gone. The operator retrieves the key from their account portal and passes it again at install time.

**Key check timing:** Only at download time (install or upgrade). No runtime validation. The bridge service runs without checking the key on every boot.

**Development phase:** No key required. Downloads proceed without authentication. GPG verification still applies.

### 4.4 Device portal / backend — TBD

A web portal for device registration, key issuance, key revocation, and account recovery is a known future requirement. Not in scope for the current phase. Per-device keys with hardware binding is the confirmed model. The portal must support:

- New device registration → key issuance
- Key revocation (per device)
- Account password recovery
- Re-bind workflow (hardware UUID change)
- Per-device history: install date, last download, key status

---

## 5. Sim-Bridge Service Installation

### 5.1 What gets installed

When `SIMBRIDGE_ENABLED=yes`:

- sim-bridge binary → `/opt/bridge/bin/bridge`
- `bridge.service` systemd unit → enabled and started on boot
- `bridge` system user (nologin, no home directory)
- `bridge` user added to `dialout` group for USB serial device access
- `avrdude` (apt package) — Arduino Mega firmware flashing
- `esptool` (pip package) — ESP32 firmware flashing
- udev rules for all USB hardware (see section 6)
- `bridge.json` written from `setup.properties` values (see section 7)
- UFW firewall rules for bridge UDP ports (see section 8)
- Firmware package deployed to `/opt/bridge/firmware/`
- Initial firmware flashed to connected hardware (see section 9)

### 5.2 What is never installed by setup.sh

- `arduino-cli` — development tool, not required on production appliance
- GitHub Actions runner — development tool, not required
- Any Arduino toolchain or compiler

If a development machine has these installed, `setup.sh` does not remove them and does not install them. It is silent on their presence.

### 5.3 Service behaviour

The `bridge` service is enabled and auto-starts on boot from the moment it is installed. No manual `systemctl start` step is required.

**Development phase:** Service starts unconditionally after installation.
**Production:** Device key must be provided at install and validated against the portal before the service is activated. *(TBD — portal not yet built.)*

---

## 6. USB Hardware & udev Rules

### 6.1 Conditional on sim-bridge

udev rules for USB serial devices are written **only when** `SIMBRIDGE_ENABLED=yes`. A non-bridge install has no USB serial udev rules.

### 6.2 Persistent device names

Four USB devices are connected to the Pi's USB ports:

| Device | Persistent name |
|--------|----------------|
| Arduino Mega 2560 R3 | `/dev/simbridge-mega` |
| ESP32 — elevator trim | `/dev/simbridge-esp-elevator-trim` |
| ESP32 — flaps | `/dev/simbridge-esp-flaps` |
| ESP32 — rudder trim | `/dev/simbridge-esp-rudder-trim` |

### 6.3 Port-position udev rules

Persistent naming is achieved by binding each device name to the kernel path of its physical USB port on the Pi 5. The kernel path is a hardware constant for each physical port — it does not change between boots or connection events.

A udev rule of the form:

```
SUBSYSTEM=="tty", KERNELS=="<port-path>", SYMLINK+="simbridge-esp-elevator-trim"
```

guarantees that any device plugged into that physical port always receives that name, regardless of boot order or connection sequence.

### 6.4 Physical wiring requirement

This is a **wiring specification**, not just a software rule. Each Pi 5 USB port is designated for a specific device. The operator connects each device to its designated port during physical installation. The device stays in that port permanently.

`setup.properties` holds the kernel port path for each designated port:

```
SIMBRIDGE_PORT_MEGA=<tbd>
SIMBRIDGE_PORT_ESP_ELEVATOR_TRIM=<tbd>
SIMBRIDGE_PORT_ESP_FLAPS=<tbd>
SIMBRIDGE_PORT_ESP_RUDDER_TRIM=<tbd>
```

### 6.5 When udev rules are written

udev rules are written during the sim-bridge installation block within `setup.sh`. By the time setup runs, the Pi has already booted and all USB devices are physically connected and enumerated. The rules are written once and are thereafter permanent.

On reinstall or update, `setup.sh` checks whether rules already exist and whether they match `setup.properties`. Rules are only rewritten if they have changed or if `--force` is passed.

### 6.6 TBD — Pi 5 USB port kernel paths

The actual kernel paths (`1-1.1` etc.) for each physical USB port on the Pi 5 must be discovered from live hardware:

```bash
udevadm info /dev/ttyUSB0 | grep KERNELS
```

This maps physical port to kernel path once. The values are documented and added to `setup.properties` permanently. All subsequent installs use those values.

**Deferred:** Hardware inspection when ESP32 boards arrive (~3 days).

### 6.7 TBD — ESP32 USB chip serial numbers

If the ESP32 development boards have unique USB chip serial numbers (CP2102, CH340 or other), serial-number-based udev rules would be preferred over port-position rules — they would be port-independent, allowing boards to be moved between ports without reconfiguring. This will be checked when hardware arrives.

If unique serials exist → serial-number rules replace port-position rules.
If not → port-position rules confirmed as the approach.

---

## 7. bridge.json Ownership

### 7.1 Fields owned by setup.sh

`setup.sh` derives the following fields from `setup.properties` and writes them into `bridge.json`. These fields are updated on every `setup.sh` run:

| `bridge.json` field | Source in `setup.properties` |
|--------------------|------------------------------|
| `network.listen_ip` | `NETWORK_IP` (Pi's static IP — bind to specific interface, not `0.0.0.0`) |
| `network.plugin_ip` | `FIREWALL_AIRMANAGER_IP` (X-Plane host IP) |
| `network.plugin_port` | `SIMBRIDGE_PLUGIN_PORT` (default: 49500) |
| `network.listen_port` | `SIMBRIDGE_LISTEN_PORT` (default: 49501) |
| `network.update_rate_hz` | `SIMBRIDGE_UPDATE_RATE_HZ` |
| `logging.level` | `SIMBRIDGE_LOG_LEVEL` |
| `devices[].serial_port` | Persistent udev device names (section 6.2) |

**On `listen_ip`:** The bridge binds to the Pi's specific network interface IP, not `0.0.0.0`. The firewall provides a second independent layer of access control. Both enforce the same restriction.

### 7.2 Fields owned by the operator

The `controls` array in `bridge.json` is **never written or modified by `setup.sh`**. It is hand-crafted by the operator to match the specific cockpit wiring. No two cockpits are identical.

### 7.3 First install vs update behaviour

- **First install:** `setup.sh` writes the complete `bridge.json` — all infrastructure fields from `setup.properties` plus an empty `controls` array as a starting point.
- **Subsequent runs:** `setup.sh` updates only the fields it owns (section 7.1). The `controls` array is preserved untouched.

---

## 8. Firewall Rules

### 8.1 Sim-bridge UDP rules (conditional)

When `SIMBRIDGE_ENABLED=yes`, the following UFW rules are added alongside the existing AirPlayer rules:

| Direction | Protocol | Source/Dest | Port | Purpose |
|-----------|----------|-------------|------|---------|
| Inbound | UDP | `FIREWALL_AIRMANAGER_IP` → `NETWORK_IP` | `SIMBRIDGE_LISTEN_PORT` (49501) | DataRef updates from X-Plane plugin |
| Outbound | UDP | `NETWORK_IP` → `FIREWALL_AIRMANAGER_IP` | `SIMBRIDGE_PLUGIN_PORT` (49500) | DataRef writes to X-Plane plugin |

### 8.2 Ports are protocol constants

Ports 49500 and 49501 are static, pre-agreed values forming part of the bridge protocol. They are not per-install choices. Their defaults in `setup.properties` should rarely if ever change.

### 8.3 Sim host firewall — operator responsibility

The machine running X-Plane must also have its firewall configured to permit this traffic:
- Inbound UDP on port 49500 (receives DataRef writes from bridge)
- Outbound UDP to the Pi on port 49501 (sends DataRef updates to bridge)

This is outside `setup.sh`'s scope but must be documented in the setup guide.

---

## 9. Firmware Package & Initial Flashing

### 9.1 Firmware package structure

The firmware package is downloaded from the server as part of bridge installation and deployed to `/opt/bridge/firmware/`:

```
/opt/bridge/firmware/
  manifest.json          ← version metadata per device type
  mega.hex               ← Arduino Mega compiled firmware
  esp32_avionics.bin     ← ESP32 compiled firmware (all units, same binary)
```

All ESP32 units run identical firmware. The instrument role (elevator trim, flaps, rudder trim) is assigned at runtime by sim-bridge via a JSON `config` message over serial — it is not encoded in the firmware.

### 9.2 Initial flash during bridge installation

On first install, `setup.sh` flashes all connected hardware as part of the bridge installation block:

- Arduino Mega: `avrdude` with `mega.hex`
- Each connected ESP32: `esptool` with `esp32_avionics.bin`

Boards are physically connected and enumerated before setup runs (section 6.5). The persistent udev names are used — no reliance on `/dev/ttyUSB0` ordering.

### 9.3 Reinstall behaviour

On reinstall, boards already have a working sketch. `setup.sh` checks the manifest version against the version reported by each device. If versions match, flashing is skipped. If there is a mismatch, the operator is prompted interactively before any flash is performed.

---

## 10. Firmware Upgrade Script

### 10.1 upgrade-firmware.sh

Firmware upgrades are handled by a dedicated `upgrade-firmware.sh` script, not by `setup.sh`. Upgrades are **operator-triggered only** — there is no periodic or automatic upgrade mechanism.

### 10.2 Upgrade process

1. Query current firmware version from each connected device
2. Download latest compatible firmware package from server (GPG verified)
3. Compare versions — display current vs available per device
4. Prompt operator to confirm before proceeding (interactive menu)
5. Display clear warning: **"Do not power off during firmware update"**
6. Flash each device in sequence
7. Verify version on each device after flashing
8. Report success or failure per device

### 10.3 Scope

- Applies to: Arduino Mega and all connected ESP32 devices
- All ESP32 devices receive the same binary
- Each device is flashed and verified individually before moving to the next

---

## 11. New setup.properties Properties

The following new properties are required. Existing properties are unchanged.

```properties
# ============================================================================
# SIM-BRIDGE INSTALLATION
# ============================================================================
SIMBRIDGE_ENABLED=no

# Download server
SIMBRIDGE_DOWNLOAD_SERVER=https://downloads.example.com
SIMBRIDGE_DOWNLOAD_ROOT=/releases/sim-bridge

# Pinned versions and GPG references
SIMBRIDGE_VERSION=0.1.0
SIMBRIDGE_GPG_KEY_ID=<fingerprint>
SIMBRIDGE_FIRMWARE_VERSION=1.0.0
SIMBRIDGE_FIRMWARE_GPG_KEY_ID=<fingerprint>

# Device key (production only — passed via --device-key CLI arg or stored here)
# SIMBRIDGE_DEVICE_KEY=

# Bridge runtime config
SIMBRIDGE_PLUGIN_PORT=49500
SIMBRIDGE_LISTEN_PORT=49501
SIMBRIDGE_UPDATE_RATE_HZ=10
SIMBRIDGE_LOG_LEVEL=INFO

# USB port kernel paths (Pi 5) — TBD from hardware inspection
SIMBRIDGE_PORT_MEGA=
SIMBRIDGE_PORT_ESP_ELEVATOR_TRIM=
SIMBRIDGE_PORT_ESP_FLAPS=
SIMBRIDGE_PORT_ESP_RUDDER_TRIM=
```

Note: `FIREWALL_AIRMANAGER_IP` and `NETWORK_IP` (already in `setup.properties`) are reused for bridge configuration — no duplication.

---

## 12. Open Questions & Deferred Decisions

| # | Item | Status |
|---|------|--------|
| 1 | Pi 5 USB port kernel path mapping | Deferred — hardware inspection in ~3 days |
| 2 | ESP32 USB chip serial number check | Deferred — hardware inspection in ~3 days. May replace port-position rules with serial-number rules |
| 3 | AirPlayer redistribution rights | Requires confirmation with Sim Innovations. Affects fallback strategy |
| 4 | Device portal / backend | Future requirement. Confirmed model: per-device UUID key + hardware UUID binding |
| 5 | ESP32 device count per install | Currently 1. Up to 3 planned. `upgrade-firmware.sh` must iterate all connected devices |
| 6 | diagnostics.sh extension | Not discussed. Likely needs bridge service status, connected device versions, and USB device presence checks |
| 7 | AirPlayer download URL / GPG | Requires Sim Innovations confirmation |
| 8 | `bridge.json` controls array commissioning | Operator hand-crafts this. No tooling planned. Needs documentation |

---

## 13. Summary of New Scripts

| Script | Purpose |
|--------|---------|
| `upgrade-firmware.sh` | Operator-triggered firmware upgrade for Mega and ESP32 devices. Interactive, with version checking and confirmation gates. |

`setup.sh` gains one new section (sim-bridge installation, section 10 of 11). All other scripts are unchanged in purpose, though `diagnostics.sh` extension is flagged as a likely requirement (item 6 above).
