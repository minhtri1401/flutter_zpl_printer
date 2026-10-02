# flutter_zpl_printer Codebase Summary

## Project Overview

`flutter_zpl_printer` is a pure-Dart Flutter library providing comprehensive Zebra label printer control by speaking Zebra's native printer protocols (SGD, ZPL, BLE) directly. No Link-OS SDK dependency.

- **Version:** 0.3.0
- **Status:** ~85% SDK feature parity
- **Test Coverage:** ~85%
- **Dart SDK:** ^3.10.0
- **Flutter:** >=3.3.0

## Directory Structure

```
.
├── lib/
│   ├── flutter_zpl_printer.dart                          # Barrel exports (public API)
│   └── src/
│       ├── connection/
│       │   ├── connection.dart              # Abstract Connection base
│       │   ├── connection_config.dart       # Timeout/chunk configuration
│       │   ├── tcp_connection.dart          # TCP/socket implementation
│       │   ├── ble_connection.dart          # BLE implementation
│       │   ├── bluetooth_constants.dart     # Zebra service/char UUIDs
│       │   ├── multichannel_tcp_connection.dart
│       │   ├── multichannel_ble_connection.dart
│       │   ├── reconnectable_connection.dart
│       │   └── response_validators.dart     # ResponseValidator factories
│       ├── discovery/
│       │   ├── discovery_service.dart       # Unified discovery
│       │   ├── network_discovery.dart       # TCP discovery
│       │   ├── ble_discovery.dart           # BLE discovery
│       │   └── discovered_printer.dart      # Model
│       ├── printer/
│       │   ├── zebra_printer.dart           # Main API
│       │   ├── zebra_printer_link_os.dart   # Extension for enterprise
│       │   ├── sgd.dart                     # Set-Get-Do protocol
│       │   ├── printer_status.dart          # ~HS response parsing
│       │   ├── printer_language.dart        # ZPL/CPCL detection
│       │   ├── file_util.dart               # File operations (E:, R:)
│       │   ├── format_util.dart             # Stored format management
│       │   ├── graphics_util.dart           # GRF/image operations
│       │   ├── font_util.dart               # Font download (Link-OS)
│       │   ├── alert_util.dart              # Alert management
│       │   ├── profile_util.dart            # Backup/restore (ZIP)
│       │   ├── profile_constants.dart       # Cloneable settings list
│       │   ├── firmware_util.dart           # Firmware updates
│       │   ├── zpl_sanitizer.dart           # Injection prevention
│       ├── graphics/
│       │   ├── grf_encoder.dart             # PNG/JPEG to GRF
│       │   ├── z64_compressor.dart          # Deflate+base64 compression
│       │   └── graphics_util.dart
│       ├── models/
│       │   ├── printer_object.dart          # File/dir entry
│       │   ├── storage_info.dart            # Drive space info
│       │   ├── field_description.dart       # Label field metadata
│       │   ├── printer_status.dart          # Status data (media, temp)
│       │   ├── printer_alert.dart           # Alert config
│       │   ├── printer_profile.dart         # ZIP profile structure
│       │   ├── link_os_version.dart         # Firmware version
│       │   ├── zpl_print_mode.dart          # Speed/darkness enum
│       │   └── ...
│       └── exceptions/
│           └── connection_exception.dart    # Exception hierarchy
├── test/
│   ├── mocks/
│   │   └── mock_connection.dart             # Test double
│   ├── connection/
│   │   └── *.dart                           # Connection tests
│   ├── printer/
│   │   └── *.dart                           # Printer tests
│   ├── graphics/
│   │   └── *.dart                           # Graphics tests
│   └── discovery/
│       └── *.dart                           # Discovery tests
├── pubspec.yaml                             # Dependencies
├── CLAUDE.md                                # Architecture guide
├── README.md                                # User guide
└── docs/
    ├── system-architecture.md               # Layered design
    ├── development-roadmap.md               # Milestones & phases
    ├── project-changelog.md                 # Version history
    └── code-standards.md                    # Style & patterns
```

