# flutter_zpl_printer

A robust Flutter plugin for discovering, connecting to, and interacting with Zebra ZPL-compatible printers on Android and iOS. 

Built deeply upon the official **Zebra Link-OS Multiplatform SDK**, this library grants developers the power to reliably connect over Bluetooth (MFi / Classic / BLE) and Wi-Fi (TCP/IP), inspect hardware status, fetch deep configuration settings, and reliably dispatch raw ZPL payloads.

This package is meticulously designed as the Native counterpart to the pure-Dart [`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator) library.

---

## 🚀 Features

* **📡 Network & Wireless Discovery:** Scan for local Wi-Fi and attached Bluetooth ZPL printers automatically.
* **🔌 Multi-Protocol Connections:** Seamlessly open and close TCP/IP or Bluetooth hardware connections.
* **🏷️ Raw ZPL Printing:** Emit ZPL format strings payload over the wire.
* **📊 Hardware Status:** Detailed insight into hardware states (`isHeadOpen`, `isPaperOut`, `isRibbonOut`, `isPaused`, `isReadyToPrint`, etc.).
* **⚙️ Complete Settings (`allcv`):** Read the full map of active hardware configurations directly from the printer's OS.
* **🧵 Thread-Safe:** All native execution is shunted to background Executors & Grand Central Dispatch background queues, protecting the Flutter UI thread entirely.

---

## 🛠 Platform Setup

For this plugin to successfully reach physical hardware via the native Zebra SDKs, you **must** configure the following permissions in your host application:

### Android
Add these permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Network (Wi-Fi) Permissions -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

<!-- Bluetooth Classic / BLE Permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<!-- Android 12+ Bluetooth Permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" /> <!-- Required for Bluetooth discovery -->
```

*(Note: Don't forget to request runtime permissions for Location/Bluetooth if your app targets Android 6.0+!)*

### iOS
Add the following keys to your `ios/Runner/Info.plist`:

```xml
<!-- Required for MFi Bluetooth connection to Zebra printers -->
<key>UISupportedExternalAccessoryProtocols</key>
<array>
  <string>com.zebra.rawport</string>
</array>

<!-- Optional depending on your use-case: Keeps connection alive -->
<key>UIBackgroundModes</key>
<array>
  <string>external-accessory</string> 
</array>

<!-- Privacy Prompts -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app requires Bluetooth to connect to Zebra ZPL printers.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app requires Local Network access to discover Zebra networked printers.</string>
```

---

## 📖 Usage Examples

### 1. Initialization and Discovery
Listen to the discovery streams, and then start the scan:

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

final printerPlugin = FlutterZplPrinter();

// Listen for Discovered Devices
printerPlugin.onPrinterFound.listen((PrinterDevice device) {
  print('Found ${device.name} at ${device.address} (${device.type.name})');
});

// Listen for Completion
printerPlugin.onDiscoveryCompleted.listen((_) {
  print('Discovery finished!');
});

// Trigger Scan
await printerPlugin.startDiscovery();
```

*(Always remember to call `printerPlugin.stopDiscovery()` or `printerPlugin.dispose()` when cleaning up your UI!)*

### 2. Connect & Print
Once you've captured a `PrinterDevice.address` from the discovery stream, establishing a connection is straightforward:

```dart
// Connect using the device's Address (IP or MAC / Serial) and Type
await printerPlugin.connect(device.address, device.type);

// (Optional) Generate a beautiful ZPL payload using flutter_zpl_generator here!
final myZpl = "^XA^FO50,50^ADN,36,20^FDHello World!^FS^XZ";

// Push to the printer
await printerPlugin.printZpl(myZpl);

// Always disconnect securely to free up OS file descriptors
printerPlugin.disconnect();
```

### 3. Check Printer Status
Curious why a print job failed? The `getStatus()` command polls the physical hardware to see what is jammed:

```dart
await printerPlugin.connect(device.address, device.type);

final PrinterStatus status = await printerPlugin.getStatus();

if (status.isReadyToPrint) {
    print('Printer is online and ready!');
} else {
    // Audit the device sensors
    if (status.isPaperOut) print("Out of labels!");
    if (status.isHeadOpen) print("Please close the printer hatch!");
    if (status.isPaused) print("Printer is paused.");
    if (status.isHeadTooHot) print("Print head overheated. Please wait.");
}
```

### 4. Fetch Deep Settings
If you want to read underlying configurations (baud rate, darkness, print mode, tear off offset, etc.):

```dart
await printerPlugin.connect(device.address, device.type);

final Map<String, String> settings = await printerPlugin.getSettings();

print('Printer IP Configuration: ${settings["ip.addr"]}');
print('Overall Darkness Level: ${settings["print.tone"]}');
```

*(Note: On iOS, settings are retrieved via the Zebra SGD command `! U1 getvar "allcv"`. On Android, the Link-OS `SettingsProvider` API is used, which requires a Link-OS compatible printer.)*

---

## 🤝 The Perfect Match: `flutter_zpl_generator`

While `flutter_zpl_printer` flawlessly handles the complex hardware connections, **crafting raw ZPL strings by hand is an absolute nightmare.**

### ❌ The Old Way (Raw ZPL Strings)
Manually concatenating ZPL code means fighting coordinate math, memorizing obscure two-letter ZPL commands (`^FO`, `^ADN`), and discovering syntax errors only *after* the label comes out of the printer... badly.

```dart
// 💀 Nightmare to read, write, and maintain:
final myZpl = "^XA\n"
              "^FO50,50^ADN,36,20^FDWarehouse A - Rack 5^FS\n"
              "^FO50,150^BY3^BCN,100,Y,N,N^FD9876543210^FS\n"
              "^XZ";

await printerPlugin.printZpl(myZpl);
```

### ✅ The Modern Way (`flutter_zpl_generator`)
Pair this plugin with its companion library, **[`flutter_zpl_generator`](https://pub.dev/packages/flutter_zpl_generator)**. It allows you to build type-safe, declarative ZPL designs in pure Dart!

```bash
# Get both packages running today:
flutter pub add flutter_zpl_printer
flutter pub add flutter_zpl_generator
```

Then, simply combine them for a completely seamless hardware printing pipeline:

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:flutter_zpl_generator/flutter_zpl_generator.dart';

Future<void> printModernLabel(PrinterDevice device) async {
  final printerPlugin = FlutterZplPrinter();
  await printerPlugin.connect(device.address, device.type);

  // 🎨 Declaratively design your configuration and commands (like a Widget Tree!)
  final generator = ZplGenerator(
    config: ZplConfiguration(
      printWidth: 4 * 203,  // 4 inches at 203 DPI 
      labelLength: 6 * 203, // 6 inches at 203 DPI
    ),
    commands: [
        // Safe, human-readable ZPL elements!
        ZplText(text: "Warehouse A - Rack 5", x: 10, y: 10),
        ZplBarcode(
            data: "9876543210", 
            type: ZplBarcodeType.code128, 
            height: 100, // Barcode height in dots
            x: 10, 
            y: 80,
        ),
    ],
  );
  
  // 📠 Render safely and dispatch instantly to the printer!
  final String payload = await generator.build();
  await printerPlugin.printZpl(payload);
  
  printerPlugin.disconnect();
}
```

#### Why You'll Love It:
* **Zero Syntax Errors:** Emitting malformed ZPL commands is impossible.
* **Type-Safety:** Strongly typed enums for Barcodes, QR codes, and Fonts ensure you always use valid printer parameters.
* **Maintainable:** The structure resembles familiar Flutter Widget trees, drastically reducing onboarding time for your internal teams.

---

## 🚨 Error Handling

Native errors are propagated as `PlatformException` with structured error codes for cross-platform tracking:

| Code | Meaning |
|------|---------|
| `1001` | Connection open failed |
| `2001` | Write / print failed |
| `3001` | Printer instance creation failed |
| `3002` | Status query failed |
| `4001` | Settings: no response from printer (iOS) |
| `4002` | Settings: empty response from printer (iOS) |
| `4003` | Settings: printer does not support Link-OS (Android) |
| `5001` | Not connected to a printer |

```dart
import 'package:flutter/services.dart';

try {
  await printerPlugin.printZpl(myZpl);
} on PlatformException catch (e) {
  switch (e.code) {
    case '5001':
      print('Please connect to a printer first.');
    case '1001':
      print('Could not reach the printer. Check network/Bluetooth.');
    default:
      print('Printer error [${e.code}]: ${e.message}');
  }
}
```
