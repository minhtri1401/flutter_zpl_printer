/// Test-only exports. Consumers import this instead of `package:flutter_zpl_printer/flutter_zpl_printer.dart`
/// when they need public test doubles (e.g. in widget or integration tests).
///
/// The classes here are intentionally public but not exported from the main
/// barrel — they have no production use.
library;

export 'src/platform/testing/fake_usb_platform.dart';
export 'src/platform/usb_messages.g.dart'
    show UsbDeviceRecord, UsbEnumerateFilter, UsbOpenResult;
export 'src/platform/usb_platform.dart';
