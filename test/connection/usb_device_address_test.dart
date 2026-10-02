import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/connection/usb_device_address.dart';

void main() {
  group('UsbDeviceAddress', () {
    test('encode with serial', () {
      final a = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027, serialNumber: 'XX123');
      expect(a.encode(), 'usb://0A5F:0027/XX123');
    });
    test('encode without serial', () {
      final a = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027);
      expect(a.encode(), 'usb://0A5F:0027');
    });
    test('encode pads 1-digit vid/pid', () {
      final a = UsbDeviceAddress(vendorId: 0x5, productId: 0xAF);
      expect(a.encode(), 'usb://0005:00AF');
    });
    test('parse full', () {
      final a = UsbDeviceAddress.parse('usb://0A5F:0027/XX123');
      expect(a.vendorId, 0x0A5F);
      expect(a.productId, 0x0027);
      expect(a.serialNumber, 'XX123');
    });
    test('parse without serial', () {
      final a = UsbDeviceAddress.parse('usb://0A5F:0027');
      expect(a.vendorId, 0x0A5F);
      expect(a.productId, 0x0027);
      expect(a.serialNumber, isNull);
    });
    test('parse lowercase hex', () {
      final a = UsbDeviceAddress.parse('usb://0a5f:0027');
      expect(a.vendorId, 0x0A5F);
    });
    test('parse with non-hex serial', () {
      final a = UsbDeviceAddress.parse('usb://0A5F:0027/XX_ABC-123');
      expect(a.serialNumber, 'XX_ABC-123');
    });
    test('parse wrong scheme throws', () {
      expect(() => UsbDeviceAddress.parse('tcp://1.2.3.4:9100'), throwsFormatException);
    });
    test('parse no vid throws', () {
      expect(() => UsbDeviceAddress.parse('usb://'), throwsFormatException);
    });
    test('parse malformed throws', () {
      expect(() => UsbDeviceAddress.parse('usb://zzz:0027'), throwsFormatException);
    });
    test('isZebra for 0x0A5F', () {
      expect(UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027).isZebra, isTrue);
    });
    test('isZebra false for non-Zebra VID', () {
      expect(UsbDeviceAddress(vendorId: 0x1234, productId: 0x0027).isZebra, isFalse);
    });
    test('zebraVendorId constant', () {
      expect(UsbDeviceAddress.zebraVendorId, 0x0A5F);
    });
    test('equality', () {
      final a = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027, serialNumber: 'S');
      final b = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027, serialNumber: 'S');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
    test('inequality on serial', () {
      final a = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027, serialNumber: 'A');
      final b = UsbDeviceAddress(vendorId: 0x0A5F, productId: 0x0027, serialNumber: 'B');
      expect(a, isNot(equals(b)));
    });
    test('round-trip parse ∘ encode', () {
      const original = 'usb://0A5F:0027/XXYZ';
      final roundTripped = UsbDeviceAddress.parse(original).encode();
      expect(roundTripped, original);
    });
  });
}
