import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/discovery/zebra_name_parser.dart';

void main() {
  group('extractZebraSerial', () {
    test('returns the clean serial unchanged', () {
      expect(extractZebraSerial('WMZKN210306204'), 'WMZKN210306204');
    });

    test('extracts serial from the raw advanced-discovery blob', () {
      expect(
        extractZebraSerial(
          ':,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24',
        ),
        'WMZKN210306204',
      );
    });

    test('returns null for non-Zebra strings', () {
      expect(extractZebraSerial('Unknown Printer'), isNull);
      expect(extractZebraSerial(null), isNull);
      expect(extractZebraSerial(''), isNull);
    });

    test("doesn't false-match iPhone15A123456789", () {
      expect(extractZebraSerial('iPhone15A123456789'), isNull);
    });
  });

  group('extractZebraModel', () {
    test('parses ZQ mobile with DPI', () {
      expect(
        extractZebraModel(':,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24'),
        'ZQ620-203dpi',
      );
    });

    test('parses ZD desktop with DPI', () {
      expect(
        extractZebraModel('ZBRXXL220000001ZTC ZD421-300dpi ZPL V94.20.00'),
        'ZD421-300dpi',
      );
    });

    test('parses ZT industrial with suffix letter (ZT610R)', () {
      expect(
        extractZebraModel('ZBRZT610000001ZTC ZT610R-600dpi V85.10.02'),
        'ZT610R-600dpi',
      );
    });

    test('parses legacy GK family without DPI suffix', () {
      expect(
        extractZebraModel('ZBRGK420000001ZTC GK420d ZPL V45.11.18'),
        'GK420d',
      );
    });

    test('parses ZTC attached without space', () {
      expect(extractZebraModel('ZBR123ZTCZR638-203dpi V123'), 'ZR638-203dpi');
    });

    test('returns null without ZTC sentinel', () {
      expect(extractZebraModel('WMZKN210306204'), isNull);
      expect(extractZebraModel(null), isNull);
      expect(extractZebraModel(''), isNull);
    });
  });

  group('extractBareZebraModel', () {
    test('strips the DPI suffix (ZQ620-203dpi -> ZQ620)', () {
      expect(
        extractBareZebraModel(
          ':,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24',
        ),
        'ZQ620',
      );
    });

    test('keeps suffix letters (ZT610R-600dpi -> ZT610R)', () {
      expect(
        extractBareZebraModel('ZBRZT610000001ZTC ZT610R-600dpi V85.10.02'),
        'ZT610R',
      );
    });

    test('works for GK family without DPI (GK420d)', () {
      expect(
        extractBareZebraModel('ZBRGK420000001ZTC GK420d ZPL V45.11.18'),
        'GK420d',
      );
    });
  });

  group('friendlyZebraName', () {
    test('returns "MODEL (SERIAL)" when both extractable', () {
      expect(
        friendlyZebraName(':,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24'),
        'ZQ620-203dpi (WMZKN210306204)',
      );
    });

    test('falls back to the serial alone (clean BLE name)', () {
      expect(friendlyZebraName('WMZKN210306204'), 'WMZKN210306204');
    });

    test('falls back to the cleaned raw when no Zebra tokens', () {
      expect(friendlyZebraName(':,.Unknown Device'), 'Unknown Device');
    });

    test('handles null / empty / punctuation-only', () {
      expect(friendlyZebraName(null), 'Zebra Printer');
      expect(friendlyZebraName(''), 'Zebra Printer');
      expect(friendlyZebraName(':,.'), 'Zebra Printer');
    });
  });
}
