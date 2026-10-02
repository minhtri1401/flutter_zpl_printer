import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  group('Connection chunked write', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxChunkSize: 4,
          interChunkDelayMs: 0,
        ),
      );
      conn.open();
    });

    test('splits data into chunks of maxChunkSize', () async {
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      await conn.write(data);

      expect(conn.writtenData.length, 3);
      expect(conn.writtenData[0], [1, 2, 3, 4]);
      expect(conn.writtenData[1], [5, 6, 7, 8]);
      expect(conn.writtenData[2], [9, 10]);
    });

    test('single chunk when data fits in maxChunkSize', () async {
      final data = Uint8List.fromList([1, 2, 3]);
      await conn.write(data);

      expect(conn.writtenData.length, 1);
      expect(conn.writtenData[0], [1, 2, 3]);
    });

    test('exact chunk boundary', () async {
      final data = Uint8List.fromList([1, 2, 3, 4]);
      await conn.write(data);

      expect(conn.writtenData.length, 1);
      expect(conn.writtenData[0], [1, 2, 3, 4]);
    });

    test('throws ConnectionClosedException when not connected', () async {
      final disconnected = MockConnection();
      final data = Uint8List.fromList([1, 2]);

      expect(
        () => disconnected.write(data),
        throwsA(isA<ConnectionClosedException>()),
      );
    });
  });

  group('Connection sendAndWaitForResponse', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          maxChunkSize: 1024,
          interChunkDelayMs: 0,
        ),
      );
      conn.open();
    });

    test('writes data and returns response', () async {
      conn.queueStringResponse('OK');

      final response = await conn.sendAndWaitForResponse(
        Uint8List.fromList('test'.codeUnits),
      );

      expect(String.fromCharCodes(response), 'OK');
      expect(conn.allWrittenString, 'test');
    });

    test('returns empty bytes when no response', () async {
      final response = await conn.sendAndWaitForResponse(
        Uint8List.fromList('test'.codeUnits),
      );

      expect(response.isEmpty, true);
    });

    test('stops reading when endOfResponseMarker found', () async {
      conn.queueStringResponse('partial...\r\nEND\r\n');

      final response = await conn.sendAndWaitForResponse(
        Uint8List.fromList('cmd'.codeUnits),
        endOfResponseMarker: 'END',
      );

      expect(String.fromCharCodes(response).contains('END'), true);
    });
  });

  group('Connection sendAndWaitForValidResponse', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          maxChunkSize: 1024,
          interChunkDelayMs: 0,
        ),
      );
      conn.open();
    });

    test('returns response when validator passes', () async {
      // SGD-style quoted response
      conn.queueStringResponse('"ZQ620"');

      final response = await conn.sendAndWaitForValidResponse(
        Uint8List.fromList('cmd'.codeUnits),
        validator: (data) =>
            data.length >= 2 && data.first == 0x22 && data.last == 0x22,
      );

      expect(String.fromCharCodes(response), '"ZQ620"');
    });
  });
}
