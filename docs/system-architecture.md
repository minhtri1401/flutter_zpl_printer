# System Architecture

## Overview

`flutter_zpl_printer` is a layered, transport-agnostic library for controlling Zebra label printers. Built directly on Zebra's native printer protocols (SGD, ZPL, BLE), it provides a clean Dart API without depending on the official Link-OS SDK.

```
┌──────────────────────────────────┐
│      Application Code             │
│  (import 'package:flutter_zpl_printer/flutter_zpl_printer') │
└──────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  High-Level Printer API           │
│  ZebraPrinter (+ LinkOs ext.)    │
│  Static utilities: Sgd, FileUtil,│
│  FormatUtil, GraphicsUtil, etc.  │
└──────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  Connection Layer                 │
│  Connection (abstract)            │
│  TcpConnection | BleConnection   │
│  Multichannel | Reconnectable    │
└──────────────────────────────────┘
           ↓
┌──────────────────────────────────┐
│  Transport (TCP/BLE/Serial)      │
└──────────────────────────────────┘
```

## Connection Layer

### Connection (Abstract Base)

The `Connection` abstract class is the transport-agnostic interface that all printer operations use.

**Key Methods:**
- `open()` — Initialize the transport connection
- `close()` — Tear down the connection
- `write(Uint8List)` — Send data with automatic chunking (default 512 bytes/chunk)
- `sendAndWaitForResponse()` — Send and wait for data (marker-based)
- `sendAndWaitForValidResponse()` — Send and wait using a custom validator

**Chunking:** Large payloads are split by `config.maxChunkSize` (default 512 bytes) with optional `config.interChunkDelayMs` delay between chunks. Matches Link-OS SDK `ConnectionA` behavior.

**Response Waiting:** All `sendAndWaitFor*` methods use dual timeouts to prevent hangs:
- `initialTimeout` (default 5000ms) — time to receive first byte
- `readTimeout` (default 1000ms) — time to receive additional bytes (per poll)
- Outer deadline prevents infinite reads when printer trickles data

### TcpConnection

Direct socket connection via `dart:io` to a printer's TCP ports.

- **Port 9100** — ZPL print commands
- **Port 6101** — CPCL commands (if supported)

```dart
final conn = TcpConnection(address: '192.168.1.100', port: 9100);
await conn.open();
await conn.write(Uint8List.fromList(utf8.encode('^XA...')));
await conn.close();
```

### BleConnection

Bluetooth Low Energy via `universal_ble` package. Parameterized by characteristic UUIDs.

**Zebra BLE Service UUIDs:**
- Advertisement service: `0000fe79-0000-1000-8000-00805f9b34fb`
- Data service: `38eb4a80-c54c-4b7b-a5e0-4a49d1053280`

**Standard Characteristics:**
- Print pair: write `38eb4a82`, read `38eb4a81` (with notifications)
- Status pair: write `38eb4a84`, read `38eb4a83` (with notifications)

```dart
final conn = BleConnection(
  deviceId: 'printer-device-id',
  writeCharacteristic: '38eb4a82-c54c-4b7b-a5e0-4a49d1053280',
  readCharacteristic: '38eb4a81-c54c-4b7b-a5e0-4a49d1053280',
);
```

### MultichannelTcpConnection

Composes two `TcpConnection` instances (port 9100 for print, port 9200 for status) into a single connection.

Routes operations intelligently:
- **Print commands** (ZPL, SGD `setvar`) → port 9100
- **Status queries** (SGD `getvar`, `~HS`) → port 9200

Reduces network round-trips by running queries in parallel.

```dart
final conn = MultichannelTcpConnection(
  printAddress: '192.168.1.100',
  statusAddress: '192.168.1.100',
);
```

### MultichannelBleConnection

Analogous to `MultichannelTcpConnection` but uses BLE characteristics:
- Print pair: `38eb4a82` (write), `38eb4a81` (read)
- Status pair: `38eb4a84` (write), `38eb4a83` (read)

### ReconnectableConnection

Decorator that wraps any `Connection`. Handles disconnections with exponential backoff.

**Behavior:**
- Detects `ConnectionClosedException`
- Attempts reconnect with backoff: 250ms → 500ms → 1000ms → 2000ms (max)
- Throws `ReconnectSuccessException` on successful reconnect (signals caller to retry)
- Never auto-retries — caller must catch and re-issue command

```dart
final base = TcpConnection(address: '192.168.1.100', port: 9100);
final reliable = ReconnectableConnection(base);
try {
  await reliable.sendAndWaitForResponse(cmd);
} on ReconnectSuccessException {
  // Reconnected; retry the command
}
```

### ResponseValidators

Factory methods returning `ResponseValidator` predicates (`bool Function(Uint8List)`). Used by `sendAndWaitForValidResponse()` to detect response completeness without timeouts.

```dart
// SGD response validator: looks for printer prompt or quoted value
final validator = ResponseValidators.sgd();

// JSON response validator: complete JSON object/array
final jsonValidator = ResponseValidators.json();

// Status response validator: ~HS with all 3 ETX-delimited lines
final statusValidator = ResponseValidators.status();

// Multiline validator: N complete lines
final multiValidator = ResponseValidators.multiline(3);

// Custom validator: ends with specific string
final endValidator = ResponseValidators.endsWith('OK\r\n');
```