## Public API (lib/flutter_zpl_printer.dart)

### Exceptions
- `ConnectionException` — Base connection error
- `ConnectionClosedException` — Connection offline
- `ConnectionTimeoutException` — Operation timeout
- `ReconnectSuccessException` — Reconnect signaling

### Connection Layer
- `Connection` — Abstract transport
- `TcpConnection` — TCP/socket (port 9100/6101)
- `BleConnection` — Bluetooth LE
- `MultichannelTcpConnection` — Dual TCP ports
- `MultichannelBleConnection` — Dual BLE characteristics
- `ReconnectableConnection` — Auto-reconnect wrapper
- `ResponseValidators` — Validator factory methods
- `ConnectionConfig` — Timeout/chunk tuning

### Discovery
- `NetworkDiscovery` — TCP discovery (broadcast, multicast, probe)
- `BleDiscovery` — BLE scan
- `DiscoveryService` — Unified discovery stream
- `DiscoveredPrinter` — Search result model

### Printer Operations
- `ZebraPrinter` — High-level API (main entry point)
- `ZebraPrinterLinkOs` — Extension with firmware/profile/font/alert methods
- `Sgd` — Set-Get-Do protocol (static)
- `FileUtil` — File operations (static)
- `FormatUtil` — Stored format management (static)
- `FontUtil` — Font download (static)
- `AlertUtil` — Alert configuration (static)
- `ProfileUtil` — Backup/restore (static)
- `FirmwareUtil` — Firmware updates (static)
- `GraphicsUtil` — GRF/image operations (static)
- `ZplSanitizer` — Input validation (static)

### Graphics
- `GrfEncoder` — PNG/JPEG to monochrome GRF
- `Z64Compressor` — Deflate+base64 compression
- `GraphicsUtil` — High-level image operations

### Models
- `PrinterStatus` — Parsed ~HS response
- `PrinterLanguage` — ZPL / CPCL / unknown
- `DiscoveredPrinter` — Discovery result
- `PrinterObject` — File/directory entry
- `StorageInfo` — Drive space
- `FieldDescription` — Label field metadata
- `PrinterAlert` — Alert config
- `PrinterProfile` — ZIP backup structure
- `LinkOsVersion` — Firmware version
- `ZplPrintMode` — Speed/darkness
- `ConnectionType` — TCP / BLE enum

## Core Layers

### 1. Connection Layer (lib/src/connection/)

**Responsibility:** Transport abstraction for read/write operations.

**Key Classes:**
- `Connection` (abstract)
  - `open()`, `close()`, `isConnected`
  - `write(Uint8List)` — Chunked write
  - `sendAndWaitForResponse(data, endOfResponseMarker?)` — Simple marker-based
  - `sendAndWaitForValidResponse(data, validator)` — Predicate-based
  - `waitForData(timeoutMs)`, `bytesAvailable()`, `read()`

- `TcpConnection` — `dart:io` Socket
  - Constructor: `TcpConnection(address, port, config)`
  - Implements all Connection abstract methods
  - Line-based read (reads until socket closes or no more bytes)

- `BleConnection` — `universal_ble` package
  - Constructor: `BleConnection(deviceId, writeCharacteristic, readCharacteristic, config)`
  - Subscribes to notifications on read characteristic
  - Queues writes to write characteristic

- `MultichannelTcpConnection` — Composition of two TcpConnection
  - Constructor: `MultichannelTcpConnection(printAddress, statusAddress, config)`
  - Routes setvar/do → port 9100
  - Routes getvar → port 9200
  - Overrides `sendAndWaitFor*` for intelligent routing

- `MultichannelBleConnection` — Composition of two BLE characteristic pairs
  - Analogous to MultichannelTcpConnection but uses BLE

- `ReconnectableConnection` — Decorator wrapping any Connection
  - Constructor: `ReconnectableConnection(innerConnection, config)`
  - Catches `ConnectionClosedException`
  - Exponential backoff: 250ms → 500ms → 1000ms → 2000ms
  - Throws `ReconnectSuccessException` on successful reconnect (caller retries)

