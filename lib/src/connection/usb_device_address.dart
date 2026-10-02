/// Stable USB-device identifier encoded as `usb://<vid>:<pid>[/<serial>]`.
///
/// Stored verbatim in [DiscoveredPrinter.address] and in the consumer app's
/// saved-printer store, so the string form round-trips through persistence.
class UsbDeviceAddress {
  final int vendorId;
  final int productId;
  final String? serialNumber;

  const UsbDeviceAddress({
    required this.vendorId,
    required this.productId,
    this.serialNumber,
  });

  /// Parses `usb://0A5F:0027[/SERIAL]`. Hex is case-insensitive.
  /// Throws [FormatException] on anything else.
  factory UsbDeviceAddress.parse(String address) {
    final match = _pattern.firstMatch(address);
    if (match == null) {
      throw FormatException('Not a usb:// address', address);
    }
    return UsbDeviceAddress(
      vendorId: int.parse(match.group(1)!, radix: 16),
      productId: int.parse(match.group(2)!, radix: 16),
      serialNumber: match.group(3),
    );
  }

  /// Canonical encoded form. VID/PID are zero-padded to 4 uppercase hex digits.
  String encode() {
    final vid = vendorId.toRadixString(16).toUpperCase().padLeft(4, '0');
    final pid = productId.toRadixString(16).toUpperCase().padLeft(4, '0');
    return serialNumber == null ? 'usb://$vid:$pid' : 'usb://$vid:$pid/$serialNumber';
  }

  /// Zebra Technologies Corporation's USB-IF-registered vendor ID.
  static const int zebraVendorId = 0x0A5F;

  bool get isZebra => vendorId == zebraVendorId;

  static final RegExp _pattern = RegExp(
    r'^usb://([0-9A-Fa-f]{1,4}):([0-9A-Fa-f]{1,4})(?:/(.+))?$',
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsbDeviceAddress &&
          other.vendorId == vendorId &&
          other.productId == productId &&
          other.serialNumber == serialNumber;

  @override
  int get hashCode => Object.hash(vendorId, productId, serialNumber);

  @override
  String toString() => encode();
}
