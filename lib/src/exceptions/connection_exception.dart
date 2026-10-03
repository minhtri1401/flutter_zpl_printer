/// Exception hierarchy for connection errors.
///
/// Mirrors SDK's `com.zebra.sdk.comm.ConnectionException`.
class ConnectionException implements Exception {
  final String message;
  final Object? cause;

  ConnectionException(this.message, [this.cause]);

  @override
  String toString() => cause != null
      ? 'ConnectionException: $message ($cause)'
      : 'ConnectionException: $message';
}

class ConnectionTimeoutException extends ConnectionException {
  final int timeoutMs;

  ConnectionTimeoutException(this.timeoutMs, [String? message])
    : super(message ?? 'Connection timed out after ${timeoutMs}ms');
}

class ConnectionClosedException extends ConnectionException {
  ConnectionClosedException([String? message])
    : super(message ?? 'The connection is not open');
}

// ─── USB exception hierarchy ───────────────────────────────────────────────

/// Base class for USB-specific connection errors.
class UsbConnectionException extends ConnectionException {
  UsbConnectionException(super.message, [super.cause]);
}

/// libusb shared library could not be loaded (missing, wrong arch, etc.).
class UsbLibLoadException extends UsbConnectionException {
  UsbLibLoadException([String? message])
    : super(message ?? 'libusb shared library could not be loaded');
}

/// USB is not supported on the current platform (e.g. iOS).
class UsbUnsupportedOnPlatformException extends UsbConnectionException {
  UsbUnsupportedOnPlatformException([String? message])
    : super(message ?? 'USB is not supported on this platform');
}

/// Android: user denied the USB permission dialog, or the device has no
/// pre-granted permission. Desktop: sandbox / driver denied access.
class UsbPermissionDeniedException extends UsbConnectionException {
  UsbPermissionDeniedException([String? message])
    : super(message ?? 'USB permission was denied');
}

/// The user dismissed the Android USB permission dialog without choosing.
class UsbPermissionRequestCancelledException extends UsbConnectionException {
  UsbPermissionRequestCancelledException([String? message])
    : super(message ?? 'USB permission request was cancelled');
}

/// The device was unplugged between enumerate and open, or between open
/// attempts.
class UsbDeviceDisappearedException extends UsbConnectionException {
  UsbDeviceDisappearedException([String? message])
    : super(message ?? 'USB device is no longer attached');
}

/// The device is claimed by another app or driver. On Windows this typically
/// means the ZDesigner/usbprint driver is bound and libusb cannot claim.
/// The [remediation] field carries a user-actionable hint.
class UsbDeviceBusyException extends UsbConnectionException {
  final String? remediation;
  UsbDeviceBusyException(String message, {this.remediation, Object? cause})
    : super(message, cause);
}

/// The device has no printer-class (bInterfaceClass == 0x07) interface.
class UsbInterfaceNotFoundException extends UsbConnectionException {
  UsbInterfaceNotFoundException([String? message])
    : super(message ?? 'No printer-class interface found on USB device');
}

/// The device's iSerialNumber descriptor does not match the serial stored
/// in the [UsbDeviceAddress]. Catches a swapped-printer-at-same-port case.
class UsbIdentityMismatchException extends UsbConnectionException {
  final String? expectedSerial;
  final String? actualSerial;
  UsbIdentityMismatchException({
    this.expectedSerial,
    this.actualSerial,
    String? message,
  }) : super(
         message ??
             'USB device identity mismatch '
                 '(expected: ${expectedSerial ?? "?"}, actual: ${actualSerial ?? "?"})',
       );
}

/// A libusb_bulk_transfer call exceeded its timeout budget.
class UsbTransferTimeoutException extends ConnectionTimeoutException {
  UsbTransferTimeoutException(int timeoutMs, [String? message])
    : super(
        timeoutMs,
        message ?? 'USB transfer timed out after ${timeoutMs}ms',
      );
}

/// The endpoint returned LIBUSB_ERROR_PIPE more times than
/// [ConnectionConfig.usbStallRetries] allows.
class UsbTransferStalledException extends UsbConnectionException {
  UsbTransferStalledException([String? message])
    : super(
        message ?? 'USB endpoint stalled (clear_halt retry budget exhausted)',
      );
}

/// The device was physically unplugged during an active session.
class UsbDeviceUnpluggedException extends UsbConnectionException {
  UsbDeviceUnpluggedException([String? message])
    : super(message ?? 'USB device was unplugged');
}
