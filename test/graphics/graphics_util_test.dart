import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:image/image.dart' as img;

import '../mocks/mock_connection.dart';

void main() {
  late MockConnection conn;
  late Uint8List testPng;

  setUp(() {
    conn = MockConnection(
      config: const ConnectionConfig(
        maxTimeoutForRead: 200,
        timeToWaitForMoreData: 50,
        interChunkDelayMs: 0,
      ),
    );
    conn.open();

    // Create a small test PNG
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(0, 0, 0));
    testPng = Uint8List.fromList(img.encodePng(image));
  });

  group('GraphicsUtil.printImage', () {
    test('sends uncompressed hex by default', () async {
      await GraphicsUtil.printImage(conn, testPng);

      final written = conn.allWrittenString;
      expect(written, contains('^GFA,'));
      expect(written, isNot(contains(':Z64:')));
    });

    test('sends ^GF command with compression', () async {
      await GraphicsUtil.printImage(conn, testPng, x: 50, y: 100, useCompression: true);

      final written = conn.allWrittenString;
      expect(written, startsWith('^XA'));
      expect(written, contains('^FO50,100'));
      expect(written, contains('^GFA,'));
      expect(written, contains(':Z64:'));
      expect(written, endsWith('^FS^XZ'));
    });

    test('sends ^GF command without compression', () async {
      await GraphicsUtil.printImage(
        conn,
        testPng,
        useCompression: false,
      );

      final written = conn.allWrittenString;
      expect(written, contains('^GFA,'));
      expect(written, isNot(contains(':Z64:')));
    });
  });

  group('GraphicsUtil.storeImage', () {
    test('sends ~DG command', () async {
      await GraphicsUtil.storeImage(conn, 'R:LOGO.GRF', testPng);

      final written = conn.allWrittenString;
      expect(written, startsWith('~DGR:LOGO.GRF,'));
    });
  });

  group('GraphicsUtil.printStoredImage', () {
    test('sends ^XG command', () async {
      await GraphicsUtil.printStoredImage(
        conn,
        'R:LOGO.GRF',
        x: 10,
        y: 20,
        scaleX: 2,
        scaleY: 2,
      );

      expect(
        conn.allWrittenString,
        '^XA^FO10,20^XGR:LOGO.GRF,2,2^FS^XZ',
      );
    });
  });
}