- `ResponseValidators` — Factory methods
  - `sgd()` — SGD response (quoted value or prompt)
  - `json()` — Complete JSON object/array
  - `status()` — ~HS with 3 ETX-delimited lines
  - `multiline(n)` — N complete lines
  - `endsWith(String)` — Custom marker

**Configuration (ConnectionConfig):**
- `maxChunkSize` — Split writes (default 512)
- `interChunkDelayMs` — Delay between chunks (default 0)
- `maxTimeoutForRead` — Initial wait (default 5000ms)
- `timeToWaitForMoreData` — Between polls (default 1000ms)

**Design Patterns:**
- Chunked write matches Link-OS SDK behavior
- Dual timeouts (initial + per-poll) prevent infinite hangs
- ResponseValidator examined in real-time (not timeout-based)
- Composition (Multichannel, Reconnectable) over inheritance

**Testing:**
- `MockConnection` records writes, queues responses
- Supports `simulateDisconnect()`, `failOpenCount`
- All tests use MockConnection (no real hardware in CI)

---

### 2. Discovery Layer (lib/src/discovery/)

**Responsibility:** Finding Zebra printers on network and BLE.

**Key Classes:**
- `DiscoveryService` (main entry point)
  - `discoverAll(types, timeout)` — Merged stream from TCP + BLE
  - Deduplicates by address
  - Returns `Stream<DiscoveredPrinter>`

- `NetworkDiscovery`
  - `discover(timeout)` — UDP broadcast, directed, multicast, TCP probe
  - Returns `Stream<DiscoveredPrinter>`
  - Methods: broadcast to 255.255.255.255:4201, subnet scan (TCP probe)

- `BleDiscovery`
  - `discover(timeout)` — BLE scan via `universal_ble`
  - Filters by Zebra service UUID (`38eb4a80...`)
  - Returns `Stream<DiscoveredPrinter>`

- `DiscoveredPrinter` (model)
  - `address` — IP or device ID
  - `name` — Friendly name
  - `model` — Printer model (e.g., "ZT411")
  - `connectionType` — TCP or BLE
  - Factory: `DiscoveredPrinter.fromTcp()`, `fromBle()`

**Design:**
- Stream-based; non-blocking
- Unified interface masks transport differences
- Deduplication prevents duplicate connections

---

### 3. Printer Layer (lib/src/printer/)

**Responsibility:** High-level printer operations and SGD protocol.

**Main Classes:**

**ZebraPrinter** (facade)
- Constructor: `ZebraPrinter(Connection connection)`
- Factory: `ZebraPrinter.connect(Connection)` — opens and detects language
- Methods:
  - `getStatus()` → PrinterStatus (delegates to PrinterStatus.query)
  - `getLanguage()` → PrinterLanguage (SGD `device.languages`)
  - `getSetting(name)` → String (delegates to Sgd)
  - `setSetting(name, value)` → void (delegates to Sgd)
  - `doCommand(name, value)` → String (delegates to Sgd)
  - `printZpl(String)`, `sendCommand(String)` — raw ZPL
  - Convenience methods: `calibrate()`, `reset()`, `printConfigurationLabel()`, etc.
  - Link-OS operations via extension (firmware, profile, font, alert)

**ZebraPrinterLinkOs** (extension)
- Adds Link-OS and enterprise methods to ZebraPrinter:
  - `getLinkOsVersion()` → LinkOsVersion? (null if not Link-OS)
  - `downloadTtfFont(data, path)` — Store TrueType
  - `downloadTteFont(data, path)` — Store Embedded TrueType
  - `configureAlerts(alerts)` — Set alerts
  - `getConfiguredAlerts()` → List<PrinterAlert>
  - `removeAlerts(alerts)` — Delete specific alerts
  - `removeAllAlerts()` — Clear all alerts
  - `printStoredFormatWithVarGraphics(path, vars)` — Print with substitution
  - `createProfile(onProgress)` → Uint8List (ZIP)
  - `createBackup()` → Uint8List (alias)
  - `loadProfile(zipData, fileDeletionOption)` → Future<void>
  - `loadBackup(zipData)` → Future<void> (alias)
  - `getCurrentFirmwareVersion()` → String
  - `updateFirmware(fwBytes, firmwareName, onProgress)` → bool
  - `updateFirmwareUnconditionally(fwBytes, onProgress)` → void

