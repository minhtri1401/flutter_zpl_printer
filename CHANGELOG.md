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
