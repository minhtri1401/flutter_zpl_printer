# flutter_zpl_printer integration guide

This guide covers how to build a production printing flow with
`flutter_zpl_printer`: checking which transports are usable, discovering
printers, choosing a transport, printing, reading printer state, and handling
failures.

The patterns come from **zPrint**, a shipping label app built on this
library. The library itself has been tested against real Zebra printers on iOS,
Android, macOS, and Windows over Bluetooth LE and Wi-Fi. USB is experimental; see
[section 5](#5-usb-what-works-today).
Where zPrint learned something the hard way (a firmware quirk, a timeout that
was too short), the guide says so.

For installation and per-platform permissions, see the [README](README.md#installation).
For a runnable version of the basics, see the [example app](example/lib/main.dart).

**Contents**

1. [How the pieces fit](#1-how-the-pieces-fit)
2. [Check what's available](#2-check-whats-available)
3. [Discover printers](#3-discover-printers)
4. [Connect](#4-connect)
5. [USB: what works today](#5-usb-what-works-today)
6. [Print and read printer state](#6-print-and-read-printer-state)
7. [Settings and actions (SGD)](#7-settings-and-actions-sgd)
8. [Disconnect cleanly](#8-disconnect-cleanly)
9. [Handle errors](#9-handle-errors)
10. [Test without a printer](#10-test-without-a-printer)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. How the pieces fit

```
DiscoveryService / BleDiscovery / NetworkDiscovery / UsbDiscovery
        │  Stream<DiscoveredPrinter>
        ▼
DiscoveredPrinter.createConnection()  ─or─  BleConnection / TcpConnection / UsbConnection
        │  Connection
        ▼
ZebraPrinter.connect(connection)
        │  ZebraPrinter
        ▼
printZpl · getStatus · getSetting · setSetting · getMetadata · calibrate · ...
```

- A **`Connection`** moves bytes over one transport. Every transport has the same API.
- A **`ZebraPrinter`** wraps a connection and adds printer operations.
- **`Sgd`**, `FileUtil`, `FormatUtil`, `GraphicsUtil`, and the other utilities are static helpers that
  take a `Connection` directly, for when you need more than `ZebraPrinter` offers.

---

## 2. Check what's available

Before scanning, work out which transports can work right now. That decides
what to scan for and what to tell the user ("Turn on Bluetooth" beats an empty list).

### Bluetooth

`flutter_zpl_printer` uses [`universal_ble`](https://pub.dev/packages/universal_ble) for Bluetooth LE.
Ask it for the adapter state:

```dart
import 'package:universal_ble/universal_ble.dart';

final state = await UniversalBle.getBluetoothAvailabilityState();
switch (state) {
  case AvailabilityState.poweredOn:    // ready
  case AvailabilityState.poweredOff:   // ask the user to turn Bluetooth on
  case AvailabilityState.unauthorized: // permission denied: offer openAppSettings()
  case AvailabilityState.unsupported:  // no Bluetooth LE on this device
  case AvailabilityState.unknown:
  case AvailabilityState.resetting:    // transient: treat as "off" and re-check
}

UniversalBle.onAvailabilityChange = (state) { /* update your UI */ };
```

**Permissions.** Only Android needs a runtime request. iOS, macOS, and Windows show the system
prompt the first time Bluetooth is used, as long as the usage strings from the README are in place.

```dart
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureBluetoothPermission() async {
  if (!Platform.isAndroid) return true;
  final s = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location, // needed for scanning on Android 11 and older
  ].request();
  return (s[Permission.bluetoothScan]!.isGranted && s[Permission.bluetoothConnect]!.isGranted) ||
      s[Permission.location]!.isGranted;
}
```

### Wi-Fi

UDP discovery and TCP printing need a local network. zPrint treats Wi-Fi or Ethernet as available
and anything else (cellular only, offline) as unavailable. It checks this with
[`connectivity_plus`](https://pub.dev/packages/connectivity_plus).

### USB

USB code exists for macOS, Windows, and Android, but it is **experimental**: it hasn't been
confirmed working on any platform yet. On iOS it is never available. See
[section 5](#5-usb-what-works-today) before relying on it.

```dart
final usbPossible = Platform.isMacOS || Platform.isWindows || Platform.isAndroid;
```

---

## 3. Discover printers

### All transports at once

Build the transport set from what you found in step 2, then merge the results:

```dart
final transports = <DiscoveryTransport>{
  if (usbAvailable) DiscoveryTransport.usb,
  if (wifiAvailable) DiscoveryTransport.udpBroadcast,
  if (wifiAvailable) DiscoveryTransport.udpMulticast,
  if (bleAvailable) DiscoveryTransport.ble,
};

final sub = DiscoveryService.discoverAll(
  transports: transports,
  timeout: const Duration(seconds: 15),
).listen(onPrinter);
```

`discoverAll` already swallows per-transport failures (no libusb, Wi-Fi off), so one broken
transport never stops the others. zPrint still adds `.handleError(...)` as a second line of
defence.

### One physical printer, several results

The same printer often shows up once per transport, under different names:

| Transport | `name` |
| :--- | :--- |
| BLE | `XXZKN210306204` |
| UDP | `:,.ZBRXXZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24` |

Group results by the Zebra serial embedded in the name, so the user sees one row per printer that
knows every way to reach it:

```dart
final byPrinter = <String, List<DiscoveredPrinter>>{};

void onPrinter(DiscoveredPrinter p) {
  final key = extractZebraSerial(p.name) ?? p.name ?? p.address;
  (byPrinter[key] ??= []).add(p);
}
```

`extractZebraSerial`, `extractZebraModel`, and `friendlyZebraName` are exported for this. Use
`DiscoveredPrinter.friendlyName` for display.

### Timeouts and retries

Bluetooth LE advertising is bursty, and a first scan right after the app starts often misses
printers. zPrint scans for 30 seconds and, if nothing turns up, retries up to 3 times with a short
pause (700 ms) between attempts. Keep a **Stop** button visible during long scans.

### Single-transport helpers

| Call | Finds |
| :--- | :--- |
| `BleDiscovery.discoverZebra(timeout: ...)` | Zebra printers over Bluetooth LE. On iOS/macOS it filters on Zebra's advertised service; on Android/Windows it filters results client-side. |
| `NetworkDiscovery.discover()` | UDP broadcast to port 4201 |
| `NetworkDiscovery.multicast()` | UDP multicast (224.0.1.55) |
| `NetworkDiscovery.subnetSearch(...)` | TCP probe across a subnet (slow; use when UDP is blocked) |
| `UsbDiscovery.enumerate()` | Attached USB printers (Zebra vendor ID by default; `includeNonZebra: true` lists everything) |

Always offer **manual IP entry** too. Many office networks block UDP broadcast, and
`TcpConnection.zpl(ip)` works without discovery.

---

## 4. Connect

### Connect once

```dart
final printer = await ZebraPrinter.connect(connection);
```

`ZebraPrinter.connect` opens the connection and detects the printer language. Don't call
`connection.open()` first. A second open is harmless on Bluetooth and TCP, but on USB it
enumerates and opens the device a second time.

### Pick the transport: USB, then Wi-Fi, then Bluetooth

When a printer is reachable several ways, try the fastest and most stable first, and fall back:

```dart
Future<ZebraPrinter?> connectBest(List<DiscoveredPrinter> routes) async {
  const order = [ConnectionType.usb, ConnectionType.tcp, ConnectionType.ble];
  final sorted = [...routes]
    ..sort((a, b) => order.indexOf(a.connectionType).compareTo(order.indexOf(b.connectionType)));

  for (final route in sorted) {
    try {
      final printer = await ZebraPrinter.connect(route.createConnection());
      if (route.connectionType != ConnectionType.ble) {
        await printer.getStatus(); // liveness check: proves the printer answers
      }
      return printer;
    } on UsbIdentityMismatchException {
      continue; // a different printer is on that USB port; try the next route
    } on ConnectionException {
      continue;
    }
  }
  return null;
}
```

zPrint pings TCP and USB connections with `getStatus()` right after connecting. A TCP socket can
open even when the printer behind it can't take jobs.

### Read identity once, with single-line settings

After connecting, zPrint reads a few settings to know what it's talking to:

```dart
final model    = await printer.getSetting(PrinterSgdKey.deviceProductName.value); // "ZQ620"
final firmware = await printer.getSetting(PrinterSgdKey.applName.value);          // "V85.20.24"
final width    = await printer.getSetting(PrinterSgdKey.ezplPrintWidth.value);    // dots
final ip       = await printer.getSetting(PrinterSgdKey.ipAddr.value);
```

> **Firmware quirk (seen on ZQ620, firmware V85.20):** don't read `device.host_status` in this pass.
> It returns three lines. Over Bluetooth, the extra lines stay in the receive buffer and become the
> answer to your *next* read (for example, `ip.addr` came back as the serial number). Stick to
> single-line settings, and send one command at a time.

### Bluetooth: auto-reconnect (optional)

zPrint wraps Bluetooth connections so a brief dropout recovers on its own:

```dart
final conn = ReconnectableConnection(BleConnection(deviceId), maxRetries: 3);
final printer = await ZebraPrinter.connect(conn);
```

After a successful reconnect, the operation that hit the dropout throws
`ReconnectSuccessException`. The library never retries a print on its own, because resending
could print a label twice. Catch it and let the user decide:

```dart
try {
  await printer.printZpl(zpl);
} on ReconnectSuccessException {
  // Connection is back, but this job may or may not have printed.
  showRetryPrompt();
}
```

### Upgrade from Bluetooth to Wi-Fi

Bluetooth is convenient for first contact but slow for big jobs. If the printer reports an IP
address, zPrint moves the session to TCP in the background:

```dart
Future<ZebraPrinter?> tryUpgradeToTcp(String ipFromPrinter) async {
  final ip = ipFromPrinter.trim();
  if (ip.isEmpty || ip == '0.0.0.0') return null;

  for (var attempt = 1; attempt <= 2; attempt++) {
    final conn = TcpConnection.zpl(ip);
    ZebraPrinter? tcp;
    try {
      tcp = await ZebraPrinter.connect(conn).timeout(const Duration(seconds: 8));
      await tcp.getStatus();
      return tcp; // now close the Bluetooth printer
    } catch (_) {
      try { await tcp?.disconnect(); } catch (_) {}
      try { await conn.close(); } catch (_) {}
    }
  }
  return null; // stay on Bluetooth (often AP client isolation or a different subnet)
}
```

Notes from zPrint:

- Reuse the IP you read during the identity pass. Don't do a fresh Bluetooth read just for this.
- An 8-second dial timeout with one retry. Phone hotspots add NAT/DHCP latency on the first
  connection, and 3 seconds failed consistently.
- If an attempt fails, disconnect that `ZebraPrinter` before closing its socket and before trying
  again. Otherwise an old listener can stay attached and replies cross between connections.

---

## 5. USB: what works today

The current state of USB, as tested:

| Platform | Result | Details |
| :--- | :--- | :--- |
| **macOS** | ⚪ Not tested | The code is complete (IOKit enumeration, libusb bundled through the podspec), but it hasn't been tested with a printer yet. |
| **Windows** | ❌ **Fails in our testing** | USB printing failed when tested with Zebra printers. The root cause is not confirmed yet; see below. Bluetooth LE and Wi-Fi work on Windows. |
| **Android** | ⚪ Not tested | The code is in place, but the package does not ship `libusb-1.0.so`, so USB calls fail with `UsbLibLoadException` until you build and add it. |
| **iOS** | ➖ Not possible | iOS gives apps no USB access to printers. `UsbConnection.open()` throws `UsbUnsupportedOnPlatformException`. |

**USB has not been confirmed working on any platform yet.** Ship Bluetooth LE or Wi-Fi as your
main path and treat USB as experimental. If you test USB with a printer, please share the result on
the [issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

### Windows: what the code does and what might be wrong

What the Windows implementation does today:

- **Listing printers** uses Windows SetupAPI and works without libusb.
- **Opening a printer** goes through libusb (`libusb-1.0.dll`) and assumes interface 0 and bulk
  endpoints `0x01` (out) / `0x81` (in) with 64-byte packets. It does not read these from the
  printer's USB descriptors yet.
- **Plug/unplug events are not emitted on Windows.** `UsbHotplugStream.events()` stays silent, so
  give users a Refresh button.

Possible causes of the failure (none confirmed yet):

1. **`libusb-1.0.dll` is missing.** The package doesn't include it yet. If the build log shows
   `libusb-1.0.dll not found`, every open fails with `UsbLibLoadException`. Put the official
   [libusb 1.0.29](https://github.com/libusb/libusb/releases/tag/v1.0.29) `VS2022/MS64/dll/libusb-1.0.dll`
   next to your app's `.exe`.
2. **The printer is bound to the Windows printer driver.** With Zebra Setup Utilities or the
   ZDesigner driver installed, Windows binds the printer to `usbprint` and libusb can't claim it.
   You get `UsbDeviceBusyException`. Rebinding to WinUSB with [Zadig](https://zadig.akeo.ie/) gives
   libusb access, but then the normal Windows print queue can't use the printer.
3. **The assumed endpoints don't match the printer.** Some models use different endpoint addresses.
   That would show up as `UsbTransferTimeoutException` or `UsbTransferStalledException` on write.

If you try USB on Windows, please report the printer model, Windows version, driver shown in
Device Manager, and the exception text on the
[issue tracker](https://github.com/minhtri1401/flutter_zpl_printer/issues).

### Using USB (experimental)

```dart
// Address format: usb://VID:PID/SERIAL   (Zebra's vendor ID is 0A5F)
final address = UsbDeviceAddress.parse('usb://0A5F:0027/XXZKN210306204');
final printer = await ZebraPrinter.connect(UsbConnection(address));
```

- **Pin the serial.** If the address includes a serial, `open()` checks the printer's USB serial
  and throws `UsbIdentityMismatchException` (with `expectedSerial` / `actualSerial`) if a
  different printer is plugged in. zPrint uses this to avoid printing to the wrong device, and
  falls back to the next transport.
- **Debounce plug events.** Hubs fire bursts of attach events. zPrint waits 500 ms after the last
  attach before acting on it:

  ```dart
  Timer? debounce;
  UsbHotplugStream.events().listen((e) {
    if (e.type != UsbHotplugType.attached) return refreshList();
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () => offerUsb(e.address));
  });
  ```

- **Android permission** is requested automatically by `UsbConnection.open()`. A refusal throws
  `UsbPermissionDeniedException`.
- **macOS sandboxed apps** need the `com.apple.security.device.usb` entitlement (see the README).
- **Debugging "plugged in but not found":** `UsbDiscovery.enumerate(includeNonZebra: true)` lists
  every USB device. If that is empty too, the OS is blocking access (entitlement, permission, or
  driver). If it lists devices but no Zebra, the printer isn't presenting as a Zebra device.
  The printer's own view is in the `usb.connected` setting.

---

## 6. Print and read printer state

### Print

```dart
await printer.printZpl(zpl);
```

`printZpl` writes the bytes and returns once they're sent. It does not wait for the label to come
out. For multiple copies, either loop or use ZPL's `^PQ` command (`^PQ3` prints three):

```dart
for (var i = 0; i < copies; i++) {
  await printer.printZpl(zpl);
}
```

Check status before a job so you can say *why* it won't print:

```dart
final s = await printer.getStatus();
if (!s.isReadyToPrint) {
  final reason = s.isHeadOpen ? 'Close the print head'
      : s.isPaperOut ? 'Load labels'
      : s.isRibbonOut ? 'Replace the ribbon'
      : s.isPaused ? 'Printer is paused'
      : s.isHeadTooHot ? 'Print head is too hot. Wait a moment'
      : 'Printer is not ready';
  showMessage(reason);
  return;
}
await printer.printZpl(zpl);
```

To build the ZPL itself, see [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator).

### Images: use flutter_zpl_generator

Build image labels with [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator)
and send them with `printZpl`. This is how zPrint prints images on real printers:

```dart
import 'dart:typed_data';

import 'package:flutter_zpl_generator/flutter_zpl_generator.dart' as zpl; // prefix: both packages define ZplPrintMode
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

Future<void> printPicture(ZebraPrinter printer, Uint8List pngBytes) async {
  // Print width in dots, as reported by the printer (fallback: 384 dots,
  // a 2-inch 203 dpi mobile printer).
  final raw = await printer.getSetting(PrinterSgdKey.ezplPrintWidth.value);
  final width = int.tryParse(raw.trim()) ?? 384;

  final label = await zpl.ZplGenerator(
    config: zpl.ZplConfiguration(
      printWidth: width,
      printMode: zpl.ZplPrintMode.tearOff,
    ),
    autoLabelLengthFromFirstImage: true,
    commands: [
      zpl.ZplImageDownload(
        image: pngBytes,
        targetWidth: width,
        ditheringAlgorithm: zpl.ZplDitheringAlgorithm.threshold,
      ),
      const zpl.ZplImageRecall(), // x: 0, y: 0, graphicName: 'IMG'
    ],
  ).build();

  await printer.printZpl(label);
}
```

Why these settings, from zPrint:

- **`~DG` download, then `^XG` recall.** `ZplImageDownload` puts the graphic in printer memory
  before `^XA`, which Link-OS mobile printers (ZQ620 and others) need. `ZplImageRecall` places it.
- **Uncompressed hex** (the default, `ZplImageCompression.none`). Every Zebra printer accepts it.
- **Threshold dithering.** Floyd-Steinberg's dense dot coverage can trip the print head's thermal
  protection on the ZQ620.
- **Tear-off mode** (`ZplPrintMode.tearOff`). A mobile printer left in applicator or cutter mode
  can hold labels instead of printing them.
- **`autoLabelLengthFromFirstImage`** sets the label length to the image height.

> **Avoid `printer.printImage(...)` / `GraphicsUtil.printImage(...)` in 0.1.x.** They compress with
> Z64 by default, and the Z64 checksum is computed over the raw bitmap instead of the Base64 text
> that Zebra's manual specifies. A printer that checks it treats the image as an aborted download.
> If you must use them, pass `useCompression: false`. See
> [Known issues](README.md#image-compression-z64).

### Printer info in one call

```dart
final info = await printer.getMetadata(keys: const [
  PrinterMetadataKey.deviceProductName,
  PrinterMetadataKey.deviceFriendlyName,
  PrinterMetadataKey.powerPercentFull,
  PrinterMetadataKey.ezplPrintWidth,
  PrinterMetadataKey.zplLabelLength,
]);
```

Keys the printer doesn't support are left out of the map instead of throwing. Only ask for what
the screen needs: each key is one round trip, which adds up over Bluetooth.

### Battery

```dart
int? battery(String raw) {
  final v = raw.trim();
  if (v.isEmpty || v == '?') return null; // desktop printer, or not supported
  return int.tryParse(v);
}

final percent = battery(await printer.getSetting(PrinterSgdKey.powerPercentFull.value));
```

Printers answer `?` for settings they don't have. Treat `?` and an empty string as "unknown".

### Darkness and speed

zPrint's print-quality screen uses these keys and ranges:

```dart
await printer.setSetting(PrinterSgdKey.headDarknessSwitch.value, '15'); // 0–30
await printer.setSetting(PrinterSgdKey.mediaSpeed.value, '3');          // 1–6 (ips)
```

With a slider, update the label while dragging and only write the setting when the user lets go
(`onChangeEnd`). A write per frame floods the printer.

### Built-in actions

```dart
await printer.printConfigurationLabel(); // ~WC
await printer.calibrate();               // ~JC: re-measures the media
```

---

## 7. Settings and actions (SGD)

Zebra printers expose their configuration as named settings ("SGD": Set / Get / Do).
`PrinterSgdKey` lists keys verified on real printers, grouped by `SgdCategory`.

### Get and set

```dart
final name = await printer.getSetting(PrinterSgdKey.deviceFriendlyName.value);
await printer.setSetting(PrinterSgdKey.deviceFriendlyName.value, 'Dock-3');
```

### Several settings in one write

To apply a batch (Wi-Fi setup, a saved profile), zPrint sends all the `setvar` lines in a single
write instead of one round trip each:

```dart
// import 'dart:convert'; import 'dart:typed_data';
final batch = StringBuffer()
  ..write('! U1 setvar "device.friendly_name" "Dock-3"\r\n')
  ..write('! U1 setvar "head.darkness_switch" "15"\r\n')
  ..write('! U1 setvar "media.speed" "3"\r\n');
await printer.connection.write(Uint8List.fromList(utf8.encode(batch.toString())));
```

### Actions ("do" commands)

`Sgd.doCommand` and `printer.doCommand` send the command and **wait for a reply**. Many actions
never reply (`device.reset` reboots the printer), so the call sits there until it times out. For
fire-and-forget actions, zPrint writes the packet directly:

```dart
Future<void> sgdDo(Connection conn, String action, [String arg = '']) =>
    conn.write(Uint8List.fromList(utf8.encode('! U1 do "$action" "$arg"\r\n')));

await sgdDo(printer.connection, 'device.reset');
```

Use `doCommand` only for actions you know answer.

---

## 8. Disconnect cleanly

```dart
await printer.disconnect();
```

- On Bluetooth, `close()` waits about 5 seconds before dropping the link so the printer can finish
  receiving the last job. Don't block the UI on it: navigate away and let it finish.
- If you're mid-upgrade (Bluetooth to TCP), stop the upgrade first, then disconnect, so a
  late-arriving TCP socket doesn't bring the session back.
- Put each teardown step in its own `try`/`catch`. One failure (the printer already gone)
  shouldn't stop the rest of the cleanup.

---

## 9. Handle errors

Everything the library throws is a `ConnectionException` or a subclass. zPrint maps them to these
messages:

| Exception | When | Message zPrint shows |
| :--- | :--- | :--- |
| `ConnectionTimeoutException` | No answer in time | "Printer not responding. Move closer or check it's on." |
| `ConnectionClosedException` | Link dropped mid-operation | "Printing was interrupted. Reconnect and tap Retry to reprint." |
| `ReconnectSuccessException` | Auto-reconnect worked; the operation may not have | Ask before resending |
| `UsbDeviceBusyException` | Another driver owns the printer (Windows) | Show `e.remediation`; it says how to fix it |
| `UsbPermissionDeniedException` | User refused USB access (Android) | Explain and offer to retry |
| `UsbIdentityMismatchException` | A different printer is on that port | Fall back to the next transport |
| `UsbLibLoadException` | libusb missing (Windows DLL, Android `.so`) | Use Wi-Fi or Bluetooth instead |
| `UsbUnsupportedOnPlatformException` | USB on iOS | Hide USB on this platform |
| `ConnectionException` (other) | Anything else | "Couldn't reach printer. Check it's not connected elsewhere." |

Keep `e.toString()` for logs or a "details" view. Users need the plain message, support needs the
details.

---

## 10. Test without a printer

USB has a fake platform you can script:

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer_testing.dart';

final fake = FakeUsbPlatform()..devices.add(UsbDeviceRecord(
  vendorId: 0x0A5F, productId: 0x0027, path: '/fake', hasPermission: true,
  serialNumber: 'XX1', interfaceNumber: 0, bulkInEndpoint: 0x81, bulkOutEndpoint: 0x01,
));
final conn = UsbConnection.withPlatform(UsbDeviceAddress.parse('usb://0A5F:0027/XX1'), fake);
final printer = await ZebraPrinter.connect(conn);
```

For everything else, put your printer code behind your own small interface and fake it there, or
subclass `Connection` to record writes and return canned replies.

---

## 11. Troubleshooting

| Symptom | Check |
| :--- | :--- |
| Bluetooth scan finds nothing | Is the adapter `poweredOn`? Android permissions granted? Is the printer awake (mobile printers sleep)? Does it support Bluetooth LE (4.0+)? Scan for longer, or retry. |
| Bluetooth connects but replies look wrong | Are you sending commands concurrently? Did you read a multi-line setting such as `device.host_status`? |
| Wi-Fi discovery finds nothing | The network may block UDP broadcast. Use manual IP or `subnetSearch`. On iOS, add `NSLocalNetworkUsageDescription`. On macOS, sandboxed apps need `com.apple.security.network.server` to receive replies. |
| TCP connect times out | Same subnet? Phone hotspots and guest networks often isolate clients. |
| USB printer not listed (macOS) | Sandboxed app without `com.apple.security.device.usb`? Try `includeNonZebra: true`. |
| USB on Windows fails | See [section 5](#windows-what-the-code-does-and-what-might-be-wrong). Use Wi-Fi or Bluetooth for now. |
| `UsbLibLoadException` | libusb isn't next to the app (Windows) or wasn't built into the APK (Android). |
| Image prints blank or not at all | Using `printImage` / `GraphicsUtil.printImage`? Switch to `flutter_zpl_generator` ([section 6](#images-use-flutter_zpl_generator)) or pass `useCompression: false`. |
| A reset or other action hangs | You used `doCommand` for an action that never replies. Write the packet directly ([section 7](#actions-do-commands)). |