**Sgd** (static utility)
- SGD protocol implementation
- Methods:
  - `get(setting, connection)` → String
  - `set(setting, value, connection)` → void
  - `doCommand(action, value, connection)` → String
- Format: `! U1 getvar/setvar/do "$setting" "$value"\r\n`
- Auto-strips quotes from responses

**FileUtil** (static utility)
- File operations on E: and R: drives
- Methods:
  - `listFiles(connection, drive)` → List<PrinterObject>
  - `getFile(connection, path)` → Uint8List
  - `deleteFile(connection, path)` → void
  - `uploadFile(connection, path, data, onProgress)` → void
  - `ftpUploadFile()`, `ftpDownloadFile()` — Stubbed (enterprise only)

**FormatUtil** (static utility)
- Stored label format management
- Methods:
  - `storeFormat(connection, path, zpl)` → void (~DF)
  - `listFormats(connection, drive)` → List<PrinterObject>
  - `deleteFormat(connection, path)` → void (~DD)
  - `printFormat()` — Multiple overloads (~XF / ^XF)

**GraphicsUtil** (static utility)
- GRF and image operations
- Methods:
  - `printImage(connection, imageBytes, x, y, width, height)` → void (^GF)
  - `storeGraphics(connection, imageBytes, path, compress)` → void (~DG)
  - `recallStoredGraphics(connection, path, x, y)` → void (^XG)

**FontUtil** (static utility)
- Font management (Link-OS only)
- Methods:
  - `downloadTtfFont(connection, data, printerPath)` → void
  - `downloadTteFont(connection, data, printerPath)` → void
- Throws if not Link-OS printer

**AlertUtil** (static utility)
- Printer alert/notification configuration
- Methods:
  - `configureAlerts(connection, alerts)` → void
  - `getConfiguredAlerts(connection)` → List<PrinterAlert>
  - `removeAlerts(connection, alerts)` → void
  - `removeAllAlerts(connection)` → void

**ProfileUtil** (static utility)
- Backup/restore configuration (ZIP-based)
- Methods:
  - `createProfile(connection, onProgress)` → Uint8List (ZIP)
  - `createBackup()` — Alias for createProfile
  - `loadProfile(connection, zipData, fileDeletionOption)` → void
  - `loadBackup()` — Alias for loadProfile
- ZIP structure: `settings.json`, `alerts.json`, cloneable files
- Supports FileDeletionOption: all, cloneable, none

**ProfileConstants** (static data)
- Curated list of ~100 cloneable SGD settings
- Used by ProfileUtil for backup
- Covers language, display, network, security, media, print settings

**FirmwareUtil** (static utility)
- Firmware update operations (Link-OS only)
- Methods:
  - `getCurrentFirmwareVersion(connection)` → String (SGD `appl.name`)
  - `updateFirmware(connection, fwBytes, firmwareName, onProgress)` → bool
  - `updateFirmwareUnconditionally(connection, fwBytes, onProgress)` → void
- Returns true if firmware was sent, false if version already matches
- **Warning:** Printer reboots after upload; connection is lost

**PrinterStatus** (model + utility)
- Parsed `~HS` response
- Fields: `mediaStatus`, `headTemp`, `nativeLanguage`, `errors`, `alerts`, etc.
- Factory: `PrinterStatus.query(connection)` — Issues ~HS and parses response
- Computed property: `isReady` (media status OK, no errors)

**PrinterLanguage** (enum)
- ZPL, CPCL, unknown
- Factory: `PrinterLanguage.fromString(String)`

