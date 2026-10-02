import 'package:flutter/services.dart';
import '../connection/usb_device_address.dart';

/// Direction of a hot-plug event.
enum UsbHotplugType { attached, detached }

/// One USB attach or detach event pushed from native to Dart.
class UsbHotplugEvent {
  final UsbHotplugType type;
  final UsbDeviceAddress address;

  /// Platform-specific opaque path — same shape as [UsbDeviceRecord.path].
  final String path;

  final DateTime timestamp;

  UsbHotplugEvent({
    required this.type,
    required this.address,
    required this.path,
    required this.timestamp,
  });

  /// Parses the wire payload (defined in the USB transport spec §3.3).
  factory UsbHotplugEvent.fromMap(Map<Object?, Object?> m) {
    final rawType = m['type'];
    final type = switch (rawType) {
      'attached' => UsbHotplugType.attached,
      'detached' => UsbHotplugType.detached,
      _ => throw FormatException('Unknown hotplug type', rawType),
    };
    return UsbHotplugEvent(
      type: type,
      address: UsbDeviceAddress(
        vendorId: m['vendorId'] as int,
        productId: m['productId'] as int,
        serialNumber: m['serialNumber'] as String?,
      ),
      path: m['path'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(m['timestamp_ms'] as int),
    );
  }
}

/// Broadcast stream of USB attach/detach events.
///
/// Emits on macOS and Android. Windows does not emit events yet, and iOS
/// never does.
///
/// Native side starts emitting on first listen, stops on last cancel. Payload
/// shape defined in the USB transport spec §3.3. All three platforms emit the
/// same dictionary — Dart side does not branch.
class UsbHotplugStream {
  UsbHotplugStream._();

  static const _channel = EventChannel('com.zebra.flutter_zpl_printer/usb/hotplug');

  /// Returns a broadcast stream. Multiple listeners are supported; each gets
  /// the same events (Flutter's `receiveBroadcastStream` handles fan-out).
  static Stream<UsbHotplugEvent> events() => _channel
      .receiveBroadcastStream()
      .map((raw) => UsbHotplugEvent.fromMap((raw as Map).cast<Object?, Object?>()));
}
