import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/exceptions/connection_exception.dart';

void main() {
  group('Usb exception hierarchy', () {
    test('UsbConnectionException extends ConnectionException', () {
      final e = UsbConnectionException('oops');
      expect(e, isA<ConnectionException>());
      expect(e.message, 'oops');
    });
    test('toString includes class name and message', () {
      expect(UsbConnectionException('x').toString(), contains('x'));
    });
    test('UsbLibLoadException', () {
      final e = UsbLibLoadException('libusb not found');
      expect(e, isA<UsbConnectionException>());
      expect(e.message, contains('libusb'));
    });
    test('UsbLibLoadException default message', () {
      expect(UsbLibLoadException().message, contains('libusb'));
    });
    test('UsbUnsupportedOnPlatformException', () {
      expect(
        UsbUnsupportedOnPlatformException(),
        isA<UsbConnectionException>(),
      );
    });
    test('UsbPermissionDeniedException', () {
      expect(
        UsbPermissionDeniedException('denied'),
        isA<UsbConnectionException>(),
      );
    });
    test('UsbPermissionRequestCancelledException', () {
      expect(
        UsbPermissionRequestCancelledException(),
        isA<UsbConnectionException>(),
      );
    });
    test('UsbDeviceDisappearedException', () {
      expect(UsbDeviceDisappearedException(), isA<UsbConnectionException>());
    });
    test('UsbDeviceBusyException carries remediation', () {
      final e = UsbDeviceBusyException('busy', remediation: 'rebind');
      expect(e.remediation, 'rebind');
      expect(e, isA<UsbConnectionException>());
    });
    test('UsbDeviceBusyException without remediation', () {
      final e = UsbDeviceBusyException('busy');
      expect(e.remediation, isNull);
    });
    test('UsbInterfaceNotFoundException', () {
      expect(UsbInterfaceNotFoundException(), isA<UsbConnectionException>());
    });
    test('UsbIdentityMismatchException carries expected + actual', () {
      final e = UsbIdentityMismatchException(
        expectedSerial: 'A',
        actualSerial: 'B',
      );
      expect(e.expectedSerial, 'A');
      expect(e.actualSerial, 'B');
      expect(e.message, contains('A'));
      expect(e.message, contains('B'));
    });
    test('UsbIdentityMismatchException with custom message', () {
      final e = UsbIdentityMismatchException(
        message: 'custom',
        expectedSerial: 'A',
      );
      expect(e.message, 'custom');
    });
    test('UsbTransferTimeoutException extends ConnectionTimeoutException', () {
      final e = UsbTransferTimeoutException(5000);
      expect(e, isA<ConnectionTimeoutException>());
      expect(e.timeoutMs, 5000);
      expect(e.message, contains('5000'));
    });
    test('UsbTransferStalledException', () {
      expect(UsbTransferStalledException(), isA<UsbConnectionException>());
    });
    test('UsbDeviceUnpluggedException', () {
      expect(UsbDeviceUnpluggedException(), isA<UsbConnectionException>());
    });
  });
}
