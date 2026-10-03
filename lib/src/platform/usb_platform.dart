import 'dart:typed_data';

import 'usb_messages.g.dart'
    show UsbDeviceRecord, UsbEnumerateFilter, UsbOpenResult;

/// Abstract seam between high-level USB classes ([UsbConnection],
/// [UsbDiscovery]) and the concrete MethodChannel + FFI backend.
///
/// Production code wires the composite at [UsbConnection._defaultPlatform].
/// Tests swap in [FakeUsbPlatform] via [UsbConnection.withPlatform].
abstract class UsbPlatform {
  // ─── Lifecycle — routes to Pigeon MethodChannel ─────────────────────────
  Future<bool> isSupported();
  Future<List<UsbDeviceRecord>> enumerate(UsbEnumerateFilter filter);
  Future<bool> hasPermission(String path);
  Future<bool> requestPermission(String path);
  Future<UsbOpenResult> openForFfi(String path);
  Future<void> closeAfterFfi(String path);

  // ─── I/O — routes to libusb FFI worker isolate ──────────────────────────

  /// Writes [data] via libusb_bulk_transfer on the bulk-OUT endpoint
  /// associated with the handle. The handle is the [UsbOpenResult.platformHandle]
  /// returned by [openForFfi].
  Future<void> writeBytes({
    required int handleId,
    required Uint8List data,
    required int timeoutMs,
  });

  /// Reads up to [maxBytes] from the bulk-IN endpoint. Returns the actual
  /// bytes read (may be 0). Throws [UsbTransferTimeoutException] on timeout.
  Future<Uint8List> readBytes({
    required int handleId,
    required int maxBytes,
    required int timeoutMs,
  });

  /// libusb_clear_halt on the given endpoint. Used after
  /// LIBUSB_ERROR_PIPE to recover a stalled endpoint.
  Future<void> clearHalt({required int handleId, required int endpoint});

  /// libusb_reset_device. Caller must treat the handle as invalid after this
  /// — typically followed by close + re-open.
  Future<void> resetDevice({required int handleId});

  /// Reads an ASCII string descriptor at [index] via
  /// libusb_get_string_descriptor_ascii. Returns null on read failure.
  Future<String?> readStringDescriptor({
    required int handleId,
    required int index,
  });

  /// Releases the claimed interface and closes the libusb device handle.
  /// Also terminates the worker isolate that owned the handle.
  Future<void> closeHandle({required int handleId});
}
