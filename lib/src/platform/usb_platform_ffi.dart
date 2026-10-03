import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../exceptions/connection_exception.dart';
import 'libusb_loader.dart';

/// libusb errno constants (values from libusb.h / spec §4.1).
const int _libusbSuccess = 0;
const int _libusbErrorNoDevice = -4;
const int _libusbErrorBusy = -6;
const int _libusbErrorTimeout = -7;
const int _libusbErrorPipe = -9;
const int _libusbErrorInterrupted = -10;

/// FFI-backed I/O half of the USB platform composite. Lifecycle methods delegate
/// to [UsbPlatformChannel]; only hot-path I/O lives here.
///
/// Thread safety: libusb bulk transfers are synchronous-blocking. For v1 we
/// run them on the Dart main isolate (acceptable for label print jobs of a few
/// KB). A dedicated worker isolate is a v2 optimization — see spec §4.4.
class UsbPlatformFfi {
  final LibusbBindings _lib;
  Pointer<Void> _ctx = nullptr;
  final Map<int, Pointer<Void>> _handles = {};
  int _nextHandleId = 1;

  UsbPlatformFfi._(this._lib);

  /// Loads libusb and initializes the global context. Throws [UsbLibLoadException]
  /// on loader failure; [UsbConnectionException] on libusb_init failure.
  factory UsbPlatformFfi.load() {
    final lib = LibusbBindings.load();
    final inst = UsbPlatformFfi._(lib);
    final ctxOut = calloc<Pointer<Void>>();
    try {
      final rc = lib.init(ctxOut);
      if (rc != _libusbSuccess) {
        throw UsbConnectionException('libusb_init failed (rc=$rc)');
      }
      inst._ctx = ctxOut.value;
    } finally {
      calloc.free(ctxOut);
    }
    return inst;
  }

  /// Opens a device matching (vid, pid, optional serial) and claims [interfaceNumber].
  /// Returns a handle id usable with [writeBytes], [readBytes], etc.
  /// On Android pass [androidFd] (from `UsbDeviceConnection.getFileDescriptor`)
  /// to use `libusb_wrap_sys_device` instead of walking the device list.
  int openAndClaim({
    required int vendorId,
    required int productId,
    String? serial,
    required int interfaceNumber,
    int? androidFd,
  }) {
    final handleOut = calloc<Pointer<Void>>();
    try {
      int rc;
      if (androidFd != null) {
        rc = _lib.wrapSysDevice(_ctx, androidFd, handleOut);
      } else {
        rc = _openByDescriptor(vendorId, productId, serial, handleOut);
      }
      if (rc != _libusbSuccess || handleOut.value == nullptr) {
        throw _mapLibusbError(rc, 'open');
      }
      final handle = handleOut.value;

      // Enable auto-detach of kernel drivers (Linux only; no-op elsewhere).
      _lib.setAutoDetachKernelDriver(handle, 1);

      final claim = _lib.claimInterface(handle, interfaceNumber);
      if (claim != _libusbSuccess) {
        _lib.close(handle);
        throw _mapLibusbError(claim, 'claim_interface');
      }

      final id = _nextHandleId++;
      _handles[id] = handle;
      return id;
    } finally {
      calloc.free(handleOut);
    }
  }

  Future<void> writeBytes({
    required int handleId,
    required int endpoint,
    required Uint8List data,
    required int timeoutMs,
  }) async {
    final handle = _handles[handleId];
    if (handle == null) {
      throw ConnectionClosedException('Invalid handle $handleId');
    }

    final buf = calloc<Uint8>(data.length);
    final transferred = calloc<Int32>();
    try {
      buf.asTypedList(data.length).setAll(0, data);
      final rc = _lib.bulkTransfer(
        handle,
        endpoint,
        buf,
        data.length,
        transferred,
        timeoutMs,
      );
      if (rc != _libusbSuccess) throw _mapLibusbError(rc, 'bulk_transfer OUT');
    } finally {
      calloc.free(buf);
      calloc.free(transferred);
    }
  }

  Future<Uint8List> readBytes({
    required int handleId,
    required int endpoint,
    required int maxBytes,
    required int timeoutMs,
  }) async {
    final handle = _handles[handleId];
    if (handle == null) {
      throw ConnectionClosedException('Invalid handle $handleId');
    }

    final buf = calloc<Uint8>(maxBytes);
    final transferred = calloc<Int32>();
    try {
      final rc = _lib.bulkTransfer(
        handle,
        endpoint,
        buf,
        maxBytes,
        transferred,
        timeoutMs,
      );
      if (rc == _libusbErrorTimeout && transferred.value == 0) {
        return Uint8List(0); // Soft-timeout = no data; caller polls again.
      }
      if (rc != _libusbSuccess) throw _mapLibusbError(rc, 'bulk_transfer IN');
      final count = transferred.value;
      final out = Uint8List(count);
      out.setAll(0, buf.asTypedList(count));
      return out;
    } finally {
      calloc.free(buf);
      calloc.free(transferred);
    }
  }

