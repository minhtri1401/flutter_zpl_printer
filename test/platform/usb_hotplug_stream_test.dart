import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/platform/usb_hotplug_stream.dart';

void main() {
  group('UsbHotplugEvent.fromMap', () {
    test('attached with serial', () {
      final e = UsbHotplugEvent.fromMap({
        'type': 'attached',
        'vendorId': 0x0A5F,
        'productId': 0x0027,
        'serialNumber': 'XX123',
        'path': '/dev/bus/usb/001/004',
        'timestamp_ms': 1714000000000,
      });
      expect(e.type, UsbHotplugType.attached);
      expect(e.address.vendorId, 0x0A5F);
      expect(e.address.productId, 0x0027);
      expect(e.address.serialNumber, 'XX123');
      expect(e.path, '/dev/bus/usb/001/004');
      expect(e.timestamp.millisecondsSinceEpoch, 1714000000000);
    });

    test('detached without serial', () {
      final e = UsbHotplugEvent.fromMap({
        'type': 'detached',
        'vendorId': 0x0A5F,
        'productId': 0x0027,
        'serialNumber': null,
        'path': 'p',
        'timestamp_ms': 1,
      });
      expect(e.type, UsbHotplugType.detached);
      expect(e.address.serialNumber, isNull);
    });

    test('unknown type throws FormatException', () {
      expect(
        () => UsbHotplugEvent.fromMap({
          'type': 'wat',
          'vendorId': 0,
          'productId': 0,
          'path': '',
          'serialNumber': null,
          'timestamp_ms': 0,
        }),
        throwsFormatException,
      );
    });

    test('missing timestamp_ms throws', () {
      expect(
        () => UsbHotplugEvent.fromMap({
          'type': 'attached',
          'vendorId': 0,
          'productId': 0,
          'path': '',
          'serialNumber': null,
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
