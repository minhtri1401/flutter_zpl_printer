// Pigeon interface for the USB transport's platform channel.
//
// Regenerate with:
//   dart run pigeon --input pigeons/usb_messages.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/platform/usb_messages.g.dart',
  dartTestOut: 'test/platform/usb_messages_test_api.g.dart',
  kotlinOut: 'android/src/main/kotlin/com/example/flutter_zpl_printer/UsbMessages.g.kt',
  kotlinOptions: KotlinOptions(package: 'com.example.flutter_zpl_printer'),
  swiftOut: 'darwin/Classes/UsbMessages.g.swift',
  swiftOptions: SwiftOptions(),
  cppHeaderOut: 'windows/usb/usb_messages.g.h',
  cppSourceOut: 'windows/usb/usb_messages.g.cpp',
  cppOptions: CppOptions(namespace: 'flutter_zpl_printer'),
  copyrightHeader: 'pigeons/copyright.txt',
))

/// One USB device returned by [UsbHostApi.enumerate].
class UsbDeviceRecord {
  UsbDeviceRecord({
    required this.vendorId,
    required this.productId,
    required this.path,
    required this.hasPermission,
    this.manufacturer,
    this.product,
    this.serialNumber,
    this.interfaceNumber,
    this.bulkInEndpoint,
    this.bulkOutEndpoint,
    this.wMaxPacketSizeOut,
    this.driverBinding,
  });

  /// Vendor ID (0x0A5F for Zebra).
  final int vendorId;

  /// Product ID.
  final int productId;

  /// Platform-opaque identifier used for subsequent calls.
  /// Android: `/dev/bus/usb/001/004`. macOS: IOKit path. Windows: `\\?\USB#VID_...`.
  final String path;

  /// Android-relevant. True on macOS/Windows (permission model is per-app, not per-device).
  final bool hasPermission;

  final String? manufacturer;
  final String? product;
  final String? serialNumber;

  /// Printer-class interface index (`bInterfaceClass == 0x07`). Null if no such
  /// interface exists on the device.
  final int? interfaceNumber;

  /// Bulk IN endpoint address (with direction bit).
  final int? bulkInEndpoint;

  /// Bulk OUT endpoint address.
  final int? bulkOutEndpoint;

  /// wMaxPacketSize of the bulk-OUT endpoint. Drives auto chunk size.
  final int? wMaxPacketSizeOut;

  /// Windows-only. One of "WINUSB", "USBPRINT", "OTHER". Null on other platforms.
  final String? driverBinding;
}

/// Filter passed to [UsbHostApi.enumerate].
class UsbEnumerateFilter {
  UsbEnumerateFilter({
    this.vendorId,
    this.includeDescriptorStrings = true,
  });

  /// If non-null, return only devices with this vendor ID.
  final int? vendorId;

  /// Reading descriptor strings is slow on Windows (~10-50ms/device).
  /// Set false during hot-plug re-enumeration where latency matters.
  final bool includeDescriptorStrings;
}

/// Result of a successful [UsbHostApi.openForFfi] call. The Dart FFI layer
/// takes over I/O from here.
class UsbOpenResult {
  UsbOpenResult({
    required this.platformHandle,
    required this.vendorId,
    required this.productId,
    required this.claimedInterfaceNumber,
    required this.bulkInEndpoint,
    required this.bulkOutEndpoint,
    required this.wMaxPacketSizeOut,
    this.serialNumber,
  });

  /// Android: file descriptor from `UsbDeviceConnection.getFileDescriptor()`.
  /// macOS/Windows: 0 (FFI matches the device via VID+PID+serial).
  final int platformHandle;

  final int vendorId;
  final int productId;
  final String? serialNumber;

  /// Interface index that the native side has claimed.
  final int claimedInterfaceNumber;

  final int bulkInEndpoint;
  final int bulkOutEndpoint;
  final int wMaxPacketSizeOut;
}

/// USB host API — lifecycle only. Bulk I/O happens via Dart FFI directly to
/// libusb; channel hops would be too expensive for the hot path.
@HostApi()
abstract class UsbHostApi {
  /// Quick capability probe. False on iOS and on desktops without libusb.
  bool isSupported();

  /// Snapshot enumeration. Returns a complete list (no streaming).
  @async
  List<UsbDeviceRecord> enumerate(UsbEnumerateFilter filter);

  /// Android: `UsbManager.hasPermission(device)`. Other: always true.
  bool hasPermission(String path);

  /// Android: triggers system dialog; resolves when user responds.
  /// Other: resolves true immediately.
  @async
  bool requestPermission(String path);

  /// Claims the printer-class interface on Android (fd-based libusb handoff).
  /// On macOS/Windows, returns metadata so Dart FFI can call libusb_open.
  /// Throws on permission denied, device busy, device disappeared, etc.
  @async
  UsbOpenResult openForFfi(String path);

  /// Final cleanup after Dart FFI has released and closed the libusb handle.
  /// Android: closes the retained `UsbDeviceConnection`. Other: no-op.
  /// Must be idempotent.
  @async
  void closeAfterFfi(String path);
}
