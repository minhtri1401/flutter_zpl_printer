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

  group('FileUtil.listFiles', () {
    test('sends correct ZPL command for E: drive', () async {
      conn.queueStringResponse('E:FORMAT1.ZPL    1234\nE:LOGO.GRF    5678\n');

      final files = await FileUtil.listFiles(conn);

      expect(conn.allWrittenString, '^XA^HWE:*.*^XZ');
      expect(files.length, 2);
      expect(files[0].name, 'E:FORMAT1.ZPL');
      expect(files[0].sizeBytes, 1234);
      expect(files[1].name, 'E:LOGO.GRF');
      expect(files[1].sizeBytes, 5678);
    });

    test('sends correct ZPL command for R: drive', () async {
      conn.queueStringResponse('R:TEMP.ZPL    100\n');

      await FileUtil.listFiles(conn, drive: 'R:');

      expect(conn.allWrittenString, '^XA^HWR:*.*^XZ');
    });

    // Reply copied from the ^HW example in Zebra's ZPL II Programming Guide.
    test('parses ^HW host directory output', () async {
      conn.queueStringResponse(
        '\x02\r\n-DIR R:*.*\r\n'
        '*R:ARIALN1.FNT 49140\r\n'
        '*R:ZEBRA.GRF 8420\r\n'
        '\r\n-794292 bytes free R:RAM\r\n\x03',
      );

      final files = await FileUtil.listFiles(conn, drive: 'R:');

      expect(files.map((f) => f.name), ['R:ARIALN1.FNT', 'R:ZEBRA.GRF']);
      expect(files.map((f) => f.sizeBytes), [49140, 8420]);
    });

    // The format description puts a space after the asterisk.
    test('parses entries with a space after the asterisk', () async {
      conn.queueStringResponse('\x02\r\nDIR E: \r\n* E:FORMAT1.ZPL  1234\r\n\x03');

      final files = await FileUtil.listFiles(conn);

      expect(files.single.name, 'E:FORMAT1.ZPL');
      expect(files.single.sizeBytes, 1234);
    });

    test('handles empty response', () async {
      conn.queueStringResponse('');

      final files = await FileUtil.listFiles(conn);

      expect(files, isEmpty);
    });
  });

  group('FileUtil.deleteFile', () {
    test('sends correct ^ID command', () async {
      await FileUtil.deleteFile(conn, 'E:FORMAT1.ZPL');

      expect(conn.allWrittenString, '^XA^IDE:FORMAT1.ZPL^FS^XZ');
    });
  });

  group('FileUtil.storeFile', () {
    test('sends ~DY command with data', () async {
      final data = Uint8List.fromList([0x01, 0x02, 0x03]);

      await FileUtil.storeFile(conn, 'E:TEST.ZPL', data);

      final written = conn.allWrittenString;
      expect(written, startsWith('~DYE:TEST.ZPL,B,P,3,0,:'));
    });
  });

  group('FileUtil.getStorageInfo', () {
    test('parses free and total bytes', () async {
      conn.queueStringResponse('"123456,654321"');

      final info = await FileUtil.getStorageInfo(conn, 'E:');

      expect(info.drive, 'E:');
      expect(info.freeBytes, 123456);
      expect(info.totalBytes, 654321);
      expect(info.usedPercent, closeTo(0.811, 0.001));
    });
  });

  group('FileUtil.sendFileContents', () {
    test('sends data with progress callback', () async {
      final data = Uint8List(2048);
      final progressCalls = <List<int>>[];

      await FileUtil.sendFileContents(
        conn,
        data,
        onProgress: (sent, total) => progressCalls.add([sent, total]),
      );

      expect(progressCalls.last, [2048, 2048]);
      expect(progressCalls.length, greaterThan(1));
    });
  });
}
