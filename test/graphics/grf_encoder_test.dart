import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:image/image.dart' as img;

void main() {
  group('GrfEncoder', () {
    test('encodes an 8x8 black image to all-ones GRF', () {
      // Create a pure black 8x8 image
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));
      final png = Uint8List.fromList(img.encodePng(image));

      final grf = GrfEncoder.encode(png);

      expect(grf.width, 8);
      expect(grf.height, 8);
      expect(grf.bytesPerRow, 1); // 8 pixels / 8 = 1 byte per row
      expect(grf.totalBytes, 8); // 1 byte * 8 rows
      // All black -> all bits set -> 0xFF per byte
      expect(grf.hexData, 'FF' * 8);
    });

    test('encodes an 8x8 white image to all-zeros GRF', () {
      final image = img.Image(width: 8, height: 8);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      final png = Uint8List.fromList(img.encodePng(image));

      final grf = GrfEncoder.encode(png);

      expect(grf.hexData, '00' * 8);
    });

    test('calculates bytesPerRow correctly for non-byte-aligned width', () {
      // 10 pixels wide -> ceil(10/8) = 2 bytes per row
      final image = img.Image(width: 10, height: 1);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));
      final png = Uint8List.fromList(img.encodePng(image));

      final grf = GrfEncoder.encode(png);

      expect(grf.bytesPerRow, 2);
      // 10 black pixels + 6 padding zeros = 0xFF, 0xC0
      expect(grf.hexData, 'FFC0');
    });

    test('respects threshold parameter', () {
      // Gray at exactly 127 -> should be black with default threshold 128
      final image = img.Image(width: 8, height: 1);
      img.fill(image, color: img.ColorRgb8(127, 127, 127));
      final png = Uint8List.fromList(img.encodePng(image));

      final grfDefault = GrfEncoder.encode(png, threshold: 128);
      expect(grfDefault.hexData, 'FF'); // all black

      // With threshold 1, only pure black pixels are black
      final grfLow = GrfEncoder.encode(png, threshold: 1);
      expect(grfLow.hexData, '00'); // all white (127 >= 1)
    });

    test('resizes image with targetWidth', () {
      final image = img.Image(width: 16, height: 16);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));
      final png = Uint8List.fromList(img.encodePng(image));

      final grf = GrfEncoder.encode(png, targetWidth: 8);

      expect(grf.width, 8);
      expect(grf.height, 8); // aspect ratio preserved
    });

    test('throws on invalid image data', () {
      expect(
        () => GrfEncoder.encode(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('bitmapBytes has correct raw bytes', () {
      final image = img.Image(width: 8, height: 1);
      img.fill(image, color: img.ColorRgb8(0, 0, 0));
      final png = Uint8List.fromList(img.encodePng(image));

      final grf = GrfEncoder.encode(png);

      expect(grf.bitmapBytes.length, 1);
      expect(grf.bitmapBytes[0], 0xFF);
    });
  });
}
