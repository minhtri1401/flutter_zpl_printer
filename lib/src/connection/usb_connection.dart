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
/// Platform status in this release: not yet tested on hardware on macOS or
/// Android (Android also lacks a bundled `libusb-1.0.so`); fails in testing
/// on Windows (cause not yet confirmed, see the README's "Known issues");
/// not possible on iOS, where [open] throws
/// [UsbUnsupportedOnPlatformException].
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

  /// Bytes pulled off the bulk IN endpoint by [bytesAvailable] and not yet
  /// handed out by [read].
  final BytesBuilder _pending = BytesBuilder(copy: false);

  /// How long [bytesAvailable] waits on the IN endpoint per poll. Kept short
  /// because the base class calls it in a loop until its own deadline.
  static const _pollTimeoutMs = 50;

  /// Bulk IN request size. A multiple of every USB bulk packet size (64 for
  /// full speed, 512 for high speed), so a full packet can't overflow it.
  static const _readChunkBytes = 4096;

  /// Finds the platform path for our [address] by enumerating devices and
  /// matching VID + PID, preferring the device whose serial matches when
  /// [UsbDeviceAddress.serialNumber] is set (two printers of the same model
  /// share VID + PID). If no serial matches, the first VID + PID match is
  /// returned so [open] can surface [UsbIdentityMismatchException] (richer
  /// diagnostics) rather than a generic [UsbDeviceDisappearedException].
  Future<String?> _resolvePath() async {
    final filter = UsbEnumerateFilter(
      vendorId: address.isZebra ? UsbDeviceAddress.zebraVendorId : null,
      includeDescriptorStrings: true,
    );
    final records = await _platform.enumerate(filter);
    final matches = records
        .where(
          (r) =>
              r.vendorId == address.vendorId &&
              r.productId == address.productId,
        )
        .toList();
    if (matches.isEmpty) return null;
    final serial = address.serialNumber;
    if (serial != null) {
      for (final r in matches) {
        if (r.serialNumber == serial) return r.path;
      }
    }
    return matches.first.path;
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
    _pending.clear();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final snapshot = _open;
    final pathSnapshot = _lastPath;
    _open = null;
    _lastPath = null;
    _pending.clear();
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

  /// libusb bulk endpoints can't be peeked, so this does a short read and
  /// buffers whatever arrives. The base class's request/response loop only
  /// calls [read] while this returns > 0.
  @override
  Future<int> bytesAvailable() async {
    if (_pending.isEmpty && isConnected) {
      final data = await _readBulk(_pollTimeoutMs);
      if (data != null) _pending.add(data);
    }
    return _pending.length;
  }

  @override
  Future<Uint8List?> read() async {
    if (_pending.isNotEmpty) return _pending.takeBytes();
    return _readBulk(config.usbBulkTimeoutMs);
  }

  Future<Uint8List?> _readBulk(int timeoutMs) async {
    if (!isConnected) return null;
    final handle = _open!;
    try {
      final data = await _platform.readBytes(
        handleId: handle.platformHandle,
        maxBytes: _readChunkBytes,
        timeoutMs: timeoutMs,
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
