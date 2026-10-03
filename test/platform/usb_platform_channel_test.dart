// ignore_for_file: dead_code
// `throwAsTyped` returns `Never`, so analyzer flags the post-catch fail()
// lines — kept as guards against accidental regressions where a code stops
// throwing.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/exceptions/connection_exception.dart';
import 'package:flutter_zpl_printer/src/platform/usb_platform_channel.dart';

void main() {
  group('throwAsTyped — PlatformException → typed exception', () {
    test('USB_UNSUPPORTED → UsbUnsupportedOnPlatformException', () {
      expect(
        () => throwAsTyped(
          PlatformException(code: 'USB_UNSUPPORTED', message: 'iOS'),
        ),
        throwsA(isA<UsbUnsupportedOnPlatformException>()),
      );
    });

    test('USB_LIB_LOAD_FAILED → UsbLibLoadException', () {
      expect(
        () => throwAsTyped(
          PlatformException(code: 'USB_LIB_LOAD_FAILED', message: 'no .so'),
        ),
        throwsA(isA<UsbLibLoadException>()),
      );
    });

    test('USB_PERMISSION_DENIED → UsbPermissionDeniedException', () {
      expect(
        () => throwAsTyped(PlatformException(code: 'USB_PERMISSION_DENIED')),
        throwsA(isA<UsbPermissionDeniedException>()),
      );
    });

    test(
      'USB_PERMISSION_CANCELLED → UsbPermissionRequestCancelledException',
      () {
        expect(
          () =>
              throwAsTyped(PlatformException(code: 'USB_PERMISSION_CANCELLED')),
          throwsA(isA<UsbPermissionRequestCancelledException>()),
        );
      },
    );

    test('USB_DEVICE_NOT_FOUND → UsbDeviceDisappearedException', () {
      expect(
        () => throwAsTyped(PlatformException(code: 'USB_DEVICE_NOT_FOUND')),
        throwsA(isA<UsbDeviceDisappearedException>()),
      );
    });

    test('USB_DEVICE_DISAPPEARED → UsbDeviceDisappearedException', () {
      expect(
        () => throwAsTyped(PlatformException(code: 'USB_DEVICE_DISAPPEARED')),
        throwsA(isA<UsbDeviceDisappearedException>()),
      );
    });

    test('USB_DEVICE_BUSY → UsbDeviceBusyException (no remediation)', () {
      try {
        throwAsTyped(
          PlatformException(code: 'USB_DEVICE_BUSY', message: 'busy'),
        );
      } on UsbDeviceBusyException catch (e) {
        expect(e.remediation, isNull);
        return;
      }
      fail('should have thrown UsbDeviceBusyException');
    });

    test(
      'USB_DRIVER_BOUND_TO_SPOOLER → UsbDeviceBusyException with remediation',
      () {
        try {
          throwAsTyped(
            PlatformException(
              code: 'USB_DRIVER_BOUND_TO_SPOOLER',
              message: 'bound',
            ),
          );
        } on UsbDeviceBusyException catch (e) {
          expect(e.remediation, isNotNull);
          expect(e.remediation, contains('WinUSB'));
          return;
        }
        fail('should have thrown UsbDeviceBusyException');
      },
    );

    test('USB_INTERFACE_NOT_FOUND → UsbInterfaceNotFoundException', () {
      expect(
        () => throwAsTyped(PlatformException(code: 'USB_INTERFACE_NOT_FOUND')),
        throwsA(isA<UsbInterfaceNotFoundException>()),
      );
    });

    test('USB_IDENTITY_MISMATCH carries expected/actual from details', () {
      try {
        throwAsTyped(
          PlatformException(
            code: 'USB_IDENTITY_MISMATCH',
            details: {'expected': 'A', 'actual': 'B'},
          ),
        );
      } on UsbIdentityMismatchException catch (e) {
        expect(e.expectedSerial, 'A');
        expect(e.actualSerial, 'B');
        return;
      }
      fail('should have thrown UsbIdentityMismatchException');
    });

    test('USB_IDENTITY_MISMATCH with missing details is still typed', () {
      expect(
        () => throwAsTyped(PlatformException(code: 'USB_IDENTITY_MISMATCH')),
        throwsA(isA<UsbIdentityMismatchException>()),
      );
    });

    test('unknown code → UsbConnectionException with cause preserved', () {
      try {
        throwAsTyped(PlatformException(code: 'SOMETHING_ELSE', message: 'x'));
      } on UsbConnectionException catch (e) {
        expect(e.cause, isA<PlatformException>());
        expect(e.message, contains('SOMETHING_ELSE'));
        return;
      }
      fail('should have thrown UsbConnectionException');
    });
  });
}
