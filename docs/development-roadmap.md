# Development Roadmap

## Project Vision

`flutter_zpl_printer` is a pure-Dart Flutter library that provides comprehensive Zebra printer control by speaking Zebra's native printer protocols directly, eliminating dependency on the official Link-OS SDK while maintaining high feature parity.

## Completed Phases

### Phase 1: Foundation (v0.1.0 — Completed)

- TCP connection with chunked write and response validation
- Basic ZPL print commands and SGD protocol
- PrinterStatus parsing from `~HS` response
- Error handling and connection lifecycle management
- MockConnection for testing

**Commit:** `6ff33c4` — Initial commit with detailed README

### Phase 2: BLE & Multichannel (v0.1.0 → v0.2.0 — Completed)

- BLE connection via `universal_ble` package (Zebra service/characteristic UUIDs)
- MultichannelTcpConnection (port 9100 print, 9200 status)
- MultichannelBleConnection (dual BLE characteristics)
- ReconnectableConnection with exponential backoff
- ResponseValidators factory methods

**Commit:** `35ab104` — Add BLE multichannel connection and fix V2 code review issues

### Phase 3: SDK Completion (v0.2.0 → v0.3.0 — Completed)

- FirmwareUtil: `updateFirmware()`, `updateFirmwareUnconditionally()`, `getCurrentFirmwareVersion()`
- ProfileUtil: `createProfile()`, `createBackup()`, `loadProfile()`, `loadBackup()` (ZIP-based)
- ZebraPrinterLinkOs extension: Link-OS detection, firmware updates, font management, alert management
- Profile import/export with settings, alerts, and cloneable file preservation
- Comprehensive test coverage: 62% → ~85%

**Commit:** `834d56f` — Complete SDK implementation with firmware, profile, and file management utilities

## Current Status

**SDK Feature Parity:** ~85% (core features + Link-OS extensions)

### Implemented Features

**Connection Layer:**
- ✓ TCP (port 9100/6101)
- ✓ BLE via `universal_ble`
- ✓ Multichannel (TCP + BLE)
- ✓ Auto-reconnect with exponential backoff
- ✓ Response validation predicates

**Printer Operations:**
- ✓ SGD (Set-Get-Do) protocol
- ✓ Status query (`~HS`)
- ✓ ZPL print commands
- ✓ File operations (list, download, upload, delete)
- ✓ Format storage and recall
- ✓ Graphics/GRF encoding and Z64 compression
- ✓ Font management (TTF, TTE)
- ✓ Alert configuration
- ✓ Profile backup/restore (ZIP-based)
- ✓ Firmware updates with version checking

**Discovery:**
- ✓ TCP discovery (broadcast, directed, multicast, subnet scan)
- ✓ BLE discovery
- ✓ Unified DiscoveryService

### Known Limitations

**Out of Scope (Will Not Implement):**
- Classic Bluetooth (deprecated; use BLE instead)
- USB connections (requires platform-specific native code)
- Certificate management (complex PKI; most users don't need)
- SNMP monitoring (rarely used; can poll SGD instead)
- Weblink UI automation (deprecated in modern printers)

**Partial Implementation:**
- **FileUtil FTP variants:** `ftpUploadFile()`, `ftpDownloadFile()` — stubs only; enterprise feature rarely used
- **FormatUtil stream variant:** `printStoredFormatWithVarGraphics(stream)` — supports basic overloads; full streaming variant not implemented
- **ProfileUtil advanced modes:** Complex import scenarios (e.g., merge vs. replace) not fully tested on all printer models

## Remaining Work

### Short Term (v0.3.x patch releases)

1. **Firmware update UX polish**
   - Better progress feedback during upload
   - Graceful handling of reboot-induced disconnects
   - Post-update verification (firmware version check after reconnect)

2. **ProfileUtil robustness**
   - Handle missing ZIP entries gracefully
   - Support for cloneable file filtering (certain extensions only)
   - Dry-run mode (validate without applying)

3. **Error messages & debugging**
   - More specific ConnectionException types
   - Request/response logging for troubleshooting
   - Clearer timeout vs. protocol errors

### Medium Term (v0.4.0)

1. **Graphics enhancements**
   - Support for color ESC/P (8-color) encoding
   - Batch image upload optimization
   - QR code generation helpers

2. **Format & field management**
   - Query field definitions from stored formats
   - Field-level validation before print
   - Version control for format changes

3. **Performance**
   - Connection pooling for high-throughput scenarios
   - Batch command optimization
   - Memory-efficient streaming for large files

### Long Term (v0.5.0+)

1. **Extended device support**
   - Mobile printer support (ZQ, ZR series) specific tuning
   - Desktop printer advanced settings
   - Industrial printer high-temp/high-speed modes

2. **Analytics & telemetry**
   - Printer utilization tracking
   - Print job history
   - Ink/media consumption monitoring

3. **Ecosystem integration**
   - Label template library
   - Cloud backup integration
   - Multi-printer orchestration helpers

## Version History

| Version | Date | Key Changes |
|---------|------|------------|
| 0.1.0 | 2026-03-15 | Initial release: TCP, ZPL, SGD, status |
| 0.2.0 | 2026-03-28 | BLE, multichannel, reconnect |
| 0.3.0 | 2026-04-07 | Firmware, profiles, Link-OS extensions |
| 0.4.0 | TBD | Graphics, format management, performance |
| 0.5.0 | TBD | Extended devices, analytics, ecosystem |

## Milestones & Success Metrics

### Milestone 1: Feature Parity (v0.3.0) ✓
- **Target:** 85% SDK coverage
- **Status:** Achieved
- **Metrics:** All core operations work; Link-OS extensions functional

### Milestone 2: Stability (v0.3.x)
- **Target:** <5% test failure rate on real hardware
- **Status:** On track
- **Metrics:** Comprehensive error handling, reliable auto-reconnect

### Milestone 3: Performance (v0.4.0)
- **Target:** <2s label print-to-output on LAN, <500ms discovery
- **Status:** Pending
- **Metrics:** Throughput benchmarks, memory profiling

### Milestone 4: Ecosystem (v0.5.0+)
- **Target:** 10+ integrations with popular label systems
- **Status:** Future
- **Metrics:** Third-party usage, GitHub stars, adoption

## Dependencies

- **Flutter:** >=3.3.0
- **Dart SDK:** ^3.10.0
- **universal_ble:** ^1.2.0 (for BLE)
- **image:** ^4.8.0 (for GRF encoding)
- **archive:** ^4.0.0 (for ZIP profiles)

## Contributing

New features should:
1. Maintain transport agnosticism (work with any Connection)
2. Include tests with MockConnection
3. Avoid hard-coded timeouts; use config
4. Document Zebra SDK equivalent (e.g., "Mirrors SDK's `ProfileUtil.java`")

## Notes

- This library is **not affiliated** with Zebra Technologies. It is an independent implementation of Zebra's printer protocols.
- Firmware updates carry risk; test in non-production first.
- BLE has inherent latency; TCP is recommended for high-throughput scenarios.
