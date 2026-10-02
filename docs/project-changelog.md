# Project Changelog

All notable changes to `flutter_zpl_printer` are documented here. Format based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Planned
- Firmware update progress UX improvements
- ProfileUtil dry-run mode for validation
- Graphics color encoding (ESC/P 8-color support)
- Format field definition querying
- Connection pooling for high-throughput scenarios

## [0.3.0] — 2026-04-07

### Added
- **FirmwareUtil:** Complete firmware update management
  - `getCurrentFirmwareVersion(Connection)` — Query installed version via SGD `appl.name`
  - `updateFirmware(Connection, Uint8List, firmwareName, onProgress)` — Conditional update (checks version first)
  - `updateFirmwareUnconditionally(Connection, Uint8List, onProgress)` — Force update skipping version check
  - Progress callback for UI feedback
  - **Warning:** Printer reboots after upload; connection lost (use ReconnectableConnection)

- **ProfileUtil:** Complete backup/restore operations
  - `createProfile(Connection, onProgress)` — Snapshot all settings, alerts, and cloneable files to ZIP
  - `createBackup()` — Alias for createProfile
  - `loadProfile(Connection, zipData, fileDeletionOption)` — Restore configuration from ZIP with selective file deletion
  - `loadBackup()` — Alias for loadProfile
  - ZIP structure: `settings.json` (SGD values), `alerts.json` (alert configs), cloneable files at root
  - Progress reporting: "Fetching settings", "Downloading files", "Creating ZIP", etc.
  - Graceful failure: missing files don't block profile creation
  - **Note:** Advanced scenarios (merge vs. replace) minimally tested

- **ZebraPrinterLinkOs extension:** Enterprise features for Link-OS printers
  - `getLinkOsVersion()` — Detect Link-OS presence and parse version (returns null if not Link-OS)
  - `downloadTtfFont(Uint8List, String)` — Store TrueType font to printer storage
  - `downloadTteFont(Uint8List, String)` — Store Embedded TrueType font
  - `configureAlerts(List<PrinterAlert>)` — Set printer alert policies
  - `getConfiguredAlerts()` — Query current alerts
  - `removeAlerts(List<PrinterAlert>)` — Delete specific alerts
  - `removeAllAlerts()` — Clear all alerts
  - `printStoredFormatWithVarGraphics(String, Map<String, String>)` — Print stored format with variable substitution
  - Font operations require Link-OS printer; throw `ConnectionException` if unavailable

- **ProfileConstants:** Curated list of cloneable SGD settings for backup
  - 100+ settings covering language, display, network, security, media, print
  - Excludes volatile/hardware-specific settings
  - Updates when new settings discovered

- **LinkOsVersion model:** Parsed firmware version
  - Fields: `major`, `minor`, `patch`, `rawString`
  - Factory: `LinkOsVersion.parse(String)` — Extracts version from `appl.link_os_version` SGD response

- **PrinterProfile model:** Structured profile representation
  - `settings: Map<String, String>` — SGD values
  - `alerts: List<PrinterAlert>` — Alert configurations
  - `files: Map<String, Uint8List>` — Cloneable files (fonts, formats, graphics)
  - Serialization: to/from ZIP via ProfileUtil

- **Test coverage expansion:** 62% → ~85%
  - FirmwareUtil tests: version comparison, conditional vs. unconditional, upload with progress
  - ProfileUtil tests: ZIP creation, ZIP parsing, settings round-trip, alert preservation
  - ZebraPrinterLinkOs tests: Link-OS detection, font download, alert management
  - ReconnectableConnection: disconnect simulation, exponential backoff verification
  - MultichannelTcpConnection/BleConnection: dual-channel routing

### Changed
- **ZebraPrinter:** Now includes convenience wrappers for firmware/profile via extension (non-breaking)
- **FileUtil.uploadFile():** Enhanced progress callback for large files
- **Sgd.doCommand():** Improved error messages for action failures
- **ResponseValidators.sgd():** More lenient handling of printer prompt variations

### Fixed
- **ReconnectableConnection:** Exponential backoff was hitting max too quickly (now 250ms → 2000ms)
- **MultichannelTcpConnection:** Status channel write was blocking print channel (fixed routing logic)
- **GrfEncoder:** Memory leak on large image conversion (now uses streaming decompression)
- **ProfileUtil:** Cloneable file detection too strict (relaxed to include more common file types)
- **BleConnection:** Characteristic discovery timeout on slow devices (increased to 10s)

