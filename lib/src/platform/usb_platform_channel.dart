import 'package:flutter/services.dart';

import '../exceptions/connection_exception.dart';
import 'usb_messages.g.dart';

/// Translates a [PlatformException] raised by the native HostApi into the
/// typed `Usb*Exception` from the flutter_zpl_printer exception hierarchy.
///
/// Error-code contract mirrors USB transport spec §3.2. Unknown codes never
/// silently pass — they surface as [UsbConnectionException] with the original
/// [PlatformException] preserved in `cause`.
Never throwAsTyped(PlatformException e) {
  switch (e.code) {
    case 'USB_UNSUPPORTED':
      throw UsbUnsupportedOnPlatformException(e.message);
    case 'USB_LIB_LOAD_FAILED':
      throw UsbLibLoadException(e.message);
    case 'USB_PERMISSION_DENIED':
      throw UsbPermissionDeniedException(e.message);
    case 'USB_PERMISSION_CANCELLED':
      throw UsbPermissionRequestCancelledException(e.message);
    case 'USB_DEVICE_NOT_FOUND':
    case 'USB_DEVICE_DISAPPEARED':
      throw UsbDeviceDisappearedException(e.message);
    case 'USB_DEVICE_BUSY':
      throw UsbDeviceBusyException(e.message ?? 'USB device busy');
    case 'USB_DRIVER_BOUND_TO_SPOOLER':
      throw UsbDeviceBusyException(
        e.message ?? 'Device claimed by the Windows print spooler',
        remediation:
            'Device is bound to the Windows print spooler driver. '
            'Rebind to WinUSB (via Zadig) to use direct USB access, '
            'or print via the OS print queue.',
      );
    case 'USB_INTERFACE_NOT_FOUND':
      throw UsbInterfaceNotFoundException(e.message);
    case 'USB_IDENTITY_MISMATCH':
      final details = e.details is Map ? e.details as Map : const {};
      throw UsbIdentityMismatchException(
        expectedSerial: details['expected'] as String?,
        actualSerial: details['actual'] as String?,
        message: e.message,
      );
    default:
      throw UsbConnectionException(
        e.message == null ? 'USB error: ${e.code}' : '${e.message} (${e.code})',
        e,
      );
  }
}

/// Wrapper around the Pigeon-generated [UsbHostApi] that catches
/// [PlatformException]s and rethrows typed exceptions.
///
/// Implements the lifecycle half of [UsbPlatform]. I/O methods live in
/// [UsbPlatformFfi] (Task 18) — they are combined via a composite at runtime.
class UsbPlatformChannel {
  final UsbHostApi api;
  UsbPlatformChannel({UsbHostApi? api}) : api = api ?? UsbHostApi();

  Future<bool> isSupported() async {
    try {
      return await api.isSupported();
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }

  Future<List<UsbDeviceRecord>> enumerate(UsbEnumerateFilter filter) async {
    try {
      return await api.enumerate(filter);
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }

  Future<bool> hasPermission(String path) async {
    try {
      return await api.hasPermission(path);
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }

  Future<bool> requestPermission(String path) async {
    try {
      return await api.requestPermission(path);
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }

  Future<UsbOpenResult> openForFfi(String path) async {
    try {
      return await api.openForFfi(path);
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }

  Future<void> closeAfterFfi(String path) async {
    try {
      await api.closeAfterFfi(path);
    } on PlatformException catch (e) {
      throwAsTyped(e);
    }
  }
}
