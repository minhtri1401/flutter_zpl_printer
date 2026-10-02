import 'dart:convert';
import 'dart:io';
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

    test('crc16 of empty data is the XMODEM initial value', () {
      expect(Z64Compressor.crc16(Uint8List(0)), 0x0000);
    });

    test('crc16 matches the CRC-16/XMODEM check value', () {
      // Standard check vector; flutter_zpl_generator documents the same.
      expect(Z64Compressor.crc16(ascii.encode('123456789')), 0x31C3);
    });

    test('CRC trailer is computed over the Base64 text', () {
      final data = Uint8List.fromList(List.generate(500, (i) => i % 7));

      final parts = Z64Compressor.compress(data).split(':');
      final b64 = parts[2];
      final crc = int.parse(parts[3], radix: 16);

      expect(crc, Z64Compressor.crc16(ascii.encode(b64)));
      expect(crc, isNot(Z64Compressor.crc16(data)));
      expect(zlib.decode(base64Decode(b64)), data); // body round-trips
    });
  });
}
