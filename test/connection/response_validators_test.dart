import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('ResponseValidators.sgd', () {
    final validator = ResponseValidators.sgd();

    test('complete with quoted string', () {
      expect(validator(Uint8List.fromList('"value"'.codeUnits)), true);
    });

    test('incomplete with only opening quote', () {
      expect(validator(Uint8List.fromList('"val'.codeUnits)), false);
    });

    test('incomplete when empty', () {
      expect(validator(Uint8List(0)), false);
    });

    test('incomplete with single byte', () {
      expect(validator(Uint8List.fromList([0x22])), false);
    });

    test('complete with empty quoted string', () {
      expect(validator(Uint8List.fromList('""'.codeUnits)), true);
    });
  });

  group('ResponseValidators.json', () {
    final validator = ResponseValidators.json();

    test('complete with simple object', () {
      expect(validator(Uint8List.fromList('{"k":"v"}'.codeUnits)), true);
    });

    test('complete with nested objects', () {
      expect(
          validator(Uint8List.fromList('{"a":{"b":1}}'.codeUnits)), true);
    });

    test('incomplete with partial object', () {
      expect(validator(Uint8List.fromList('{"k":'.codeUnits)), false);
    });

    test('incomplete when empty', () {
      expect(validator(Uint8List(0)), false);
    });

    test('incomplete with no opening brace', () {
      expect(validator(Uint8List.fromList('hello'.codeUnits)), false);
    });
  });

  group('ResponseValidators.status', () {
    final validator = ResponseValidators.status();

    test('complete with 3 ETX bytes', () {
      expect(validator(Uint8List.fromList([0x41, 0x03, 0x42, 0x03, 0x43, 0x03])), true);
    });

    test('incomplete with 2 ETX bytes', () {
      expect(validator(Uint8List.fromList([0x41, 0x03, 0x42, 0x03])), false);
    });

    test('incomplete with 0 ETX bytes', () {
      expect(validator(Uint8List.fromList([0x41, 0x42, 0x43])), false);
    });

    test('complete with exactly 3 consecutive ETX', () {
      expect(validator(Uint8List.fromList([0x03, 0x03, 0x03])), true);
    });
  });

  group('ResponseValidators.multiline', () {
    test('complete with expected newline count', () {
      final validator = ResponseValidators.multiline(3);
      expect(validator(Uint8List.fromList('a\nb\nc\n'.codeUnits)), true);
    });

    test('incomplete with fewer newlines', () {
      final validator = ResponseValidators.multiline(3);
      expect(validator(Uint8List.fromList('a\nb\n'.codeUnits)), false);
    });

    test('complete with zero expected', () {
      final validator = ResponseValidators.multiline(0);
      expect(validator(Uint8List.fromList('data'.codeUnits)), true);
    });
  });

  group('ResponseValidators.endsWith', () {
    test('matches suffix', () {
      final validator = ResponseValidators.endsWith([0x0D, 0x0A]);
      expect(validator(Uint8List.fromList([0x41, 0x0D, 0x0A])), true);
    });

    test('does not match different suffix', () {
      final validator = ResponseValidators.endsWith([0x0D, 0x0A]);
      expect(validator(Uint8List.fromList([0x41, 0x0A, 0x0D])), false);
    });

    test('too short', () {
      final validator = ResponseValidators.endsWith([0x0D, 0x0A]);
      expect(validator(Uint8List.fromList([0x0A])), false);
    });
  });
}