**ZplSanitizer** (static utility)
- Input validation against injection
- Methods:
  - `validateFieldData(String)` — Throws if contains `^` or `~`
  - `validatePath(String)` — Throws if suspicious path

**Design Patterns:**
- Static utilities (Sgd, FileUtil, etc.) take Connection parameter
- ZebraPrinter aggregates utilities; provides convenience wrappers
- Extension adds Link-OS features without bloating core
- SGD command format strictly follows protocol spec
- Progress callbacks for long operations (file download, firmware upload)

---

### 4. Graphics Layer (lib/src/graphics/)

**Responsibility:** Image encoding and compression for GRF format.

**Key Classes:**

**GrfEncoder** (static utility)
- PNG/JPEG to monochrome GRF conversion
- Methods:
  - `encodeImage(Uint8List imageBytes)` → String (hex GRF)
  - `encodeImage()` — Supports dithering, threshold modes
- Process: Decode (image pkg) → Monochrome → Compress → Hex encode
- Output ready for `^GF` ZPL command

**Z64Compressor** (static utility)
- Deflate + base64 + CRC16 compression
- Methods:
  - `compress(Uint8List bitmapBytes)` → Uint8List (compressed)
  - `decompress(Uint8List compressed)` → Uint8List (original)
- Reduces payload for bandwidth-constrained links (BLE)
- Printer decompresses automatically with `~DU` prefix

**GraphicsUtil** (static utility)
- High-level image operations
- Methods:
  - `printImage(connection, imageBytes, x, y, width, height)` → void
  - `storeGraphics(connection, imageBytes, path, compress)` → void
  - `recallStoredGraphics(connection, path, x, y)` → void

**Design:**
- GrfEncoder is format-agnostic; handles PNG, JPEG, GIF
- Z64Compressor is optional; called explicitly
- GraphicsUtil provides convenient wrappers

---

### 5. Models Layer (lib/src/models/)

Data classes representing printer state and configuration.

**PrinterStatus**
- Fields: mediaStatus, headTemp, nativeLanguage, errors, alerts
- Parsed from `~HS` response

**PrinterLanguage**
- Enum: zpl, cpcl, unknown

**PrinterObject**
- File/directory entry: name, size, type, created

**StorageInfo**
- Drive space: drive, freeBytes, totalBytes

**FieldDescription**
- Label field: name, type, defaultValue, maxLength

**PrinterAlert**
- Alert config: type, action, priority

**PrinterProfile**
- Backup structure: settings Map, alerts List, files Map

**LinkOsVersion**
- Parsed firmware: major, minor, patch, rawString

**ZplPrintMode**
- Speed/darkness: speed (0-12), darkness (0-30)

**DiscoveredPrinter**
- Search result: address, name, model, connectionType

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | SDK | Flutter framework |
| universal_ble | ^1.2.0 | BLE transport |
| image | ^4.8.0 | PNG/JPEG decoding |
| archive | ^4.0.0 | ZIP profile handling |
| mocktail | ^1.0.0 | (dev) Test mocking |
| flutter_lints | ^6.0.0 | (dev) Linting |

## Testing Strategy

**Approach:** Unit tests with MockConnection; no real hardware in CI.

**Test Structure:**
```
test/
├── mocks/mock_connection.dart
├── connection/
│   ├── tcp_connection_test.dart
│   ├── ble_connection_test.dart
│   ├── multichannel_tcp_connection_test.dart
│   ├── reconnectable_connection_test.dart
│   └── response_validators_test.dart
├── printer/
│   ├── sgd_test.dart
│   ├── file_util_test.dart
│   ├── format_util_test.dart
│   ├── profile_util_test.dart
│   ├── firmware_util_test.dart
│   ├── alert_util_test.dart
│   ├── font_util_test.dart
│   ├── printer_status_test.dart
│   └── zebra_printer_test.dart
├── graphics/
│   ├── grf_encoder_test.dart
│   ├── z64_compressor_test.dart
│   └── graphics_util_test.dart
└── discovery/
    ├── network_discovery_test.dart
    └── ble_discovery_test.dart
```