### Deprecated
- None

### Removed
- None

### Security
- **ZplSanitizer:** Added validation for `^` and `~` injection in field data
- **ProfileUtil:** Sanitizes file paths before download to prevent directory traversal

---

## [0.2.0] — 2026-03-28

### Added
- **BleConnection:** Bluetooth Low Energy support
  - Parameterized by read/write characteristic UUIDs
  - Matches Zebra BLE service (`38eb4a80`) and standard characteristics
  - Notification-based reading (no polling)
  - Automatic reconnect on BLE disconnect

- **MultichannelTcpConnection:** Dual-port TCP optimization
  - Composes port 9100 (print) and port 9200 (status) connections
  - Routes commands intelligently: setvar → 9100, getvar → 9200
  - Reduces round-trip latency for status queries

- **MultichannelBleConnection:** Dual-characteristic BLE optimization
  - Print pair: `38eb4a82` (write), `38eb4a81` (read)
  - Status pair: `38eb4a84` (write), `38eb4a83` (read)
  - Analogous to MultichannelTcpConnection but over BLE

- **ReconnectableConnection:** Auto-reconnect decorator
  - Wraps any Connection (TCP, BLE, or multichannel)
  - Exponential backoff: 250ms → 500ms → 1000ms → 2000ms
  - Throws `ReconnectSuccessException` on successful reconnect (non-blocking signal to retry)
  - Never auto-retries; caller handles recovery

- **ResponseValidators:** Predicate factory methods
  - `sgd()` — Detects SGD response completion (prompt or quoted value)
  - `json()` — Validates complete JSON object/array
  - `status()` — Recognizes `~HS` with all 3 ETX-delimited lines
  - `multiline(n)` — Waits for N complete lines
  - `endsWith(String)` — Custom marker-based detection

- **BleDiscovery:** BLE scan support
  - Scans for Zebra BLE service UUID
  - Returns `DiscoveredPrinter` with BLE device ID

- **DiscoveryService.discoverAll():** Unified discovery
  - Merges TCP and BLE discovery streams
  - Deduplicates by address
  - Configurable transport types and timeout

### Changed
- **Connection.sendAndWaitForResponse():** Now uses ResponseValidator-based dual timeouts
  - Outer deadline prevents infinite waits on trickling data
  - Matches Link-OS SDK timeout behavior more closely
- **ConnectionConfig:** Added `interChunkDelayMs` for slower transports (default 0)

### Fixed
- **TcpConnection:** Incorrect socket timeout handling on reads
- **NetworkDiscovery:** Broadcast not working on some subnets (now tries directed + multicast)
- **PrinterStatus:** Parse errors on non-English locales (now more lenient)

### Deprecated
- None

### Removed
- None

### Security
- None (no changes)

---

## [0.1.0] — 2026-03-15

### Added
- **Connection layer** — Transport-agnostic abstraction
  - `Connection` abstract base with `open()`, `close()`, `write()`, `sendAndWaitFor*()`
  - Chunked write matching SDK behavior (default 512 byte chunks)
  - `waitForData()` with polling (50ms intervals)
  - `connectionDescription` for logging

- **TcpConnection** — Direct socket to printer
  - Supports port 9100 (ZPL) and 6101 (CPCL)
  - Clean error handling for disconnects

- **Sgd protocol** — Set-Get-Do text commands
  - `Sgd.get(setting, connection)` → `! U1 getvar "$setting"`
  - `Sgd.set(setting, value, connection)` → `! U1 setvar "$setting" "$value"`
  - `Sgd.doCommand(action, value, connection)` → `! U1 do "$action" "$value"`
  - Automatic quote stripping from responses
  - Error detection via ResponseValidator

- **PrinterStatus** — `~HS` response parsing
  - `mediaStatus`, `headTemp`, `nativeLanguage`, `errors`, `alerts`
  - `isReady` computed property
  - `PrinterStatus.query(connection)` factory method

- **PrinterLanguage** — Enum detection
  - `zpl` / `cpcl` / `unknown`
  - `PrinterLanguage.fromString()` factory

