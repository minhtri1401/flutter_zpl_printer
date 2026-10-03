# flutter_zpl_printer

[![pub package](https://img.shields.io/pub/v/flutter_zpl_printer.svg)](https://pub.dev/packages/flutter_zpl_printer)

`flutter_zpl_printer` is a Flutter plugin for Zebra label printers. It finds printers, connects over
Bluetooth LE, Wi-Fi, or USB, sends ZPL, and reads printer status, all in Dart. It runs on
iOS, Android, macOS, and Windows, and needs neither Zebra's Link-OS SDK nor Apple MFi approval.

It talks to the printer using Zebra's native protocols (SGD, `~HS` host status, the Zebra BLE GATT
service), so your app ships no proprietary binaries. Labels are built with
[`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator), which is included:

```dart
final printer = await ZebraPrinter.connect(TcpConnection.zpl('192.168.1.50'));
await printer.printLabel(ZplGenerator(commands: [
  ZplText(x: 40, y: 40, text: 'Hello from Flutter'),
  ZplBarcode(x: 40, y: 100, data: '123456789', height: 80),
]));
```

The [integration guide](GUIDE.md) covers transport fallback, auto-reconnect, settings, error
handling, and troubleshooting, based on a production app.

> **Upgrading from 0.1.x?** The only breaking change is the rename of `ZplPrintMode` (the print mode
> read from status) to `PrinterPrintMode`. See the [changelog](CHANGELOG.md#020).

## Platform support

| Transport | iOS | macOS | Windows | Android |
| :--- | :---: | :---: | :---: | :---: |
| Bluetooth LE | ✅ | ✅ | ✅ | ✅ |
| Wi-Fi / TCP | ✅ | ✅ | ✅ | ✅ |
| USB | ➖ | ⚪ | ❌ | ⚪ |

✅ prints on real hardware · ❌ fails in hardware testing · ⚪ code exists, not tested on hardware · ➖ not possible on the platform

USB is experimental and hasn't been confirmed working on any platform. Use Bluetooth LE or Wi-Fi in
production. Details per platform are in [the guide](GUIDE.md#5-usb-what-works-today).

## Installation

```yaml
dependencies:
  flutter_zpl_printer: ^0.2.1
```

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart'; // also exports flutter_zpl_generator
```

### Platform setup

<details>
<summary><b>iOS</b>: <code>ios/Runner/Info.plist</code></summary>

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to Zebra printers over Bluetooth.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Used to discover Zebra printers on your local network.</string>
```

Requires iOS 13.1 or later (from `universal_ble`).
</details>

<details>
<summary><b>macOS</b>: entitlements and <code>Info.plist</code></summary>

`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>   <!-- needed to receive UDP discovery replies -->
<key>com.apple.security.device.bluetooth</key>
<true/>
<key>com.apple.security.device.usb</key>
<true/>
```

`macos/Runner/Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to Zebra printers over Bluetooth.</string>
```
</details>

<details>
<summary><b>Android</b>: <code>AndroidManifest.xml</code></summary>

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

Request the Bluetooth permissions at runtime (for example with `permission_handler`) before scanning.
</details>

<details>
<summary><b>Windows</b></summary>

Bluetooth LE and Wi-Fi need no setup. USB fails in testing so far; see [the guide](GUIDE.md#windows-what-the-code-does-and-what-might-be-wrong).
</details>

## Quick start

```dart
// 1. Find printers: USB, UDP broadcast/multicast, and BLE, merged and de-duplicated.
final found = await DiscoveryService.discoverAll().first;

// 2. Connect. createConnection() picks BleConnection, TcpConnection, or UsbConnection.
final printer = await ZebraPrinter.connect(found.createConnection());

// 3. Check status before printing so you can tell the user what's wrong.
final status = await printer.getStatus();
if (status.isPaperOut) return showError('Load labels');
if (status.isHeadOpen) return showError('Close the print head');

// 4. Print raw ZPL, or a label built in Dart.
try {
  await printer.printZpl('^XA^FO50,50^A0N,40,40^FDHello Zebra^FS^XZ');
  await printer.printLabel(ZplGenerator(
    config: const ZplConfiguration(printWidth: 406),
    commands: [
      ZplText(x: 40, y: 40, text: 'Order #1042'),
      ZplBarcode(x: 40, y: 100, data: '1042', height: 80),
    ],
  ));
} on ConnectionException catch (e) {
  showError(e.message); // every transport throws ConnectionException or a subclass
}

// Images: downloaded to printer memory (~DG) and recalled (^XG).
await printer.printImage(pngBytes, targetWidth: 400);

await printer.disconnect();
```

To connect without discovery, build the connection yourself:

```dart
TcpConnection.zpl('192.168.1.50');                              // Wi-Fi, port 9100
BleConnection(deviceId);                                        // Bluetooth LE
UsbConnection(UsbDeviceAddress.parse('usb://0A5F:0027/SERIAL')); // USB (experimental)
```

The [example app](example/lib/main.dart) runs all three transports end to end.

## Features

- Connections: `BleConnection`, `TcpConnection`, `UsbConnection`; `MultichannelBleConnection` and
  `MultichannelTcpConnection` with separate print and status channels; `ReconnectableConnection` for
  [auto-reconnect](GUIDE.md#bluetooth-auto-reconnect-optional) with exponential backoff.
- Discovery: UDP broadcast, directed broadcast, multicast, TCP subnet search, BLE scan, USB
  enumeration and hot-plug events. See [Discover printers](GUIDE.md#3-discover-printers).
- Status: `~HS` parsed into `isReadyToPrint`, `isPaperOut`, `isHeadOpen`, `isRibbonOut`, `isPaused`,
  `isHeadTooHot`, labels remaining, and more.
- Settings (SGD): get, set, and do commands, with verified keys in `PrinterSgdKey`. See
  [Settings and actions](GUIDE.md#7-settings-and-actions-sgd).
- Labels and images: the full `flutter_zpl_generator` API (text, barcodes, QR codes, images, templates)
  through `printLabel` and `printImage`. See [Images](GUIDE.md#images).
- Files and formats: list, store, and delete files on `E:` / `R:`; print stored formats with field data.
- Utilities: `FontUtil`, `AlertUtil`, `ProfileUtil` (backup and restore), `FirmwareUtil`, `ZplSanitizer`.
- Testing: fakes in `flutter_zpl_printer_testing.dart`. See [Test without a printer](GUIDE.md#10-test-without-a-printer).

## FAQ

### How do I print to a Zebra printer from Flutter?

Connect with `ZebraPrinter.connect()` over Bluetooth LE (`BleConnection`), Wi-Fi (`TcpConnection.zpl(ip)`),
or USB (`UsbConnection`). Then send ZPL with `printZpl`, or a label built in Dart with
`printLabel(ZplGenerator(...))`. Call `getStatus()` first so you can tell the user why a job won't print.

### Do I need Zebra's Link-OS SDK?

No. The package implements the printer protocols in Dart. There is no SDK to download, no
`libZSDK_API.a` or `ZSDK_ANDROID_API.jar` to copy into your app, and no native SDK version to keep in sync.

### Does it work on iOS without Apple MFi approval?

Yes, over Bluetooth LE and Wi-Fi. MFi (External Accessory) applies to Classic Bluetooth, which this
package doesn't support. Bluetooth LE goes through CoreBluetooth, which doesn't require the MFi program.

### Which Zebra printers work?

ZPL printers. Over Wi-Fi or Ethernet, any Zebra printer that accepts raw ZPL on port 9100. Over
Bluetooth, Link-OS printers with Bluetooth LE. Testing so far used Link-OS printers, including the ZQ620
mobile printer. CPCL printers accept raw CPCL over `TcpConnection.cpcl(ip)` (port 6101), but status
parsing is ZPL only.

### How do I print an image or a PDF?

For an image, call `printer.printImage(pngBytes, targetWidth: width)`. For a PDF, render each page to an
image with a PDF rasterizer such as `pdfx`, then print each page with `printImage`. The
[guide](GUIDE.md#images) explains the print settings that work on mobile printers.

### How do I know if the printer is out of paper or the head is open?

Call `getStatus()`. It parses Zebra's `~HS` host status into `isReadyToPrint`, `isPaperOut`,
`isHeadOpen`, `isRibbonOut`, `isPaused`, `isHeadTooHot`, and other fields.

### Does USB work?

Not yet. USB hasn't been confirmed working on any platform: it is untested on macOS and Android, fails on Windows in testing, and isn't possible
on iOS. Use Bluetooth LE or Wi-Fi in production. The [guide](GUIDE.md#5-usb-what-works-today) has the
details, and reports from your hardware are welcome.

### Does it work on Flutter web or Linux?

No. The package uses `dart:io` sockets and `dart:ffi`, which the web doesn't have, and Linux isn't
implemented. `flutter_zpl_generator` (included) builds labels on every platform, including web.

### How does it compare to other Zebra packages?

From each package's pub.dev page and repository, checked on 2026-10-02. Packages are listed by usage,
most-used first; check them for newer releases.

| Package | Approach | Platforms (pub.dev) | Transports |
| :--- | :--- | :--- | :--- |
| **flutter_zpl_printer** | Pure Dart, no Zebra SDK | Android, iOS, macOS, Windows | Bluetooth LE, Wi-Fi, USB (experimental) |
| [`zsdk`](https://pub.dev/packages/zsdk) | Zebra Link-OS SDK | Android, iOS | TCP/IP, ZPL and PDF (per its description) |
| [`zebrautil`](https://pub.dev/packages/zebrautil) ([zebra_printer_utility](https://github.com/anthonyR012/zebra_printer_utility)) | Zebra Link-OS SDK (bundles `ZSDK_ANDROID_API.jar`) | Android, iOS | Bluetooth and Wi-Fi on Android, Bluetooth on iOS (per its README) |
| [`zebrautility`](https://pub.dev/packages/zebrautility) | Zebra Link-OS SDK (bundles `ZSDK_ANDROID_API.jar`) | Android, iOS | Bluetooth and Wi-Fi on Android, Bluetooth on iOS (per its README) |
| [`zebra_printer`](https://pub.dev/packages/zebra_printer) | Zebra Link-OS SDK | Android | Bluetooth, network (per its description) |
| [`zebra_printer_cpcl`](https://pub.dev/packages/zebra_printer_cpcl) | Zebra Link-OS SDK | Android | Bluetooth, network, CPCL and ZPL (per its description) |
| [`zebra_usb_printer`](https://pub.dev/packages/zebra_usb_printer) | Android USB | Android | USB (per its description) |

The SDK-based packages are more widely used, and are a reasonable choice if you need a feature only
Zebra's SDK provides. Choose this package for iOS Bluetooth LE without MFi, macOS and Windows support,
or an app with no proprietary binaries.

## Known issues

- USB is experimental. It fails on Windows, and Android needs a `libusb-1.0.so` you build yourself.
  See [USB: what works today](GUIDE.md#5-usb-what-works-today).
- `GraphicsUtil.printImage` (inline `^GF`) hasn't been verified on a printer. On 0.1.0 and 0.1.1 its Z64
  checksum was wrong. `printer.printImage` doesn't use it. See the note under [Images](GUIDE.md#images).
- Classic Bluetooth (iOS MFi, Android SPP) isn't supported. Use Bluetooth LE.
- Status parsing targets ZPL. CPCL printers connect and print, but status objects are ZPL-specific.
- TLS isn't supported. TCP connections are plaintext.

Report problems, including your printer model and the exception text, on the
[issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

## Contributing

Issues and pull requests are welcome at
[github.com/minhtri1401/flutter_zpl_printer](https://github.com/minhtri1401/flutter_zpl_printer).

This package is not affiliated with or endorsed by Zebra Technologies. Zebra, Link-OS, and ZPL are
trademarks of Zebra Technologies Corp.

## License

MIT. The bundled libusb 1.0.29 is LGPL-2.1-or-later (see `third_party/libusb/1.0.29/LICENSE`).
