import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  group('FormatUtil.getVariableFields', () {
    test('parses fields with numbers only', () {
      const zpl = '^XA^FO50,50^A0N,50,50^FN1^FS^FO50,150^FN2^FS^XZ';
      final fields = FormatUtil.getVariableFields(zpl);

      expect(fields.length, 2);
      expect(fields[0].fieldNumber, 1);
      expect(fields[0].fieldName, isNull);
      expect(fields[1].fieldNumber, 2);
    });

    test('parses fields with names', () {
      const zpl = '^FN1"Name"^FS^FN2"Barcode"^FS';
      final fields = FormatUtil.getVariableFields(zpl);

      expect(fields.length, 2);
      expect(fields[0].fieldName, 'Name');
      expect(fields[1].fieldName, 'Barcode');
    });

    test('deduplicates field numbers', () {
      const zpl = '^FN1"A"^FS^FN1"B"^FS^FN2^FS';
      final fields = FormatUtil.getVariableFields(zpl);

      expect(fields.length, 2);
      expect(fields[0].fieldNumber, 1);
      expect(fields[0].fieldName, 'A'); // first occurrence wins
    });

    test('returns sorted by field number', () {
      const zpl = '^FN3^FS^FN1^FS^FN2^FS';
      final fields = FormatUtil.getVariableFields(zpl);

      expect(fields.map((f) => f.fieldNumber).toList(), [1, 2, 3]);
    });

    test('handles empty ZPL', () {
      expect(FormatUtil.getVariableFields(''), isEmpty);
    });

    test('handles ZPL with no variables', () {
      const zpl = '^XA^FO50,50^A0N,50,50^FDHello^FS^XZ';
      expect(FormatUtil.getVariableFields(zpl), isEmpty);
    });
  });

  group('FormatUtil.printStoredFormat', () {
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

    test('generates correct ZPL with variables', () async {
      await FormatUtil.printStoredFormat(
        conn,
        'E:LABEL.ZPL',
        {1: 'John Doe', 2: '123456'},
      );

      expect(
        conn.allWrittenString,
        '^XA^XFE:LABEL.ZPL^FN1^FDJohn Doe^FS^FN2^FD123456^FS^XZ',
      );
    });

    test('generates correct ZPL with empty variables', () async {
      await FormatUtil.printStoredFormat(conn, 'E:LABEL.ZPL', {});

      expect(conn.allWrittenString, '^XA^XFE:LABEL.ZPL^XZ');
    });
  });

  group('FormatUtil.retrieveFormat', () {
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

    test('sends ^HF command and returns cleaned response', () async {
      conn.queueStringResponse('^XA^FO50,50^FDHello^FS^XZ');

      final result = await FormatUtil.retrieveFormat(conn, 'E:LABEL.ZPL');

      expect(conn.allWrittenString, '^XA^HFE:LABEL.ZPL^FS^XZ');
      expect(result, contains('^FDHello'));
    });
  });
}