**MockConnection Features:**
- Records written bytes
- Queues responses
- Simulates disconnects
- Tracks call counts

**Coverage:** ~85% (all core paths; discovery/BLE limited to construction checks)

---

## Zebra BLE Characteristics

**Service UUID:** `38eb4a80-c54c-4b7b-a5e0-4a49d1053280`

**Standard Characteristics:**
| Purpose | Write UUID | Read UUID |
|---------|-----------|-----------|
| Print | 38eb4a82... | 38eb4a81... |
| Status | 38eb4a84... | 38eb4a83... |

Stored in `bluetooth_constants.dart`.

---

## Common Usage Patterns

### Connect and Print
```dart
final conn = TcpConnection(address: '192.168.1.100', port: 9100);
final printer = await ZebraPrinter.connect(conn);
await printer.printZpl('^XA^FO10,10^A0N,50,50^FDHello^FS^XZ');
await conn.close();
```

### Query Status
```dart
final status = await PrinterStatus.query(conn);
print(status.mediaStatus); // 'ready', 'out_of_media', etc.
print(status.headTemp);    // Temperature in °C
```

### Discover Printers
```dart
final discovery = DiscoveryService.discoverAll(timeout: Duration(seconds: 10));
await for (final found in discovery) {
  print('${found.name} at ${found.address}');
}
```

### BLE Connection
```dart
final ble = BleConnection(
  deviceId: 'printer-id',
  writeCharacteristic: '38eb4a82-...',
  readCharacteristic: '38eb4a81-...',
);
final printer = await ZebraPrinter.connect(ble);
```

### Auto-Reconnect
```dart
final reliable = ReconnectableConnection(conn);
try {
  await reliable.sendAndWaitForResponse(cmd);
} on ReconnectSuccessException {
  // Reconnected; retry the command
}
```

### Profile Backup
```dart
final zipBytes = await printer.createProfile(
  onProgress: (status) => print('Backup: $status'),
);
// Save zipBytes to file
```

### Firmware Update
```dart
final fwBytes = await File('firmware.bin').readAsBytes();
final updated = await printer.updateFirmware(
  fwBytes,
  firmwareName: 'V80.19',
  onProgress: (sent, total) => print('$sent / $total'),
);
// WARNING: Printer reboots after upload
```

---

## File Size & Organization

All Dart files kept ≤200 lines for optimal context management.

**Largest files (~150-180 lines):**
- `zebra_printer.dart` — Main API
- `file_util.dart` — File operations
- `format_util.dart` — Format management
- `profile_util.dart` — Profile backup/restore
- `connection.dart` — Abstract base + core methods

**Smallest files (~30-50 lines):**
- `printer_language.dart`, `printer_alert.dart`, etc. — Models
- `response_validators.dart` — Factory methods
- `zpl_sanitizer.dart` — Validation

This modular structure supports parallel development and easier testing.

---

## Key Architectural Decisions

1. **Transport Agnosticism:** All operations take `Connection`; swappable TCP/BLE/multichannel
2. **Composition Over Inheritance:** Multichannel and Reconnectable wrap connections
3. **Static Utilities:** Protocol logic organized as static classes (not ZebraPrinter methods)
4. **ResponseValidator Pattern:** Predicate-based response detection (not timeout-based)
5. **Extension for Link-OS:** Keeps base ZebraPrinter focused; Link-OS features opt-in
6. **ZIP for Profiles:** Self-contained backup with settings, alerts, and files
7. **Mock-Based Testing:** All tests use MockConnection (no hardware dependency)

---

## Next Steps

See `development-roadmap.md` for planned features and milestones.

**High Priority:**
- Firmware update UX polish
- ProfileUtil robustness improvements
- Better error messages and debugging

**Medium Priority:**
- Graphics enhancements (color, batch upload)
- Format field definition querying
- Performance optimization (pooling, streaming)

