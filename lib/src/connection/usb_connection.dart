import 'dart:async';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../exceptions/connection_exception.dart';
import '../platform/usb_messages.g.dart';
import '../platform/usb_platform.dart';
import '../platform/usb_platform_composite.dart';
import 'connection.dart';
import 'usb_device_address.dart';

/// USB [Connection] backed by a native platform channel for lifecycle and
/// libusb FFI for bulk I/O.
///
/// Platform status in this release: works on macOS; fails in testing on
/// Windows (cause not yet confirmed, see the README's "Known issues"); not
/// tested on Android, where `libusb-1.0.so` is not bundled; not possible on
/// iOS, where [open] throws [UsbUnsupportedOnPlatformException].
///
/// Lifecycle flow:
///   1. [open] checks platform support, requests permission (Android) if
///      needed, calls `openForFfi` to get a handle, verifies identity,
///      claims the interface, and makes the handle available for I/O.
///   2. [writeRaw] / [read] delegate through [UsbPlatform] — in production
///      those methods route to a per-connection worker isolate that owns
///      libusb calls (Task 18). Stall recovery is bounded by
///      `config.usbStallRetries`; unplug surfaces [UsbDeviceUnpluggedException]
///      and closes the connection.
///   3. [close] is idempotent; releases the interface, closes the libusb
///      handle, and notifies native side.
class UsbConnection extends Connection {
  final UsbDeviceAddress address;
  final UsbPlatform _platform;

  UsbOpenResult? _open;
  String? _lastPath;
  bool _closed = false;

  /// Finds the platform path for our [address] by enumerating devices and
  /// matching VID + PID. Serial matching is deferred to [open] so a serial
  /// mismatch surfaces as [UsbIdentityMismatchException] (richer diagnostics)
  /// rather than a generic [UsbDeviceDisappearedException].
  Future<String?> _resolvePath() async {
    final filter = UsbEnumerateFilter(
      vendorId: address.isZebra ? UsbDeviceAddress.zebraVendorId : null,
      includeDescriptorStrings: true,
    );
    final records = await _platform.enumerate(filter);
    for (final r in records) {
      if (r.vendorId == address.vendorId && r.productId == address.productId) {
        return r.path;
      }
    }
    return null;
  }

  UsbConnection(this.address, {super.config}) : _platform = _defaultPlatform();

  /// Test seam — production code should use the default constructor.
  @visibleForTesting
  UsbConnection.withPlatform(this.address, this._platform, {super.config});

  @override
  bool get isConnected => _open != null && !_closed;

  @override
  Future<void> open() async {
    if (!await _platform.isSupported()) {
      throw UsbUnsupportedOnPlatformException();
    }

    // Resolve the stable [UsbDeviceAddress] to the platform's current opaque
    // path (which may change across plug events). If no match, the device is
    // not currently attached.
    final matchPath = await _resolvePath();
    if (matchPath == null) {
      throw UsbDeviceDisappearedException(
        'No attached USB device matches $address',
      );
    }

    if (!await _platform.hasPermission(matchPath)) {
      final granted = await _platform.requestPermission(matchPath);
      if (!granted) {
        throw UsbPermissionDeniedException(
          'Permission not granted for $address',
        );
      }
    }

    final result = await _platform.openForFfi(matchPath);
    _lastPath = matchPath;

    // Identity check: if we saved a serial, the actual device descriptor must match.
    final expected = address.serialNumber;
    final actual = result.serialNumber;
    if (expected != null && actual != null && expected != actual) {
      // Clean up the native-side state before throwing.
      try {
        await _platform.closeHandle(handleId: result.platformHandle);
      } catch (_) {}
      try {
        await _platform.closeAfterFfi(matchPath);
      } catch (_) {}
      throw UsbIdentityMismatchException(
        expectedSerial: expected,
        actualSerial: actual,
      );
    }

    _open = result;
    _closed = false;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final snapshot = _open;
    final pathSnapshot = _lastPath;
    _open = null;
    _lastPath = null;
    if (snapshot != null) {
      // Best-effort cleanup — swallow errors since we're already tearing down.
      try {
        await _platform.closeHandle(handleId: snapshot.platformHandle);
      } catch (_) {}
      if (pathSnapshot != null) {
        try {
          await _platform.closeAfterFfi(pathSnapshot);
        } catch (_) {}
      }
    }
  }

  @override
  Future<int> bytesAvailable() async {
    // libusb bulk endpoints aren't peek-able. The base Connection.waitForData
    // polls read() directly, so we can safely return 0 here to force a poll.
    return 0;
  }

  @override
  Future<Uint8List?> read() async {
    if (!isConnected) return null;
    final handle = _open!;
    try {
      final data = await _platform.readBytes(
        handleId: handle.platformHandle,
        maxBytes: handle.wMaxPacketSizeOut > 0 ? handle.wMaxPacketSizeOut : 512,
        timeoutMs: config.usbBulkTimeoutMs,
      );
      return data.isEmpty ? null : data;
    } on UsbDeviceUnpluggedException {
      await close();
      rethrow;
    }
  }

  @override
  Future<void> writeRaw(Uint8List data) async {
    if (!isConnected) throw ConnectionClosedException();
    final handle = _open!;
    var retries = 0;
    while (true) {
      try {
        await _platform.writeBytes(
          handleId: handle.platformHandle,
          data: data,
          timeoutMs: config.usbBulkTimeoutMs,
        );
        return;
      } on UsbTransferStalledException {
        if (retries >= config.usbStallRetries) rethrow;
        retries++;
        try {
          await _platform.clearHalt(
            handleId: handle.platformHandle,
            endpoint: handle.bulkOutEndpoint,
          );
        } catch (_) {
          // clear_halt failure is unusual but non-fatal; let the retry surface it.
        }
      } on UsbDeviceUnpluggedException {
        await close();
        rethrow;
      }
    }
  }

  @override
  String get connectionDescription {
    final vid = address.vendorId.toRadixString(16).toUpperCase();
    final pid = address.productId.toRadixString(16).toUpperCase();
    return 'USB:$vid:$pid:${address.serialNumber ?? "?"}';
  }

  /// Lazy-initialised process-singleton composite platform.
  /// Tests short-circuit via [UsbConnection.withPlatform].
  static UsbPlatform _defaultPlatform() =>
      _sharedPlatform ??= UsbPlatformComposite();

  static UsbPlatform? _sharedPlatform;
}
