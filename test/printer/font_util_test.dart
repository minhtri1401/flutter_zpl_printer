import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  late MockConnection conn;

  setUp(() {
    conn = MockConnection(
      config: const ConnectionConfig(
        maxTimeoutForRead: 200,
        timeToWaitForMoreData: 50,
        interChunkDelayMs: 0,
      ),
    );
    conn.open();
  });

  group('FontUtil', () {
    test('downloadTtfFont sends ~DY with T,T type', () async {
      final fontData = Uint8List.fromList([0x00, 0x01, 0x02]);

      await FontUtil.downloadTtfFont(conn, fontData, 'E:CUSTOM.TTF');

      final written = conn.allWrittenString;
      expect(written, startsWith('~DYE:CUSTOM.TTF,T,T,3,0,:'));
    });

    test('downloadTteFont sends ~DY with T,E type', () async {
      final fontData = Uint8List.fromList([0xAA, 0xBB]);

      await FontUtil.downloadTteFont(conn, fontData, 'E:FONT.TTE');

      final written = conn.allWrittenString;
      expect(written, startsWith('~DYE:FONT.TTE,T,E,2,0,:'));
    });
  });
}
