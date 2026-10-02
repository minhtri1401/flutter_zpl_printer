## 0.2.0

**Build and print with one import.** `flutter_zpl_printer` now depends on and re-exports
[`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator).

### Breaking

- **`ZplPrintMode` is now `PrinterPrintMode`** (file `printer_print_mode.dart`). It's the print mode the
  printer reports in `getStatus().printMode`. The rename frees the name for `flutter_zpl_generator`'s
  `ZplPrintMode`, the mode you set in a label's configuration. Migration: rename the type in your code.
  If you imported the generator with a prefix only to avoid this clash, you can drop the prefix.

### Added

- `ZebraPrinter.printLabel(ZplGenerator label)`: builds and sends a label.
- Everything from `flutter_zpl_generator` is available through
  `package:flutter_zpl_printer/flutter_zpl_printer.dart` (`ZplGenerator`, `ZplText`, `ZplBarcode`,
  `ZplImageDownload`, ...).

### Changed

- **`ZebraPrinter.printImage` uses `flutter_zpl_generator`**: a `~DG` download (uncompressed hex) before
  `^XA`, then `^XG` to place it. That's the image path tested on hardware. New optional parameters:
  `dithering` (default threshold) and `graphicName` (default `IMG`).
- `GraphicsUtil.printImage` (low-level inline `^GF`) defaults to `useCompression: false`; Z64 is opt-in
  and not yet verified on a printer.

### Fixed

- **Z64 checksum.** `Z64Compressor` now computes CRC-16/XMODEM over the Base64 text, as Zebra's
  ZPL II Programming Guide specifies ("calculated over the :encoded_data field"). It was computed
  over the raw bitmap with CRC-16/CCITT-FALSE. Matches `flutter_zpl_generator`'s implementation.
  `Z64Compressor.crc16` now returns the XMODEM value and accepts any `List<int>`.

### Documentation

- README opens with a direct answer and adds an **FAQ** (Link-OS SDK, iOS without MFi, supported
  printers, images and PDFs, status, USB, web) and a comparison with other Zebra packages.
- pub.dev **Example** tab now shows `example/example.md` (usage snippets) instead of the app shell.
- Library-level API docs with a quick start; `context7.json` for coding-agent documentation indexes.
- pub.dev topics: `labels` replaces `usb` (USB is experimental).

### Example

- New **Print image** section: prints a generated test picture via `printImage`, via
  `printLabel(ZplGenerator(...))`, and via `GraphicsUtil.printImage` (`^GF`, hex and Z64) for comparison.
- The example no longer depends on `flutter_zpl_generator` directly.

## 0.1.1

### Documentation

- **Print images with [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator).**
  The README and guide now show the tested path: build the label with `ZplImageDownload` +
  `ZplImageRecall` and send it with `printZpl`.
- **Known issue documented: Z64 checksum.** `printImage` / `GraphicsUtil.printImage` compress with Z64
  by default and compute the CRC over the raw bitmap instead of the Base64 data, as Zebra's manual
  specifies, so a printer that checks it can drop the image. Use `flutter_zpl_generator`, or pass
  `useCompression: false`. Bluetooth LE / Wi-Fi printing and `printZpl` are not affected.

## 0.1.0

**Breaking: full rewrite.** The plugin no longer wraps Zebra's Link-OS SDK. It now
ships a pure-Dart protocol stack (SGD, ZPL `~HS` status, Zebra BLE GATT, USB
printer class) with small native shims only where the OS requires them (USB
enumeration and permissions). You no longer need to copy proprietary
`libZSDK_API.a` / `ZSDK_ANDROID_API.jar` binaries into the plugin.

### Added

- **Three transports, one `Connection` API**
  - Bluetooth LE: `BleConnection`, `MultichannelBleConnection` (print + status channels).
  - Wi-Fi / Ethernet: `TcpConnection` (9100 ZPL, 6101 CPCL), `MultichannelTcpConnection` (9100 + 9200).
  - USB (**experimental**, not yet confirmed working on any platform): `UsbConnection`, `UsbDeviceAddress`
    for macOS, Windows, and Android, backed by libusb 1.0.29.
  - `ReconnectableConnection` decorator with exponential backoff.
- **Discovery**: `DiscoveryService.discoverAll()` merges USB, UDP broadcast/multicast, and BLE.
  Each transport is also available on its own (`UsbDiscovery`, `NetworkDiscovery`, `BleDiscovery`),
  as is TCP subnet search. `UsbHotplugStream.events()` reports plug/unplug events.
- **`ZebraPrinter` high-level API**: `printZpl`, `getStatus`, `getSetting` / `setSetting` / `doCommand`,
  `calibrate`, `printConfigurationLabel`, `getMetadata`, `printImage`, file and format storage, and more.
- **Utilities**: `Sgd`, `FileUtil`, `FormatUtil`, `FontUtil`, `AlertUtil`, `ProfileUtil`, `FirmwareUtil`,
  `GraphicsUtil` (GRF / Z64 image encoding), `ZplSanitizer`.
- **Typed errors**: `ConnectionException` plus 11 USB-specific subclasses (`UsbPermissionDeniedException`,
  `UsbDeviceBusyException` with a `remediation` hint, and others).
- **`PrinterSgdKey`**: a catalog of verified Zebra SGD keys, grouped by category.
- **Test support**: `package:flutter_zpl_printer/flutter_zpl_printer_testing.dart` exports `FakeUsbPlatform`.
- **New platforms**: macOS and Windows.
- **[Integration guide](GUIDE.md)** based on a production app.

### Removed

The 0.0.1 API is gone. Migration:

| 0.0.1 | 0.1.0 |
| :--- | :--- |
| `FlutterZplPrinter().startDiscovery()` + `onPrinterFound` | `DiscoveryService.discoverAll()` (a `Stream<DiscoveredPrinter>`) |
| `connect(address, ConnectionType.bluetooth)` | `ZebraPrinter.connect(BleConnection(deviceId))` |
| `connect(address, ConnectionType.wifi)` | `ZebraPrinter.connect(TcpConnection.zpl(ip))` |
| `printZpl(zpl)` | `printer.printZpl(zpl)` |
| `getStatus()` | `printer.getStatus()` |
| `getSettings()` | `printer.getSetting('allcv')` (raw text), or `printer.getMetadata()` |
| `disconnect()` | `printer.disconnect()` |

Classic Bluetooth (iOS MFi / Android SPP) is not supported in 0.1.0. Use Bluetooth LE, which Zebra
printers with Bluetooth 4.0 or later support.

### Platform status

Tested on hardware with Zebra printers:

| Transport | iOS | macOS | Windows | Android |
| :--- | :---: | :---: | :---: | :---: |
| Bluetooth LE | ✅ | ✅ | ✅ | ✅ |
| Wi-Fi / TCP | ✅ | ✅ | ✅ | ✅ |
| USB | not possible (no USB host on iOS) | not tested | ❌ fails in testing | not tested |

### Known issues

- **Windows USB failed when tested with Zebra printers; the cause is not confirmed yet.**
  `libusb-1.0.dll` is not bundled, printers bound to the ZDesigner/`usbprint` driver can't be
  claimed, and the open path assumes fixed endpoints. Plug/unplug events are not emitted on Windows.
  Bluetooth LE and Wi-Fi work on Windows. Details and workarounds:
  [Known issues → Windows USB](https://github.com/minhtri1401/flutter_zpl_printer#windows-usb).
  Please report results on the [issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).
- **Android USB** needs `libusb-1.0.so` built per ABI. The package does not ship it yet,
  so Android USB calls fail with `UsbLibLoadException`.

## 0.0.1

* Initial release.
* Printer discovery via Bluetooth MFi and Wi-Fi.
* Connect/disconnect to Zebra ZPL printers.
* Raw ZPL payload printing.
* Printer hardware status queries.
* Retrieve all printer settings (`getSettings`).
* Cross-platform error codes for structured error handling.
