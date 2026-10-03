import 'dart:io';
import 'dart:typed_data';

import '../exceptions/connection_exception.dart';
import 'usb_messages.g.dart';
import 'usb_platform.dart';
import 'usb_platform_channel.dart';
import 'usb_platform_ffi.dart';

/// Default [UsbPlatform] for production use.
///
/// Routes lifecycle (enumerate / permission / openForFfi / closeAfterFfi)
/// through [UsbPlatformChannel] (Pigeon) and I/O through libusb FFI via
/// [UsbPlatformFfi].
///
/// The composite owns per-connection handles: [openForFfi] asks the channel
/// for device metadata (and Android fd), then tells the FFI layer to open +
/// claim the interface. The returned [UsbOpenResult.platformHandle] is the
/// internal FFI handle ID — subsequent I/O calls route straight to FFI.
class UsbPlatformComposite implements UsbPlatform {
  final UsbPlatformChannel _channel;
  UsbPlatformFfi? _ffi;

  // Per-connection metadata, keyed by the FFI handle id returned to callers.
  final Map<int, _OpenMeta> _openMeta = {};

  UsbPlatformComposite({UsbPlatformChannel? channel})
    : _channel = channel ?? UsbPlatformChannel();

  UsbPlatformFfi _ensureFfi() {
    return _ffi ??= UsbPlatformFfi.load();
  }

  @override
  Future<bool> isSupported() async {
    if (!await _channel.isSupported()) return false;
    try {
      _ensureFfi();
      return true;
    } on UsbConnectionException {
      return false;
    }
  }

  @override
  Future<List<UsbDeviceRecord>> enumerate(UsbEnumerateFilter filter) =>
      _channel.enumerate(filter);

  @override
  Future<bool> hasPermission(String path) => _channel.hasPermission(path);

  @override
  Future<bool> requestPermission(String path) =>
      _channel.requestPermission(path);

  @override
  Future<UsbOpenResult> openForFfi(String path) async {
    final native = await _channel.openForFfi(path);
    final ffi = _ensureFfi();

    final ffiHandleId = ffi.openAndClaim(
      vendorId: native.vendorId,
      productId: native.productId,
      serial: native.serialNumber,
      interfaceNumber: native.claimedInterfaceNumber,
      androidFd: Platform.isAndroid ? native.platformHandle : null,
    );

    _openMeta[ffiHandleId] = _OpenMeta(
      nativePath: path,
      interfaceNumber: native.claimedInterfaceNumber,
      bulkIn: native.bulkInEndpoint,
      bulkOut: native.bulkOutEndpoint,
    );

    // Swap in the FFI handle id so subsequent UsbPlatform I/O calls reach us.
    return UsbOpenResult(
      platformHandle: ffiHandleId,
      vendorId: native.vendorId,
      productId: native.productId,
      serialNumber: native.serialNumber,
      claimedInterfaceNumber: native.claimedInterfaceNumber,
      bulkInEndpoint: native.bulkInEndpoint,
      bulkOutEndpoint: native.bulkOutEndpoint,
      wMaxPacketSizeOut: native.wMaxPacketSizeOut,
    );
  }

  @override
  Future<void> closeAfterFfi(String path) async {
    await _channel.closeAfterFfi(path);
  }

  @override
  Future<void> writeBytes({
    required int handleId,
    required Uint8List data,
    required int timeoutMs,
  }) {
    final meta = _openMeta[handleId];
    if (meta == null) {
      throw ConnectionClosedException('Unknown handle $handleId');
    }
    return _ensureFfi().writeBytes(
      handleId: handleId,
      endpoint: meta.bulkOut,
      data: data,
      timeoutMs: timeoutMs,
    );
  }

  @override
  Future<Uint8List> readBytes({
    required int handleId,
    required int maxBytes,
    required int timeoutMs,
  }) {
    final meta = _openMeta[handleId];
    if (meta == null) {
      throw ConnectionClosedException('Unknown handle $handleId');
    }
    return _ensureFfi().readBytes(
      handleId: handleId,
      endpoint: meta.bulkIn,
      maxBytes: maxBytes,
      timeoutMs: timeoutMs,
    );
  }

  @override
  Future<void> clearHalt({required int handleId, required int endpoint}) =>
      _ensureFfi().clearHalt(handleId: handleId, endpoint: endpoint);

  @override
  Future<void> resetDevice({required int handleId}) =>
      _ensureFfi().resetDevice(handleId: handleId);

  @override
  Future<String?> readStringDescriptor({
    required int handleId,
    required int index,
  }) => _ensureFfi().readStringDescriptor(handleId: handleId, index: index);

  @override
  Future<void> closeHandle({required int handleId}) async {
    final meta = _openMeta.remove(handleId);
    if (meta != null) {
      await _ensureFfi().closeHandle(
        handleId: handleId,
        interfaceNumber: meta.interfaceNumber,
      );
    }
  }
}

class _OpenMeta {
  final String nativePath;
  final int interfaceNumber;
  final int bulkIn;
  final int bulkOut;
  _OpenMeta({
    required this.nativePath,
    required this.interfaceNumber,
    required this.bulkIn,
    required this.bulkOut,
  });
}
