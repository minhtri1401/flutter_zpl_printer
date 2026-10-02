import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../usb_messages.g.dart';
import '../usb_platform.dart';

/// In-memory [UsbPlatform] for tests.
///
/// Tests configure [devices], toggles, and delays; then construct the class
/// under test with [UsbConnection.withPlatform] or [UsbDiscovery.enumerateWith].
///
/// Exposed under `package:flutter_zpl_printer/flutter_zpl_printer_testing.dart` so consumer apps can
/// reuse it in their own widget/integration tests.
class FakeUsbPlatform implements UsbPlatform {
  /// Devices that [enumerate] returns (filtered by VID when `filter.vendorId != null`).
  final List<UsbDeviceRecord> devices = [];

  /// Value returned from [isSupported].
  bool isSupportedResult = true;

  /// If set, [enumerate] throws this instead of returning a list.
  Object? enumerateError;

  /// Value returned from [requestPermission]. Default: granted.
  bool permissionGrantResult = true;

  /// If set, [openForFfi] throws this instead of returning a handle.
  Object? openError;

  /// If set, [writeBytes] throws this on every call.
  Object? writeError;

  /// If set, [readBytes] throws this on every call.
  Object? readError;

  /// Artificial delay applied inside [openForFfi] — useful for cancellation
  /// tests.
  Duration openDelay = Duration.zero;

  final Map<int, _FakeHandle> _handles = {};
  int _nextHandleId = 1;

  @override
  Future<bool> isSupported() async => isSupportedResult;

  @override
  Future<List<UsbDeviceRecord>> enumerate(UsbEnumerateFilter filter) async {
    if (enumerateError != null) throw enumerateError!;
    return devices
        .where((d) => filter.vendorId == null || d.vendorId == filter.vendorId)
        .toList();
  }

  @override
  Future<bool> hasPermission(String path) async =>
      devices.any((d) => d.path == path && d.hasPermission);

  @override
  Future<bool> requestPermission(String path) async => permissionGrantResult;

  @override
  Future<UsbOpenResult> openForFfi(String path) async {
    if (openDelay != Duration.zero) await Future<void>.delayed(openDelay);
    if (openError != null) throw openError!;
    final device = devices.firstWhere(
      (d) => d.path == path,
      orElse: () => throw StateError('FakeUsbPlatform: no device at $path'),
    );
    final id = _nextHandleId++;
    _handles[id] = _FakeHandle(device);
    return UsbOpenResult(
      platformHandle: id,
      vendorId: device.vendorId,
      productId: device.productId,
      serialNumber: device.serialNumber,
      claimedInterfaceNumber: device.interfaceNumber ?? 0,
      bulkInEndpoint: device.bulkInEndpoint ?? 0x81,
      bulkOutEndpoint: device.bulkOutEndpoint ?? 0x01,
      wMaxPacketSizeOut: device.wMaxPacketSizeOut ?? 64,
    );
  }

  @override
  Future<void> closeAfterFfi(String path) async {}

  @override
  Future<void> writeBytes({
    required int handleId,
    required Uint8List data,
    required int timeoutMs,
  }) async {
    if (writeError != null) throw writeError!;
    final h = _handles[handleId];
    if (h == null) throw StateError('Invalid handle $handleId');
    h.written.add(Uint8List.fromList(data));
  }

  @override
  Future<Uint8List> readBytes({
    required int handleId,
    required int maxBytes,
    required int timeoutMs,
  }) async {
    if (readError != null) throw readError!;
    final h = _handles[handleId];
    if (h == null) throw StateError('Invalid handle $handleId');
    if (h.readQueue.isEmpty) return Uint8List(0);
    return h.readQueue.removeFirst();
  }

  @override
  Future<void> clearHalt({required int handleId, required int endpoint}) async {}

  @override
  Future<void> resetDevice({required int handleId}) async {}

  @override
  Future<String?> readStringDescriptor({
    required int handleId,
    required int index,
  }) async =>
      _handles[handleId]?.device.serialNumber;

  @override
  Future<void> closeHandle({required int handleId}) async {
    _handles.remove(handleId);
  }

  // ─── Test helpers ─────────────────────────────────────────────────────

  /// Writes recorded for an open handle. Empty after [closeHandle].
  List<Uint8List> writesFor(int handleId) =>
      _handles[handleId]?.written ?? const [];

  /// Queue a byte buffer that will be returned by the next [readBytes] call
  /// on [handleId].
  void queueRead(int handleId, Uint8List data) {
    _handles[handleId]?.readQueue.add(data);
  }

  bool isHandleOpen(int handleId) => _handles.containsKey(handleId);
}

class _FakeHandle {
  _FakeHandle(this.device);
  final UsbDeviceRecord device;
  final List<Uint8List> written = [];
  final Queue<Uint8List> readQueue = Queue();
}
