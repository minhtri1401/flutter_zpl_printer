import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('Z64Compressor', () {
    test('compress returns Z64 formatted string', () {
      final data = Uint8List.fromList(List.filled(100, 0xFF));

      final result = Z64Compressor.compress(data);

      expect(result, startsWith(':Z64:'));
      // Format: :Z64:{base64}:{crc16}
      final parts = result.split(':');
      expect(parts.length, 4); // ['', 'Z64', '{base64}', '{crc}']
      // CRC is 4 hex chars
      expect(parts[3].length, 4);
    });

    test('compressed output is smaller than hex encoding', () {
      // 1000 bytes of repetitive data -> should compress well
      final data = Uint8List.fromList(List.filled(1000, 0xAA));

      final compressed = Z64Compressor.compress(data);
      final hexSize = data.length * 2; // hex encoding = 2 chars per byte

      expect(compressed.length, lessThan(hexSize));
    });

    test('crc16 produces consistent results', () {
      final data = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);

      final crc1 = Z64Compressor.crc16(data);
      final crc2 = Z64Compressor.crc16(data);

      expect(crc1, crc2);
      expect(crc1, isNonZero);
    });

    test('crc16 is different for different data', () {
      final data1 = Uint8List.fromList([0x01, 0x02]);
      final data2 = Uint8List.fromList([0x03, 0x04]);

      expect(Z64Compressor.crc16(data1), isNot(Z64Compressor.crc16(data2)));
    });

    test('crc16 of empty data returns known value', () {
      final crc = Z64Compressor.crc16(Uint8List(0));
      expect(crc, 0xFFFF); // CRC-CCITT initial value with no data
    });
  });
}
