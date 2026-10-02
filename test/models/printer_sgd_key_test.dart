import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('PrinterSgdKey', () {
    test('every enum value has a unique SGD string', () {
      final seen = <String, PrinterSgdKey>{};
      for (final key in PrinterSgdKey.values) {
        final prior = seen[key.value];
        expect(prior, isNull,
            reason:
                'Duplicate SGD value "${key.value}" on ${key.name} and ${prior?.name}');
        seen[key.value] = key;
      }
    });

    test('every enum value conforms to SGD naming (lowercase dotted)', () {
      final pattern = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$');
      for (final key in PrinterSgdKey.values) {
        expect(pattern.hasMatch(key.value), isTrue,
            reason: '${key.name} has malformed SGD value "${key.value}"');
      }
    });

    test('every enum value is assigned a category', () {
      // Compile-time constraint — this just asserts the non-nullability
      // holds and the enum wiring in the constructor didn't drift.
      for (final key in PrinterSgdKey.values) {
        expect(key.category, isA<SgdCategory>());
      }
    });

    test('spot-check: usbConnected maps to "usb.connected"', () {
      expect(PrinterSgdKey.usbConnected.value, 'usb.connected');
      expect(PrinterSgdKey.usbConnected.category, SgdCategory.usb);
    });

    test('spot-check: deviceReset is categorised as an action', () {
      expect(PrinterSgdKey.deviceReset.value, 'device.reset');
      expect(PrinterSgdKey.deviceReset.category, SgdCategory.action);
    });
  });
}
