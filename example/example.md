# flutter_zpl_printer examples

Print to a Zebra label printer from Flutter over Bluetooth LE, Wi-Fi, or USB. These snippets cover the
common tasks. The full example app (Bluetooth, Wi-Fi, and USB tabs plus a printer screen) is in
[`example/lib`](https://github.com/minhtri1401/flutter_zpl_printer/tree/main/example/lib).

```dart
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart'; // includes flutter_zpl_generator
```

## Connect

```dart
// Wi-Fi / Ethernet: raw ZPL on port 9100.
final printer = await ZebraPrinter.connect(TcpConnection.zpl('192.168.1.50'));

// Bluetooth LE: scan for Zebra printers, then connect to one.
final found = await BleDiscovery.discoverZebra(timeout: const Duration(seconds: 15)).first;
final blePrinter = await ZebraPrinter.connect(found.createConnection());

// USB (experimental): address format usb://VENDOR:PRODUCT/SERIAL, Zebra's vendor ID is 0A5F.
final usbPrinter = await ZebraPrinter.connect(
  UsbConnection(UsbDeviceAddress.parse('usb://0A5F:0027/XXZKN210306204')),
);
```

`ZebraPrinter.connect` opens the connection itself. Don't call `connection.open()` first.

On Android, request Bluetooth permissions (`bluetoothScan`, `bluetoothConnect`, `location`) before scanning,
for example with `permission_handler`. See the README for the iOS, macOS, and Android setup keys.

## Check status, then print

```dart
final status = await printer.getStatus();
if (!status.isReadyToPrint) {
  print(status.isHeadOpen ? 'Close the print head'
      : status.isPaperOut ? 'Load labels'
      : status.isRibbonOut ? 'Replace the ribbon'
      : 'Printer is not ready');
} else {
  // Raw ZPL...
  await printer.printZpl('^XA^FO50,50^A0N,40,40^FDHello Zebra^FS^XZ');

  // ...or a typed label built with flutter_zpl_generator.
  await printer.printLabel(ZplGenerator(
    config: const ZplConfiguration(printWidth: 406), // 2 inches at 203 dpi
    commands: [
      ZplText(x: 40, y: 40, text: 'Order #1042'),
      ZplBarcode(x: 40, y: 100, data: '1042', height: 80),
    ],
  ));
}
```

## Print an image

```dart
// PNG or JPEG bytes. Downloaded with ~DG, then placed with ^XG.
await printer.printImage(pngBytes, targetWidth: 400);
```

## Read printer info

```dart
final info = await printer.getMetadata(keys: const [
  PrinterMetadataKey.deviceProductName, // model
  PrinterMetadataKey.applName,          // firmware
  PrinterMetadataKey.powerPercentFull,  // battery, "?" on printers without one
]);
```

## Handle errors and disconnect

```dart
try {
  await printer.printZpl(zpl);
} on ConnectionTimeoutException {
  print('Printer not responding. Check it is on and in range.');
} on ConnectionException catch (e) {
  print(e.message);
} finally {
  await printer.disconnect();
}
```

More: [README](https://pub.dev/packages/flutter_zpl_printer) ·
[integration guide](https://github.com/minhtri1401/flutter_zpl_printer/blob/main/GUIDE.md)
