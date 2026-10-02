# flutter_zpl_printer

[![pub package](https://img.shields.io/pub/v/flutter_zpl_printer.svg)](https://pub.dev/packages/flutter_zpl_printer)

Discover, connect to, and print on Zebra ZPL label printers from Flutter over
**Bluetooth LE**, **Wi-Fi / TCP**, and **USB**.

The plugin talks to the printer in Zebra's own protocols (SGD, ZPL `~HS` status,
Zebra BLE GATT services, USB printer class) from Dart. It does not depend on the
Link-OS SDK, so there are no proprietary binaries to download or copy.

It pairs well with [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator)
for building the ZPL you send.

> **Upgrading from 0.0.1?** 0.1.0 is a full rewrite with a new API.
> See the [migration table in the changelog](CHANGELOG.md#removed).

---

## Platform support

| Transport | iOS | macOS | Windows | Android |
| :--- | :---: | :---: | :---: | :---: |
| Bluetooth LE | ✅ | ✅ | ✅ | ⚪ not tested |
| Wi-Fi / TCP | ✅ | ✅ | ✅ | ⚪ not tested |
| USB | ➖ not available | ✅ | ⚠️ [known issue](#windows-usb) | ⚪ [needs libusb build](#android-usb) |

✅ tested on hardware · ⚠️ known issue · ⚪ implemented, not verified on hardware · ➖ platform limitation

iOS gives apps no USB host access to printers, so `UsbHostApi.isSupported()` returns
`false` there and USB calls throw `UsbUnsupportedOnPlatformException`.

---

## Installation

```yaml
dependencies:
  flutter_zpl_printer: ^0.1.0
```

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
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

The [example app](example/lib/main.dart) shows all three transports end to end.

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
- **Graphics**: convert PNG/JPEG to GRF or compressed Z64 and print or store it (`GraphicsUtil`).
- **More utilities**: `FontUtil`, `AlertUtil`, `ProfileUtil` (backup / restore), `FirmwareUtil`, `ZplSanitizer`.

### SGD example

```dart
final darkness = await Sgd.get(PrinterSgdKey.printToneZpl.value, connection);
await Sgd.set('device.friendly_name', 'Warehouse-01', connection);
await Sgd.doCommand('device.reset', '', connection);
```

### USB details

USB is part of `DiscoveryService.discoverAll()` by default. Machines without libusb just return no USB results.

```dart
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

## Known issues

### Windows USB

**Status:** USB printing on Windows is not working reliably in 0.1.0. Bluetooth LE and Wi-Fi work on
Windows; macOS USB is unaffected. If you hit this, please add your printer model, Windows version, and
the exception text to the [issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

What to check:

1. **Is `libusb-1.0.dll` next to your `.exe`?** The Windows build copies it from
   `third_party/libusb/1.0.29/windows/<x64|arm64>/libusb-1.0.dll`. 0.1.0 does not ship that DLL yet.
   Without it the build prints the CMake warning `libusb-1.0.dll not found` and USB calls fail with
   `UsbLibLoadException`. Workaround: download the official
   [libusb 1.0.29 Windows binaries](https://github.com/libusb/libusb/releases/tag/v1.0.29) and put
   `VS2022/MS64/dll/libusb-1.0.dll` next to your app's executable (or run `tool/fetch_libusb.sh`
   in a checkout of this package).
2. **Which driver owns the printer?** If Zebra Setup Utilities or the ZDesigner driver is installed,
   Windows binds the printer to `usbprint` and libusb cannot claim it. You get
   `UsbDeviceBusyException`; show its `remediation` text to the user. Workaround: rebind the device to
   WinUSB with [Zadig](https://zadig.akeo.ie/). After that, the Windows print spooler can no longer use
   the printer.
3. **Fallback:** print over Wi-Fi or Bluetooth LE on Windows until this is fixed.

### Android USB

Android USB needs `libusb-1.0.so` built per ABI with the NDK. 0.1.0 does not ship those binaries,
so Android USB calls fail with `UsbLibLoadException`. See `tool/fetch_libusb.sh`.

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