- **ZebraPrinter** — High-level API
  - `ZebraPrinter.connect(Connection)` — Open and detect language
  - `getStatus()`, `getLanguage()`, `getSetting()`, `setSetting()`, `doCommand()`
  - `printZpl(String)`, `sendCommand(String)` — Raw command passthrough
  - `calibrate()`, `restoreDefaults()`, `reset()`, `printConfigurationLabel()`, etc.

- **FileUtil** — E: and R: drive operations
  - `listFiles(connection, drive)` — DIR listing
  - `getFile(connection, path)` — Download file
  - `deleteFile(connection, path)` — Delete file
  - `uploadFile(connection, path, data)` — Upload file with progress
  - FTP variants stubbed (enterprise only)

- **FormatUtil** — Stored label format management
  - `storeFormat(connection, path, zpl)` — Save format to E:/R: drive
  - `listFormats(connection, drive)` — List stored formats
  - `deleteFormat(connection, path)` — Delete stored format
  - Multiple `printFormat()` overloads (with/without variables, graphics)

- **GraphicsUtil** — Image and GRF handling
  - `printImage()` — Inline GRF in label
  - `storeGraphics()` — Save GRF to printer storage (`~DG`)
  - `recallStoredGraphics()` — Recall stored GRF (`^XG`)

- **GrfEncoder** — PNG/JPEG to GRF conversion
  - `encodeImage(Uint8List)` → hex GRF data
  - Dithering and threshold modes
  - Uses `image` package for decoding

- **Z64Compressor** — GRF data compression
  - Deflate + base64 + CRC16 encoding
  - Reduces label payload for bandwidth-constrained links (BLE, satellite)

- **ZplSanitizer** — Input validation
  - `validateFieldData()`, `validatePath()` — Checks for `^` and `~` injection
  - Prevents malicious ZPL injection attacks

- **Discovery** — Printer finding
  - **NetworkDiscovery:** UDP broadcast, directed, multicast, TCP probe
  - **BleDiscovery:** BLE scan support (minimal in v0.1; full in v0.2)
  - **DiscoveredPrinter:** Model for search results (address, name, model, connection type)

- **Error handling**
  - `ConnectionException` — Base exception for connection issues
  - `ConnectionClosedException`, `ConnectionTimeoutException` — Specific subtypes
  - Clean error propagation through async stack

- **Configuration**
  - `ConnectionConfig` — Tune timeouts, chunk sizes, delays
  - Sensible defaults matching Link-OS SDK behavior

- **Testing**
  - `MockConnection` — Records writes, returns queued responses
  - Supports `simulateDisconnect()`, `failOpenCount`
  - Full unit test suite with 62% code coverage

- **Documentation**
  - `CLAUDE.md` architecture overview
  - Inline code comments explaining SDK correspondence
  - Comprehensive README with examples

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Security
- N/A (no security features in v0.1)

### Known Issues
- BLE discovery unavailable (added in v0.2)
- No firmware update support (added in v0.3)
- No backup/restore (added in v0.3)
- ProfileUtil, AlertUtil, FontUtil not implemented (v0.3 feature)

---

## Versioning Strategy

This project follows [Semantic Versioning](https://semver.org/):

- **MAJOR** — Breaking API changes, incompatible Connection protocol changes
- **MINOR** — New features, non-breaking additions to Connection or Printer API
- **PATCH** — Bug fixes, performance improvements, documentation

Release cycle:
- v0.x.0 every 2-4 weeks (feature releases)
- v0.x.y as needed (hot fixes)
- v1.0.0 when SDK feature parity reaches 95%+ and API is stable

---

## Migration Guides

### v0.2.0 → v0.3.0 (No breaking changes)

- New: `ZebraPrinterLinkOs` extension adds firmware/profile methods
- Existing code continues to work; no changes required
- To use firmware updates:
  ```dart
  // New in v0.3.0
  final updated = await printer.updateFirmware(fwBytes, firmwareName: 'V80.19');
  ```

### v0.1.0 → v0.2.0 (No breaking changes)

- New: BLE and ReconnectableConnection support
- Existing TCP code works unchanged
- To use BLE:
  ```dart
  // New in v0.2.0
  final ble = BleConnection(deviceId: 'ABC123', ...);
  final printer = await ZebraPrinter.connect(ble);
  ```

---

## Credits

- **Protocol reference:** Link-OS SDK source at `libs/ZSDK_src/`
- **BLE characteristics:** Zebra BLE documentation and protocol research
- **Community:** Early adopters and testers providing feedback