## Printer Layer

### ZebraPrinter

High-level API for printer operations. Delegates to static utility classes.

```dart
final conn = TcpConnection(address: '192.168.1.100', port: 9100);
final printer = await ZebraPrinter.connect(conn);

// Status, language detection
final status = await printer.getStatus();
final lang = await printer.getLanguage(); // ZPL or CPCL

// SGD operations
final deviceId = await printer.getSetting('device.friendly_name');
await printer.setSetting('device.friendly_name', 'Printer-Lab');
await printer.doCommand('device.reset', '');

// Print operations
await printer.printZpl('^XA^FO10,10^A0N,50,50^FDHello^FS^XZ');
await printer.calibrate();
await printer.printConfigurationLabel();
```

### ZebraPrinterLinkOs Extension

Adds Link-OS and enterprise features to `ZebraPrinter`.

```dart
// Link-OS version check
final version = await printer.getLinkOsVersion(); // null if not Link-OS

// Font management
await printer.downloadTtfFont(fontBytes, 'E:\\CustomFont.ttf');
await printer.downloadTteFont(tteBytes, 'E:\\EmbedFont.tte');

// Alerting
final alerts = await printer.getConfiguredAlerts();
await printer.configureAlerts([PrinterAlert(...), ...]);

// Profile management
final profileZip = await printer.createProfile();
await printer.createBackup('E:\\Backup\\config.zip');

// Firmware updates
final currentVersion = await printer.getCurrentFirmwareVersion();
final wasUpdated = await printer.updateFirmware(
  firmwareBytes,
  firmwareName: 'V80.19.ZPL',
  onProgress: (sent, total) => print('$sent / $total'),
);
```

### Static Utility Classes

Each operates on a `Connection` parameter and provides static methods:

**Sgd** — Set-Get-Do protocol
- `get(setting, connection)` — Query a setting via `! U1 getvar`
- `set(setting, value, connection)` — Update a setting via `! U1 setvar`
- `doCommand(action, value, connection)` — Execute action via `! U1 do`

**FileUtil** — File operations (E:, R: drives)
- `listFiles(connection, drive)` — Directory listing
- `getFile(connection, path)` — Download file
- `deleteFile(connection, path)` — Delete file
- `uploadFile(connection, path, data)` — Upload file
- `ftpUploadFile()` / `ftpDownloadFile()` — FTP variants (enterprise)

**FormatUtil** — Format label management
- `storeFormat(connection, path, zpl)` — Save format to printer storage
- `listFormats(connection, drive)` — List stored formats
- `deleteFormat(connection, path)` — Remove format
- `printFormat()` — Print stored format (various overloads)

**GraphicsUtil** — Image and GRF handling
- `printImage()` — Inline GRF in label
- `storeGraphics()` — Save GRF to printer storage
- `recallStoredGraphics()` — Recall stored GRF

**FontUtil** — Font operations (Link-OS only)
- `downloadTtfFont(connection, data, path)` — Store TrueType font
- `downloadTteFont(connection, data, path)` — Store Embedded TrueType

**AlertUtil** — Printer alerts/notifications
- `getConfiguredAlerts(connection)` — Query current alerts
- `configureAlerts(connection, alerts)` — Set alerts
- `removeAlerts(connection, alerts)` — Remove specific alerts
- `removeAllAlerts(connection)` — Clear all alerts

**ProfileUtil** — Backup/restore configuration
- `createProfile(connection, onProgress)` — Snapshot settings, alerts, files → ZIP
- `createBackup()` — Alias for `createProfile()`
- `loadProfile(connection, zipData, options)` — Restore configuration from ZIP
- `loadBackup()` — Alias for `loadProfile()`

**FirmwareUtil** — Firmware updates (Link-OS only)
- `getCurrentFirmwareVersion(connection)` — Query version
- `updateFirmware()` — Conditional update (checks version first)
- `updateFirmwareUnconditionally()` — Force update

**Warning:** After firmware upload, printer reboots and connection is lost. Use `ReconnectableConnection` for auto-recovery.

### PrinterStatus

Parses `~HS` response into structured data.

```dart
final status = await PrinterStatus.query(connection);
print(status.mediaStatus); // 'ready', 'out_of_media', etc.
print(status.headTemp); // Temperature in Celsius
print(status.isReady); // Computed property
```

### ZplSanitizer

Validates ZPL field data and paths against injection attacks.

```dart
// Check field data for caret (^) or tilde (~) injection
ZplSanitizer.validateFieldData('user_input'); // throws if unsafe

// Check paths in file operations
ZplSanitizer.validatePath('E:\\Format.zpl'); // throws if suspicious
```

## Discovery Layer

### NetworkDiscovery

UDP-based discovery for TCP printers on the local network.

Methods:
1. Broadcast to 255.255.255.255:4201
2. Directed broadcast to subnet
3. Multicast to 224.0.1.55:4201
4. TCP probe on discovered IPs (port 9100)

