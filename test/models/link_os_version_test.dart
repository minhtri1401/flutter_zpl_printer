import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('LinkOsVersion.parse', () {
    test('parses "V3.1.0"', () {
      final v = LinkOsVersion.parse('V3.1.0');
      expect(v, isNotNull);
      expect(v!.major, 3);
      expect(v.minor, 1);
      expect(v.micro, 0);
    });

    test('parses "3.2.1" without V prefix', () {
      final v = LinkOsVersion.parse('3.2.1');
      expect(v, isNotNull);
      expect(v!.major, 3);
      expect(v.minor, 2);
      expect(v.micro, 1);
    });

    test('parses "v2.0" lowercase prefix, no micro', () {
      final v = LinkOsVersion.parse('v2.0');
      expect(v, isNotNull);
      expect(v!.major, 2);
      expect(v.minor, 0);
      expect(v.micro, 0);
    });

    test('parses "5" major only', () {
      final v = LinkOsVersion.parse('5');
      expect(v, isNotNull);
      expect(v!.major, 5);
      expect(v.minor, 0);
    });

    test('returns null for empty string', () {
      expect(LinkOsVersion.parse(''), isNull);
    });

    test('returns null for non-numeric', () {
      expect(LinkOsVersion.parse('abc'), isNull);
    });
  });

  group('LinkOsVersion.supports', () {
    test('3.1 supports 2.0', () {
      const v = LinkOsVersion(major: 3, minor: 1);
      expect(v.supports(2, 0), true);
    });

    test('2.0 does not support 3.0', () {
      const v = LinkOsVersion(major: 2, minor: 0);
      expect(v.supports(3, 0), false);
    });

    test('2.1 supports 2.1 (exact match)', () {
      const v = LinkOsVersion(major: 2, minor: 1);
      expect(v.supports(2, 1), true);
    });

    test('2.0 does not support 2.1', () {
      const v = LinkOsVersion(major: 2, minor: 0);
      expect(v.supports(2, 1), false);
    });
  });

  group('LinkOsVersion.isLinkOs', () {
    test('returns true for valid version', () {
      const v = LinkOsVersion(major: 3, minor: 0);
      expect(v.isLinkOs, true);
    });
  });
}