  Future<void> clearHalt({required int handleId, required int endpoint}) async {
    final handle = _handles[handleId];
    if (handle == null) return;
    final rc = _lib.clearHalt(handle, endpoint);
    if (rc != _libusbSuccess) {
      throw UsbConnectionException('libusb_clear_halt failed (rc=$rc)');
    }
  }

  Future<void> resetDevice({required int handleId}) async {
    final handle = _handles[handleId];
    if (handle == null) return;
    _lib.resetDevice(handle);
  }

  Future<String?> readStringDescriptor({
    required int handleId,
    required int index,
  }) async {
    final handle = _handles[handleId];
    if (handle == null || index == 0) return null;
    const bufSize = 255;
    final buf = calloc<Uint8>(bufSize);
    try {
      final rc = _lib.getStringDescriptorAscii(handle, index, 0, buf, bufSize);
      if (rc <= 0) return null;
      final bytes = buf.asTypedList(rc);
      return String.fromCharCodes(bytes);
    } finally {
      calloc.free(buf);
    }
  }

  /// Releases the interface (best-effort; ignores errors) and closes the handle.
  /// Does NOT call libusb_exit — the context is process-singleton.
  Future<void> closeHandle({
    required int handleId,
    required int interfaceNumber,
  }) async {
    final handle = _handles.remove(handleId);
    if (handle == null) return;
    try {
      _lib.releaseInterface(handle, interfaceNumber);
    } catch (_) {}
    _lib.close(handle);
  }

  /// Walks libusb_get_device_list matching by VID/PID/(optional)serial. Used
  /// on macOS + Windows where native channels don't hand us a fd.
  int _openByDescriptor(
    int vendorId,
    int productId,
    String? serial,
    Pointer<Pointer<Void>> handleOut,
  ) {
    final listOut = calloc<Pointer<Pointer<Void>>>();
    try {
      final count = _lib.getDeviceList(_ctx, listOut);
      if (count < 0) return count;
      try {
        final list = listOut.value;
        for (var i = 0; i < count; i++) {
          final dev = list[i];
          final desc = calloc<DeviceDescriptorStruct>();
          try {
            final descRc = _lib.getDeviceDescriptor(dev, desc);
            if (descRc != _libusbSuccess) continue;
            if (desc.ref.idVendor != vendorId ||
                desc.ref.idProduct != productId) {
              continue;
            }
            // Open to verify serial; skip if mismatch.
            final rc = _lib.open(dev, handleOut);
            if (rc != _libusbSuccess) continue;
            if (serial != null && desc.ref.iSerialNumber != 0) {
              final actual = _readStringFromHandle(
                handleOut.value,
                desc.ref.iSerialNumber,
              );
              if (actual != null && actual != serial) {
                _lib.close(handleOut.value);
                handleOut.value = nullptr;
                continue;
              }
            }
            return _libusbSuccess;
          } finally {
            calloc.free(desc);
          }
        }
        return _libusbErrorNoDevice;
      } finally {
        _lib.freeDeviceList(listOut.value, 1);
      }
    } finally {
      calloc.free(listOut);
    }
  }

  String? _readStringFromHandle(Pointer<Void> handle, int index) {
    const bufSize = 255;
    final buf = calloc<Uint8>(bufSize);
    try {
      final rc = _lib.getStringDescriptorAscii(handle, index, 0, buf, bufSize);
      if (rc <= 0) return null;
      return String.fromCharCodes(buf.asTypedList(rc));
    } finally {
      calloc.free(buf);
    }
  }

  Exception _mapLibusbError(int rc, String op) {
    switch (rc) {
      case _libusbErrorNoDevice:
        // During a transfer the device was open and is now gone: that's an
        // unplug, which UsbConnection handles by closing itself. Before the
        // device is open it simply isn't there.
        return op.startsWith('bulk_transfer')
            ? UsbDeviceUnpluggedException('$op: device unplugged (rc=$rc)')
            : UsbDeviceDisappearedException('$op: device disappeared (rc=$rc)');
      case _libusbErrorBusy:
        return UsbDeviceBusyException('$op: device busy (rc=$rc)');
      case _libusbErrorTimeout:
        return UsbTransferTimeoutException(0, '$op timed out (rc=$rc)');
      case _libusbErrorPipe:
        return UsbTransferStalledException('$op stalled (rc=$rc)');
      case _libusbErrorInterrupted:
        return UsbConnectionException('$op interrupted (rc=$rc)');
      default:
        return UsbConnectionException('$op failed (rc=$rc)');
    }
  }
}
