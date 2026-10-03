import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  group('ZebraPrinter', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
    });

    test('connect opens connection and detects language', () async {
      // Queue language detection response
      conn.queueStringResponse('"zpl"');

      final printer = await ZebraPrinter.connect(conn);

      expect(conn.openCalled, true);
      expect(printer.connection.isConnected, true);
    });

    test('printZpl writes encoded bytes', () async {
      conn.queueStringResponse('"zpl"');
      final printer = await ZebraPrinter.connect(conn);
      conn.writtenData.clear();

      await printer.printZpl('^XA^FO50,50^A0N,50,50^FDHello^FS^XZ');

      expect(conn.allWrittenString, '^XA^FO50,50^A0N,50,50^FDHello^FS^XZ');
    });

    test('getLanguage sends correct SGD GET', () async {
      conn.queueStringResponse('"zpl"');
      final printer = await ZebraPrinter.connect(conn);

      final lang = await printer.getLanguage();

      expect(lang, PrinterLanguage.zpl);
    });

    test('getLanguage caches result', () async {
      conn.queueStringResponse('"cpcl"');
      final printer = await ZebraPrinter.connect(conn);

      // Second call should use cached value (no new response queued)
      final lang = await printer.getLanguage();

      expect(lang, PrinterLanguage.cpcl);
    });

    test('getSetting delegates to Sgd.get', () async {
      conn.queueStringResponse('"zpl"');
      final printer = await ZebraPrinter.connect(conn);
      conn.writtenData.clear();

      conn.queueStringResponse('"ZQ620"');
      final name = await printer.getSetting('device.friendly_name');

      expect(name, 'ZQ620');
    });

    test('setSetting delegates to Sgd.set', () async {
      conn.queueStringResponse('"zpl"');
      final printer = await ZebraPrinter.connect(conn);
      conn.writtenData.clear();

      await printer.setSetting('media.type', 'label');

      expect(conn.allWrittenString, '! U1 setvar "media.type" "label"\r\n');
    });

    test('disconnect closes connection', () async {
      conn.queueStringResponse('"zpl"');
      final printer = await ZebraPrinter.connect(conn);

      await printer.disconnect();

      expect(conn.closeCalled, true);
      expect(conn.isConnected, false);
    });
  });

  group('ZebraPrinter ToolsUtil methods', () {
    late MockConnection conn;
    late ZebraPrinter printer;

    setUp(() async {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
      conn.queueStringResponse('"zpl"');
      printer = await ZebraPrinter.connect(conn);
      conn.writtenData.clear();
    });

    test('calibrate sends ~JC', () async {
      await printer.calibrate();
      expect(conn.allWrittenString, '~JC');
    });

    test('restoreDefaults sends ^JUF', () async {
      await printer.restoreDefaults();
      expect(conn.allWrittenString, '^JUF');
    });

    test('printConfigurationLabel sends ~WC', () async {
      await printer.printConfigurationLabel();
      expect(conn.allWrittenString, '~WC');
    });

    test('reset sends SGD device.reset', () async {
      conn.queueStringResponse('"OK"');
      await printer.reset();
      expect(conn.allWrittenString, '! U1 do "device.reset" ""\r\n');
    });

    test('printDirectoryLabel sends ^WD', () async {
      await printer.printDirectoryLabel();
      expect(conn.allWrittenString, '^WD');
    });

    test('resetNetwork sends SGD setvar', () async {
      await printer.resetNetwork();
      expect(
        conn.allWrittenString,
        '! U1 setvar "device.reset_network" ""\r\n',
      );
    });
  });

  group('ZebraPrinter.getMetadata', () {
    late MockConnection conn;
    late ZebraPrinter printer;

    setUp(() async {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
      conn.queueStringResponse('"zpl"');
      printer = await ZebraPrinter.connect(conn);
      conn.writtenData.clear();
    });

    test('getMetadata sends SGD queries for expected keys', () async {
      conn.queueStringResponse('"My Printer"');

      final meta = await printer.getMetadata(
        keys: [PrinterMetadataKey.deviceFriendlyName],
      );

      expect(meta[PrinterMetadataKey.deviceFriendlyName], 'My Printer');
      expect(conn.allWrittenString, contains('getvar "device.friendly_name"'));
    });
  });

  group('PrinterLanguage.fromString', () {
    test('parses zpl', () {
      expect(PrinterLanguage.fromString('zpl'), PrinterLanguage.zpl);
      expect(PrinterLanguage.fromString('ZPL'), PrinterLanguage.zpl);
    });

    test('parses cpcl', () {
      expect(PrinterLanguage.fromString('cpcl'), PrinterLanguage.cpcl);
    });

    test('parses line_print', () {
      expect(
        PrinterLanguage.fromString('line_print'),
        PrinterLanguage.linePrint,
      );
    });

    test('defaults to zpl for unknown', () {
      expect(PrinterLanguage.fromString('unknown'), PrinterLanguage.zpl);
    });
  });
}