Returns stream of `DiscoveredPrinter` (address, name, model, connection type).

### BleDiscovery

BLE scan using `universal_ble` package.

Scans for devices advertising the Zebra service UUID and returns `DiscoveredPrinter` with BLE device ID.

### DiscoveryService

Unified discovery combining TCP and BLE.

```dart
final printers = DiscoveryService.discoverAll(
  types: {ConnectionType.tcp, ConnectionType.ble},
  timeout: Duration(seconds: 10),
);

await for (final printer in printers) {
  print('Found: ${printer.name} at ${printer.address}');
  // Connect to discovered printer
}
```

## Graphics Layer

### GrfEncoder

Converts PNG/JPEG images to monochrome bitmap GRF format (^GF command data).

**Process:**
1. Decode image via `image` package
2. Convert to monochrome (dithering or threshold)
3. Compress with optional Z64 compression
4. Encode as hex GRF data

```dart
final imageFile = File('label.png');
final imageBytes = await imageFile.readAsBytes();
final grfHex = await GrfEncoder.encodeImage(imageBytes);
// grfHex ready for ^GF command
```

### Z64Compressor

Compresses GRF bitmap data using Deflate + base64 + CRC16.

Reduces label size when bandwidth is constrained (e.g., BLE).

```dart
final compressed = Z64Compressor.compress(bitmapBytes);
// Smaller payload; printer decompresses automatically with ~DU
```

### GraphicsUtil

High-level image operations.

```dart
// Inline image in label (^GF command)
await GraphicsUtil.printImage(
  connection,
  imageBytes,
  x: 10,
  y: 10,
  width: 200,
  height: 300,
);

// Store image on printer (E: drive)
await GraphicsUtil.storeGraphics(
  connection,
  imageBytes,
  path: 'E:\\Images\\logo.grf',
);

// Recall stored image in label
await GraphicsUtil.recallStoredGraphics(
  connection,
  path: 'E:\\Images\\logo.grf',
  x: 50,
  y: 50,
);
```

## Key Architectural Patterns

### Composition Over Inheritance

Multichannel and reconnectable connections wrap inner connections rather than subclass them. This allows flexible composition: a `ReconnectableConnection` wrapping a `MultichannelTcpConnection` wrapping two `TcpConnection` instances, for example.

### ResponseValidator Pattern

Instead of relying on timeouts, use predicate validators to detect complete responses:

```dart
final response = await connection.sendAndWaitForValidResponse(
  command,
  validator: ResponseValidators.sgd(),
);
```

Validators examine accumulated bytes in real-time, reducing timeout-related flakiness.

### Static Utility Classes

Printer operations are organized as static utility classes (Sgd, FileUtil, etc.) rather than methods on `ZebraPrinter`. This:
- Keeps `ZebraPrinter` focused on API aggregation
- Allows independent testing of each protocol
- Matches the original Link-OS SDK organization

### Transport Agnosticism

All operations take an abstract `Connection` parameter. Swap TCP for BLE or multichannel without changing business logic.

## Models & Types

**DiscoveredPrinter** — Search result (address, friendly name, model, connection type)

**PrinterStatus** — Parsed status response (media status, temperature, errors, alerts)

**PrinterLanguage** — Enum: `zpl` or `cpcl`

**PrinterProfile** — Structured representation of stored configuration (settings, alerts, files)

**PrinterAlert** — Notification configuration (type, action, priority)

**LinkOsVersion** — Parsed firmware version with major/minor/patch

**ZplPrintMode** — Print speed and darkness settings

**StorageInfo** — Free/used space on E:, R: drives

**FieldDescription** — Label field metadata (name, type, default value)

**PrinterObject** — File/directory entry (name, size, type)

---

## Quick Reference: Common Patterns

**Open connection, query status, close:**
```dart
final conn = TcpConnection(address: '192.168.1.100', port: 9100);
await conn.open();
final status = await PrinterStatus.query(conn);
await conn.close();
```

**Auto-reconnect with fallback:**
```dart
final base = TcpConnection(address: '192.168.1.100', port: 9100);
final reliable = ReconnectableConnection(base);

try {
  await reliable.sendAndWaitForResponse(cmd);
} on ReconnectSuccessException {
  // Reconnected; retry the command
}
```

**Multichannel (dual port) connection:**
```dart
final conn = MultichannelTcpConnection(
  printAddress: '192.168.1.100',
  statusAddress: '192.168.1.100',
);
await conn.open();
// Queries automatically route to port 9200; prints to port 9100
```

**Discover and connect:**
```dart
final printers = DiscoveryService.discoverAll(
  types: {ConnectionType.tcp},
  timeout: Duration(seconds: 10),
);

await for (final found in printers) {
  final conn = TcpConnection(
    address: found.address,
    port: 9100,
  );
  final printer = await ZebraPrinter.connect(conn);
  print(await printer.getStatus());
  break;
}
```

**Print image in label:**
```dart
final imageBytes = await File('logo.png').readAsBytes();
final grfHex = await GrfEncoder.encodeImage(imageBytes);
final zpl = '^XA^FO10,10^GF${grfHex}^FS^XZ';
await printer.printZpl(zpl);
```

