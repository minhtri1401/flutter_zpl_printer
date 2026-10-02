# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`flutter_zpl_printer` is a pure-Dart Flutter library for Zebra label printers. It speaks Zebra's native printer protocols (SGD, ZPL, BLE characteristics) without depending on the official Link-OS SDK. Supports TCP, BLE, multichannel connections, and auto-reconnect.

Protocol reference material lives at `libs/ZSDK_src/com/zebra/sdk/` and is the primary reference for protocol behavior.

## Commands

```bash
# Analyze (lint)
fvm flutter analyze

# Run all tests
fvm flutter test

# Run a single test file
fvm flutter test test/printer/sgd_test.dart

# Get dependencies
fvm flutter pub get
```

All commands use `fvm` (Flutter Version Manager). The project targets Dart SDK ^3.10.0.

## Architecture

Single import: `import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';` (barrel file at `lib/flutter_zpl_printer.dart`).

### Layers

**Connection** (`lib/src/connection/`) — Transport-agnostic base with concrete implementations:
- `Connection` — Abstract base with chunked write, `sendAndWaitForResponse`, `sendAndWaitForValidResponse`. All printer operations go through this.
- `TcpConnection` — `dart:io` Socket (port 9100 ZPL, 6101 CPCL)
- `BleConnection` — `universal_ble` package. Parameterized with read/write characteristic UUIDs.
- `MultichannelTcpConnection` — Composition of two `TcpConnection` (port 9100 print, 9200 status). Overrides `sendAndWaitFor*` to route through status channel.
- `ReconnectableConnection` — Decorator wrapping any `Connection`. Exponential backoff reconnect. Throws `ReconnectSuccessException` after reconnect (never auto-retries).
- `ResponseValidators` — Factory methods returning `ResponseValidator` (`bool Function(Uint8List)`): `sgd()`, `json()`, `status()`, `multiline()`, `endsWith()`.

**Discovery** (`lib/src/discovery/`) — Printer finding:
- `NetworkDiscovery` — UDP broadcast (255.255.255.255:4201), directed broadcast, multicast (224.0.1.55), subnet search (TCP probe)
- `BleDiscovery` — BLE scan via `universal_ble`
- `DiscoveryService` — Merges TCP + BLE streams

**Printer** (`lib/src/printer/`) — High-level operations:
- `ZebraPrinter` — Main API. Delegates to `Sgd`, `FileUtil`, `FormatUtil`, `GraphicsUtil`, `FontUtil`, `AlertUtil`.
- `Sgd` — Set/Get/Do protocol. Commands: `! U1 getvar/setvar/do "setting" "value"\r\n`. Responses wrapped in quotes.
- `PrinterStatus` — Parses `~HS` response (3 ETX-separated lines, comma-separated fields).
- `ZplSanitizer` — Validates paths/field data against `^` and `~` injection.

**Graphics** (`lib/src/graphics/`) — Image conversion:
- `GrfEncoder` — PNG/JPEG → monochrome bitmap → hex GRF. Uses `image` package.
- `Z64Compressor` — Deflate + base64 + CRC16 compression for GRF data.
- `GraphicsUtil` — `^GF` (inline print), `~DG` (store), `^XG` (recall stored).

### Key Patterns

- **Composition over inheritance**: Multichannel and reconnectable connections wrap inner connections, not subclass them.
- **Static utility classes**: `Sgd`, `FileUtil`, `FormatUtil`, `GraphicsUtil`, `FontUtil`, `AlertUtil` — all static methods taking `Connection`.
- `ZebraPrinter` provides convenience wrappers that delegate to these utilities.
- **ResponseValidator**: `bool Function(Uint8List)` typedef. Used by `sendAndWaitForValidResponse` to detect response completeness without relying on timeouts.

### Zebra BLE Characteristics

Service `0000fe79-...` (advertisement) / `38eb4a80-...` (data):
- Print pair: write `38eb4a82`, read/notify `38eb4a81`
- Status pair: write `38eb4a84`, read/notify `38eb4a83`

Constants in `bluetooth_constants.dart`.

## Testing

Tests use `MockConnection` (`test/mocks/mock_connection.dart`) — records written bytes, returns queued responses. Supports disconnect simulation (`simulateDisconnect()`, `failOpenCount`).

BLE and network discovery tests are limited to construction/structural checks (no hardware in CI).

## Dependencies

- `universal_ble` — BLE transport
- `image` — PNG/JPEG decoding for GRF conversion
- `mocktail` — Test mocking (dev)