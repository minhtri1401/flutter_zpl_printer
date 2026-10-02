# flutter_zpl_printer

[![pub package](https://img.shields.io/pub/v/flutter_zpl_printer.svg)](https://pub.dev/packages/flutter_zpl_printer)

`flutter_zpl_printer` is a Flutter plugin for printing to Zebra label printers. It finds printers and
connects over **Bluetooth LE**, **Wi-Fi** (TCP port 9100), or **USB**, sends ZPL, and reads printer
status, all in Dart. It runs on iOS, Android, macOS, and Windows, without Zebra's Link-OS SDK or Apple
MFi approval.

The plugin speaks Zebra's own protocols (SGD, ZPL `~HS` status, Zebra BLE GATT services, USB printer
class) directly, so there are no proprietary binaries to download or copy. Bluetooth LE and Wi-Fi are
tested on real printers on all four platforms; USB is [experimental](#platform-support).

**Build and print with one import.** The package includes
[`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator), so you can lay out text,
barcodes, QR codes, and images and send them in one call:

```dart
await printer.printLabel(ZplGenerator(commands: [
  ZplText(x: 40, y: 40, text: 'Hello from Flutter'),
  ZplBarcode(x: 40, y: 100, data: '123456789', height: 80),
]));
```

> **Upgrading?** From 0.1.x to 0.2.0, the only breaking change is that `ZplPrintMode` (the print mode read
> from the printer's status) is now `PrinterPrintMode`; see the [changelog](CHANGELOG.md#020).
> From 0.0.1, 0.1.0 was a full rewrite; see the [migration table](CHANGELOG.md#removed).

📘 **[Integration guide](GUIDE.md)**: availability checks, discovery, transport fallback, printing,
settings, error handling, and troubleshooting, based on a production app.

---

## Platform support

| Transport | iOS | macOS | Windows | Android |
| :--- | :---: | :---: | :---: | :---: |
| Bluetooth LE | ✅ | ✅ | ✅ | ✅ |
| Wi-Fi / TCP | ✅ | ✅ | ✅ | ✅ |
| USB | ➖ not possible | ⚪ not tested | ❌ [fails in testing](#windows-usb) | ⚪ [not tested, libusb not bundled](#android-usb) |

✅ works in hardware testing · ❌ fails in hardware testing · ⚪ code exists, not verified on hardware · ➖ platform limitation

**USB, in short: experimental. It hasn't been confirmed working on any platform yet.** It is
untested on macOS and Android, it fails on Windows in our testing (cause not confirmed yet), and
iOS doesn't allow it (USB calls throw `UsbUnsupportedOnPlatformException`). Use Bluetooth LE or
Wi-Fi for production printing.

---

## Installation

```yaml
dependencies:
  flutter_zpl_printer: ^0.2.0
```

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart'; // includes flutter_zpl_generator
```

You don't need to add `flutter_zpl_generator` yourself. If your app already imports it, nothing breaks:
both imports provide the same classes. The analyzer will flag the generator import as unnecessary, so
you can remove it.

### Platform setup

<details>
<summary><b>iOS</b>: <code>ios/Runner/Info.plist</code></summary>

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to connect to Zebra printers over Bluetooth.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Used to discover Zebra printers on your local network.</string>
```

`universal_ble` (the BLE dependency) requires iOS 13.1 or later.
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

The libusb dylib is bundled through the plugin's podspec. Nothing else to install.
</details>

<details>
<summary><b>Windows</b></summary>

Bluetooth LE and Wi-Fi need no extra setup. For USB, read [Known issues → Windows USB](#windows-usb) first.
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

Request Bluetooth permissions at runtime (for example with `permission_handler`) before scanning.
</details>

---

## Quick start

### 1. Find a printer

```dart
// USB + UDP broadcast/multicast + BLE, merged and de-duplicated.
await for (final printer in DiscoveryService.discoverAll()) {
  print('${printer.connectionType.displayName}: ${printer.friendlyName} @ ${printer.address}');
}
```

Or one transport at a time:

```dart
BleDiscovery.discoverZebra(timeout: const Duration(seconds: 10)); // Bluetooth LE
NetworkDiscovery.discover();                                       // UDP broadcast on port 4201
UsbDiscovery.enumerate();                                          // attached USB printers
```

### 2. Connect

```dart
// From a discovery result: picks the right Connection type for you.
final printer = await ZebraPrinter.connect(discovered.createConnection());

// Or build a connection yourself:
final ble = BleConnection(deviceId);                                     // Bluetooth LE
final tcp = TcpConnection.zpl('192.168.1.50');                           // Wi-Fi, port 9100
final usb = UsbConnection(UsbDeviceAddress.parse('usb://0A5F:0027/XXSERIAL')); // USB
```

### 3. Print and query

```dart
final status = await printer.getStatus();
if (status.isReadyToPrint) {
  await printer.printZpl('^XA^FO50,50^A0N,40,40^FDHello Zebra^FS^XZ');
} else if (status.isHeadOpen) {
  print('Close the print head');
} else if (status.isPaperOut) {
  print('Load labels');
}

// Or build the label in Dart (flutter_zpl_generator, included):
await printer.printLabel(ZplGenerator(
  config: const ZplConfiguration(printWidth: 406),
  commands: [
    ZplText(x: 40, y: 40, text: 'Order #1042'),
    ZplBarcode(x: 40, y: 100, data: '1042', height: 80),
  ],
));

final model = await printer.getSetting(PrinterSgdKey.deviceProductName.value);
final firmware = await printer.getSetting(PrinterSgdKey.applName.value);

await printer.calibrate();
await printer.printConfigurationLabel();

await printer.disconnect();
```

### 4. Handle errors

Every transport throws `ConnectionException` or a subclass:

```dart
try {
  await printer.printZpl(zpl);
} on UsbDeviceBusyException catch (e) {
  showError(e.remediation ?? e.message); // tells the user how to fix it
} on ConnectionException catch (e) {
  showError(e.message);
}
```

### 5. Print images

```dart
await printer.printImage(pngBytes, x: 0, y: 0, targetWidth: 400);
```

`printImage` builds the label with `flutter_zpl_generator`: the image is downloaded to printer memory with
`~DG` (uncompressed hex, which every Zebra printer accepts) before `^XA`, then placed with `^XG`. That's the
image path tested on real printers, and the one Link-OS mobile printers need. It uses threshold dithering
by default: zPrint found that Floyd-Steinberg's dense dot coverage can trip the print head's thermal
protection on a ZQ620.

For full control (label width, print mode, image plus text), build the label yourself:

```dart
final raw = await printer.getSetting(PrinterSgdKey.ezplPrintWidth.value);
final width = int.tryParse(raw.trim()) ?? 384; // dots; 384 = 2-inch 203 dpi

await printer.printLabel(ZplGenerator(
  config: ZplConfiguration(printWidth: width, printMode: ZplPrintMode.tearOff),
  autoLabelLengthFromFirstImage: true, // label length = image height
  commands: [
    ZplImageDownload(image: pngBytes, targetWidth: width, ditheringAlgorithm: ZplDitheringAlgorithm.threshold),
    const ZplImageRecall(), // x: 0, y: 0, graphicName: 'IMG'
  ],
));
```

The [example app](example/lib/main.dart) shows all three transports end to end. The
[integration guide](GUIDE.md) covers the production details.

---

## Features

- **Connections**: `BleConnection`, `TcpConnection`, `UsbConnection`, plus `MultichannelBleConnection` /
  `MultichannelTcpConnection` (separate print and status channels) and `ReconnectableConnection`
  (auto-reconnect with exponential backoff).
- **Discovery**: UDP broadcast, directed broadcast, multicast, TCP subnet search, BLE scan, USB enumeration,
  and USB hot-plug events (`UsbHotplugStream.events()`).
- **Status**: full `~HS` parsing (`isReadyToPrint`, `isPaperOut`, `isHeadOpen`, `isRibbonOut`, `isPaused`,
  `isHeadTooHot`, labels remaining, and more).
- **SGD (Set/Get/Do)**: `Sgd.get`, `Sgd.set`, `Sgd.doCommand`, and a catalog of verified keys in `PrinterSgdKey`.
- **Files and formats**: list, store, and delete files on `E:` / `R:`; store formats and print them with
  `^FN` field data (`FormatUtil.printStoredFormat`).
- **Labels**: `printLabel(ZplGenerator)` and the full [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator)
  API (text, barcodes, QR, images, fonts, templates), included and re-exported.
- **Images**: `printImage` (built with `flutter_zpl_generator`). Lower level: `GraphicsUtil` converts PNG/JPEG to
  GRF and prints with `^GF` or stores with `~DG` ([status](#image-compression-z64)).
- **More utilities**: `FontUtil`, `AlertUtil`, `ProfileUtil` (backup / restore), `FirmwareUtil`, `ZplSanitizer`.

### SGD example

```dart
final darkness = await Sgd.get(PrinterSgdKey.headDarknessSwitch.value, connection);
await Sgd.set(PrinterSgdKey.deviceFriendlyName.value, 'Warehouse-01', connection);

// Sgd.doCommand waits for a reply. Actions like device.reset never send one,
// so write those directly:
await connection.write(Uint8List.fromList(utf8.encode('! U1 do "device.reset" ""\r\n')));
```

### USB details

Check the [platform table](#platform-support) first. USB is part of `DiscoveryService.discoverAll()`
by default, and USB failures there are swallowed, so other transports keep working.

```dart
// Plug/unplug events: macOS and Android. Not emitted on Windows yet.
UsbHotplugStream.events().listen((e) => print('${e.type} → ${e.address}'));

const cfg = ConnectionConfig(
  usbBulkTimeoutMs: 8000, // default 5000
  usbMaxChunkSize: 0,     // 0 = use the endpoint's wMaxPacketSize
  usbStallRetries: 3,
);
final conn = UsbConnection(address, config: cfg);
```

libusb 1.0.29 is bundled under `third_party/libusb/` and linked dynamically
(LGPL-2.1-or-later; see `third_party/libusb/1.0.29/LICENSE`).

### Testing your app

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer_testing.dart';

final fake = FakeUsbPlatform()..devices.add(UsbDeviceRecord(
  vendorId: 0x0A5F, productId: 0x0027, path: '/fake', hasPermission: true,
  serialNumber: 'XX1', interfaceNumber: 0, bulkInEndpoint: 0x81, bulkOutEndpoint: 0x01,
));
final conn = UsbConnection.withPlatform(UsbDeviceAddress.parse('usb://0A5F:0027/XX1'), fake);
```

---

## FAQ

### How do I print to a Zebra printer from Flutter?

Connect with `ZebraPrinter.connect(...)` over Bluetooth LE (`BleConnection`), Wi-Fi (`TcpConnection.zpl(ip)`),
or USB (`UsbConnection`), then send ZPL with `printZpl` or a typed label with `printLabel(ZplGenerator(...))`.
Check `getStatus()` first so you can tell the user why a job won't print. See [Quick start](#quick-start).

### Do I need Zebra's Link-OS SDK?

No. This package implements the printer protocols in Dart, so there is no SDK to download, no
`libZSDK_API.a` or `ZSDK_ANDROID_API.jar` to copy, and no native SDK version to keep in sync.

### Does it work on iOS without Apple MFi approval?

Yes, over Bluetooth LE and Wi-Fi. MFi (External Accessory) applies to Classic Bluetooth. Bluetooth LE goes
through CoreBluetooth, which needs no MFi program. Classic Bluetooth is not supported by this package.

### Which Zebra printers work?

ZPL printers. Over Wi-Fi or Ethernet, any Zebra printer that accepts raw ZPL on port 9100. Over Bluetooth,
Link-OS printers with Bluetooth LE (Bluetooth 4.0 or later). Testing so far used Link-OS printers, including a
ZQ620 mobile printer. CPCL printers can receive raw CPCL over `TcpConnection.cpcl(ip)` (port 6101), but status
parsing is ZPL-only.

### How do I print an image or a PDF?

For an image, call `printer.printImage(pngBytes, targetWidth: width)`. For a PDF, render each page to an
image first (for example with a PDF rasterizer such as `pdfx`), then print each page with `printImage`.
See [Print images](#5-print-images).

### How do I know if the printer is out of paper or the head is open?

Call `getStatus()`. It parses Zebra's `~HS` host status into `isReadyToPrint`, `isPaperOut`, `isHeadOpen`,
`isRibbonOut`, `isPaused`, `isHeadTooHot`, and more.

### Does USB work?

USB is experimental. It hasn't been confirmed working on any platform yet: untested on macOS and Android,
failing on Windows in testing, and not possible on iOS. Use Bluetooth LE or Wi-Fi in production. See
[Known issues](#known-issues).

### Does it work on Flutter web or Linux?

No. The package uses `dart:io` (TCP sockets) and `dart:ffi` (USB), which aren't available on the web, and
Linux isn't implemented.
[`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator) (included) builds labels on every
platform, including web.

### How does it compare to other Zebra packages?

From each package's pub.dev page and repository on 2026-10-02; the other packages are listed by usage,
most-used first (check them for newer releases):

| Package | Approach | Platforms (pub.dev) | Transports |
| :--- | :--- | :--- | :--- |
| **flutter_zpl_printer** | Pure Dart, no Zebra SDK | Android, iOS, macOS, Windows | Bluetooth LE, Wi-Fi, USB (experimental) |
| [`zsdk`](https://pub.dev/packages/zsdk) | Zebra Link-OS SDK | Android, iOS | TCP/IP, ZPL and PDF (per its description) |
| [`zebrautil`](https://pub.dev/packages/zebrautil) ([zebra_printer_utility](https://github.com/anthonyR012/zebra_printer_utility)) | Zebra Link-OS SDK (bundles `ZSDK_ANDROID_API.jar`) | Android, iOS | Bluetooth and Wi-Fi on Android, Bluetooth on iOS (per its README) |
| [`zebrautility`](https://pub.dev/packages/zebrautility) | Zebra Link-OS SDK (bundles `ZSDK_ANDROID_API.jar`) | Android, iOS | Bluetooth and Wi-Fi on Android, Bluetooth on iOS (per its README) |
| [`zebra_printer`](https://pub.dev/packages/zebra_printer) | Zebra Link-OS SDK | Android | Bluetooth, network (per its description) |
| [`zebra_printer_cpcl`](https://pub.dev/packages/zebra_printer_cpcl) | Zebra Link-OS SDK | Android | Bluetooth, network, CPCL and ZPL (per its description) |
| [`zebra_usb_printer`](https://pub.dev/packages/zebra_usb_printer) | Android USB | Android | USB (per its description) |

The SDK-based packages are more widely used today, and are a reasonable choice if you need a feature only
Zebra's SDK provides.

Choose this package if you want iOS Bluetooth LE without MFi, macOS and Windows support, or no
proprietary binaries in your app.

---

## Known issues

### Windows USB

**Status: USB printing on Windows failed when tested with Zebra printers. The cause is not
confirmed yet.** Bluetooth LE and Wi-Fi work on Windows. Until this is
fixed, treat Windows USB as experimental and offer Wi-Fi or Bluetooth.

What the Windows USB code does in 0.1.0:

- Lists printers with Windows SetupAPI.
- Opens them through libusb (`libusb-1.0.dll`), assuming interface 0, bulk endpoints `0x01` / `0x81`,
  and 64-byte packets. It doesn't read these from the printer yet.
- Does not emit plug/unplug events. `UsbHotplugStream.events()` stays silent on Windows.

Possible causes we're investigating:

1. **`libusb-1.0.dll` is not bundled.** If the build log says `libusb-1.0.dll not found`, opens fail with
   `UsbLibLoadException`. Workaround: put the official
   [libusb 1.0.29](https://github.com/libusb/libusb/releases/tag/v1.0.29) `VS2022/MS64/dll/libusb-1.0.dll`
   next to your app's `.exe`.
2. **The printer is bound to the Windows printer driver.** With Zebra Setup Utilities / ZDesigner installed,
   Windows binds the printer to `usbprint` and libusb can't claim it. You get `UsbDeviceBusyException`;
   show its `remediation` text. Rebinding to WinUSB with [Zadig](https://zadig.akeo.ie/) gives libusb
   access, but then the Windows print queue can't use the printer.
3. **The assumed endpoints don't match the printer.** That would show as a transfer timeout or stall on
   write.

If you try it, please report your printer model, Windows version, the driver shown in Device Manager,
and the exception text on the [issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

### Android USB

Android USB needs `libusb-1.0.so` built per ABI with the NDK. 0.1.0 does not ship those binaries,
so Android USB calls fail with `UsbLibLoadException`. See `tool/fetch_libusb.sh`.

### Image compression (Z64)

**`ZebraPrinter.printImage` is not affected from 0.2.0**: it builds the label with `flutter_zpl_generator`
(uncompressed `~DG`), the path tested on hardware.

The low-level `GraphicsUtil.printImage` (inline `^GF` graphic) has not been verified on a printer yet:

| Version | `printImage` | `GraphicsUtil.printImage` default | Z64 checksum |
| :--- | :--- | :--- | :--- |
| 0.1.0 – 0.1.1 | `^GF`, Z64 | Z64 | ❌ computed over the raw bitmap |
| 0.2.0+ | `flutter_zpl_generator` (`~DG`, hex) | uncompressed hex | ✅ CRC-16/XMODEM over the Base64 text |

Zebra's ZPL II Programming Guide says the Z64 CRC is "calculated over the :encoded_data field" (the
Base64 text) and that "a CRC mismatch is treated as an aborted download". 0.1.0 and 0.1.1 got this wrong;
on those versions pass `useCompression: false` to `GraphicsUtil.printImage`, or upgrade.

The [example app](example/lib/src/printer_page.dart)'s **Print image** section prints the same picture
through every path so you can compare them on your printer. Please share results on the
[issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

### Other limitations

- Classic Bluetooth (iOS MFi, Android SPP) is not supported. Use Bluetooth LE.
- Status parsing targets ZPL. CPCL printers connect and print, but status objects are ZPL-specific.
- TLS connections are not supported. TCP is plaintext.

---

## Contributing

Issues and pull requests are welcome at
[github.com/minhtri1401/flutter_zpl_printer](https://github.com/minhtri1401/flutter_zpl_printer).

This package is not affiliated with or endorsed by Zebra Technologies. Zebra, Link-OS, and ZPL are
trademarks of Zebra Technologies Corp.

## License

MIT for this package. Bundled libusb is LGPL-2.1-or-later.
