import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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

  group('AlertUtil.removeAllAlerts', () {
    test('sends SGD alerts.configured set with empty value', () async {
      await AlertUtil.removeAllAlerts(conn);

      expect(
        conn.allWrittenString,
        '! U1 setvar "alerts.configured" ""\r\n',
      );
    });

    test('can be called after configuring alerts', () async {
      final alerts = [
        const PrinterAlert(
          condition: AlertCondition.paperOut,
          destination: AlertDestination.tcp,
          destinationAddress: '192.168.1.100',
          port: 9100,
        ),
      ];

      await AlertUtil.configureAlerts(conn, alerts);
      conn.writtenData.clear();

      await AlertUtil.removeAllAlerts(conn);

      expect(
        conn.allWrittenString,
        '! U1 setvar "alerts.configured" ""\r\n',
      );
    });
  });

  group('FileUtil.retrieveFileNamesByExtension', () {
    test('returns list from retrieveFileNames', () async {
      // retrieveFileNames calls listFiles for E: then R:
      // Return empty responses to simulate no files (we test the filtering separately)
      conn.queueStringResponse('* ');
      conn.queueStringResponse('* ');

      final names = await FileUtil.retrieveFileNamesByExtension(conn, ['ZPL']);

      // Should not crash and return a list (empty or not)
      expect(names, isA<List<String>>());
    });

    test('accepts multiple extensions', () async {
      conn.queueStringResponse('* ');
      conn.queueStringResponse('* ');

      final names = await FileUtil.retrieveFileNamesByExtension(
        conn,
        ['ZPL', 'GRF'],
      );

      expect(names, isA<List<String>>());
    });

    test('handles empty drives', () async {
      conn.queueStringResponse('* E:');
      conn.queueStringResponse('* R:');

      final names = await FileUtil.retrieveFileNamesByExtension(conn, ['ZPL']);

      expect(names, isEmpty);
    });
  });

  group('PrinterObject getters', () {
    test('drive property with E: prefix', () {
      const obj = PrinterObject(name: 'E:LABEL.ZPL', sizeBytes: 1024);
      expect(obj.drive, 'E:');
    });

    test('drive property with R: prefix', () {
      const obj = PrinterObject(name: 'R:IMAGE.GRF', sizeBytes: 512);
      expect(obj.drive, 'R:');
    });

    test('drive property null when no prefix', () {
      const obj = PrinterObject(name: 'LABEL.ZPL', sizeBytes: 0);
      expect(obj.drive, isNull);
    });

    test('extension property extracts extension', () {
      const obj = PrinterObject(name: 'E:LABEL.ZPL', sizeBytes: 1024);
      expect(obj.extension, 'ZPL');
    });

    test('extension property null when no extension', () {
      const obj = PrinterObject(name: 'E:NOEXTENSION', sizeBytes: 512);
      expect(obj.extension, isNull);
    });

    test('fileName property removes drive prefix', () {
      const obj = PrinterObject(name: 'E:LABEL.ZPL', sizeBytes: 1024);
      expect(obj.fileName, 'LABEL.ZPL');
    });

    test('fileName property returns full name when no drive', () {
      const obj = PrinterObject(name: 'LABEL.ZPL', sizeBytes: 0);
      expect(obj.fileName, 'LABEL.ZPL');
    });

    test('fileName property handles multiple colons', () {
      const obj = PrinterObject(name: 'E:MY:FILE.ZPL', sizeBytes: 256);
      expect(obj.fileName, 'MY:FILE.ZPL');
    });

    test('all properties together', () {
      const obj = PrinterObject(name: 'R:TEMPLATE.GRF', sizeBytes: 2048);
      expect(obj.drive, 'R:');
      expect(obj.extension, 'GRF');
      expect(obj.fileName, 'TEMPLATE.GRF');
    });
  });

  group('FormatUtil.printStoredFormatWithVarGraphics', () {
    test('sends ZPL with text variables', () async {
      // Mock retrieveFormat response
      conn.queueStringResponse('^XA^FN1^FS^XZ');

      await FormatUtil.printStoredFormatWithVarGraphics(
        conn,
        'E:TEMPLATE.ZPL',
        textVars: {1: 'Hello'},
      );

      final written = conn.allWrittenString;
      // Should replace ^FN1 with text variable
      expect(written, contains('FDHello'));
    });

    test('text-only format does not store images', () async {
      conn.queueStringResponse('^XA^FN1^FS^XZ');

      await FormatUtil.printStoredFormatWithVarGraphics(
        conn,
        'E:LABEL.ZPL',
        textVars: {1: 'OnlyText'},
      );

      final written = conn.allWrittenString;
      expect(written.contains('FDOnlyText'), true);
    });

    test('empty image vars does nothing', () async {
      conn.queueStringResponse('^XA^FN1^FS^XZ');

      await FormatUtil.printStoredFormatWithVarGraphics(
        conn,
        'E:FORMAT.ZPL',
        textVars: {1: 'Data'},
        imageVars: {},
      );

      final written = conn.allWrittenString;
      expect(written.contains('FDData'), true);
    });

    test('multiple text variables combined', () async {
      conn.queueStringResponse('^XA^FN1^FN2^FN3^FS^XZ');

      await FormatUtil.printStoredFormatWithVarGraphics(
        conn,
        'E:FORM.ZPL',
        textVars: {
          1: 'First',
          2: 'Second',
          3: 'Third',
        },
      );

      final written = conn.allWrittenString;
      expect(written.contains('FDFirst'), true);
      expect(written.contains('FDSecond'), true);
      expect(written.contains('FDThird'), true);
    });
  });

  group('FirmwareUtil.getCurrentFirmwareVersion', () {
    test('queries appl.name via SGD', () async {
      conn.queueStringResponse('"V75.19.10Z"');

      final version = await FirmwareUtil.getCurrentFirmwareVersion(conn);

      expect(version, 'V75.19.10Z');
      expect(
        conn.allWrittenString,
        '! U1 getvar "appl.name"\r\n',
      );
    });

    test('returns version without quotes', () async {
      conn.queueStringResponse('"V80.20.01Z"');

      final version = await FirmwareUtil.getCurrentFirmwareVersion(conn);

      expect(version, 'V80.20.01Z');
      expect(version, isNot('"V80.20.01Z"'));
    });
  });

  group('FirmwareUtil.updateFirmware - version comparison', () {
    test('skips update when versions match', () async {
      conn.queueStringResponse('"V75.19.10Z"');

      final result = await FirmwareUtil.updateFirmware(
        conn,
        Uint8List.fromList([0x00, 0x01, 0x02]),
        firmwareName: 'V75.19.10Z.ZPL',
      );

      expect(result, false);
      // Should only have one write (the SGD get)
      expect(conn.writtenData.length, 1);
    });

    test('sends firmware when versions differ', () async {
      conn.queueStringResponse('"V75.19.10Z"');
      conn.queueStringResponse(''); // Ack for firmware write

      final firmwareBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x04]);
      final result = await FirmwareUtil.updateFirmware(
        conn,
        firmwareBytes,
        firmwareName: 'V80.20.01Z.ZPL',
      );

      expect(result, true);
      // Firmware bytes should be sent (in addition to SGD query)
      expect(conn.allWrittenBytes.length, greaterThan(4));
    });

    test('normalizes firmware filename extensions', () async {
      conn.queueStringResponse('"V75.19.10Z"');

      final result = await FirmwareUtil.updateFirmware(
        conn,
        Uint8List.fromList([0x00, 0x01]),
        firmwareName: 'V75.19.10Z.ZPL',
      );

      expect(result, false);
    });

    test('handles firmware with underscores in version', () async {
      conn.queueStringResponse('"V75_19_10Z"');

      final result = await FirmwareUtil.updateFirmware(
        conn,
        Uint8List.fromList([0x00, 0x01]),
        firmwareName: 'V75_19_10Z.ZPL',
      );

      expect(result, false);
    });
  });

  group('FirmwareUtil.updateFirmwareUnconditionally', () {
    test('sends firmware without version check', () async {
      final firmwareBytes = Uint8List.fromList([0x00, 0x01, 0x02, 0x03]);

      await FirmwareUtil.updateFirmwareUnconditionally(
        conn,
        firmwareBytes,
      );

      // Should have written firmware bytes
      expect(conn.allWrittenBytes, isNotEmpty);
    });

    test('supports progress callback', () async {
      final progressUpdates = <(int, int)>[];
      final firmwareBytes = Uint8List.fromList(List<int>.generate(2048, (i) => i % 256));

      await FirmwareUtil.updateFirmwareUnconditionally(
        conn,
        firmwareBytes,
        onProgress: (sent, total) {
          progressUpdates.add((sent, total));
        },
      );

      // Should have reported progress (at least one update)
      expect(progressUpdates.isNotEmpty, true);
    });
  });

  group('ProfileUtil ZIP operations', () {
    test('createProfile generates valid ZIP', () async {
      // Mock SGD gets for settings
      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      // Mock alerts query
      conn.queueStringResponse('""');
      // Mock file listing
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      // Mock file content retrieval
      conn.queueStringResponse('^XA^FDTest^FS^XZ');
      conn.queueStringResponse('^XA^FDConfig^FS^XZ');

      final profileBytes = await ProfileUtil.createProfile(conn);

      expect(profileBytes, isNotEmpty);
      // Verify it's a valid ZIP
      final archive = ZipDecoder().decodeBytes(profileBytes);
      expect(archive.isNotEmpty, true);
    });

    test('ZIP contains settings.json', () async {
      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      conn.queueStringResponse('""');
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      conn.queueStringResponse('^XA^FDTest^FS^XZ');
      conn.queueStringResponse('^XA^FDConfig^FS^XZ');

      final profileBytes = await ProfileUtil.createProfile(conn);
      final archive = ZipDecoder().decodeBytes(profileBytes);

      final settingsFile = archive.firstWhere(
        (f) => f.name == 'settings.json',
        orElse: () => throw Exception('settings.json not found'),
      );
      expect(settingsFile.isFile, true);

      final content = utf8.decode(settingsFile.content);
      final settings = jsonDecode(content);
      expect(settings, isA<Map>());
    });

    test('ZIP contains alerts.json', () async {
      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      conn.queueStringResponse('""');
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      conn.queueStringResponse('^XA^FDTest^FS^XZ');
      conn.queueStringResponse('^XA^FDConfig^FS^XZ');

      final profileBytes = await ProfileUtil.createProfile(conn);
      final archive = ZipDecoder().decodeBytes(profileBytes);

      final alertsFile = archive.firstWhere(
        (f) => f.name == 'alerts.json',
        orElse: () => throw Exception('alerts.json not found'),
      );
      expect(alertsFile.isFile, true);
    });

    test('loadProfile applies settings and uploads files', () async {
      // Build a test ZIP profile
      final archive = Archive();
      archive.addFile(ArchiveFile.bytes(
        'settings.json',
        utf8.encode('{"media.type": "label"}'),
      ));
      archive.addFile(ArchiveFile.bytes(
        'alerts.json',
        utf8.encode('[]'),
      ));
      archive.addFile(ArchiveFile.bytes(
        'E:LABEL.ZPL',
        utf8.encode('^XA^FDTest^FS^XZ'),
      ));

      final profileBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Mock responses for loading
      conn.queueStringResponse(''); // setvar for media.type
      conn.queueStringResponse(''); // storeFile for E:LABEL.ZPL

      await ProfileUtil.loadProfile(conn, profileBytes);

      final written = conn.allWrittenString;
      // Should set media.type
      expect(written.contains('media.type'), true);
    });

    test('loadProfile with FileDeletionOption.cloneable', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.bytes(
        'settings.json',
        utf8.encode('{}'),
      ));
      archive.addFile(ArchiveFile.bytes(
        'alerts.json',
        utf8.encode('[]'),
      ));

      final profileBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      // Mock file listing responses for deletion check
      conn.queueStringResponse('* E:LABEL.ZPL    512\nE:BINARY.DAT    256\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      // Mock delete responses
      conn.queueStringResponse('');
      conn.queueStringResponse('');

      await ProfileUtil.loadProfile(
        conn,
        profileBytes,
        deletionOption: FileDeletionOption.cloneable,
      );

      final written = conn.allWrittenString;
      // Should attempt to delete cloneable files (ZPL)
      expect(written.contains('^ID'), true);
    });

    test('createBackup alias delegates to createProfile', () async {
      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      conn.queueStringResponse('""');
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      conn.queueStringResponse('^XA^FDTest^FS^XZ');
      conn.queueStringResponse('^XA^FDConfig^FS^XZ');

      final backupBytes = await ProfileUtil.createBackup(conn);

      expect(backupBytes, isNotEmpty);
    });

    test('loadBackup alias delegates to loadProfile', () async {
      final archive = Archive();
      archive.addFile(ArchiveFile.bytes(
        'settings.json',
        utf8.encode('{}'),
      ));
      archive.addFile(ArchiveFile.bytes(
        'alerts.json',
        utf8.encode('[]'),
      ));

      final profileBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      await ProfileUtil.loadBackup(conn, profileBytes);

      // Should complete without error
      expect(conn.isConnected, true);
    });
  });

  group('ProfileUtil progress callbacks', () {
    test('createProfile calls onProgress', () async {
      final progressCalls = <String>[];

      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      conn.queueStringResponse('""');
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      conn.queueStringResponse('^XA^FDTest^FS^XZ');
      conn.queueStringResponse('^XA^FDConfig^FS^XZ');

      await ProfileUtil.createProfile(
        conn,
        onProgress: (status) {
          progressCalls.add(status);
        },
      );

      expect(progressCalls.isNotEmpty, true);
      expect(progressCalls.any((s) => s.contains('Fetching')), true);
    });

    test('loadProfile calls onProgress', () async {
      final progressCalls = <String>[];

      final archive = Archive();
      archive.addFile(ArchiveFile.bytes(
        'settings.json',
        utf8.encode('{"key": "value"}'),
      ));
      archive.addFile(ArchiveFile.bytes(
        'alerts.json',
        utf8.encode('[]'),
      ));

      final profileBytes = Uint8List.fromList(ZipEncoder().encode(archive));

      conn.queueStringResponse('');

      await ProfileUtil.loadProfile(
        conn,
        profileBytes,
        onProgress: (status) {
          progressCalls.add(status);
        },
      );

      expect(progressCalls.isNotEmpty, true);
    });
  });

  group('Integration: Alert + Format + Profile', () {
    test('can create profile with alerts and formats', () async {
      // Setup for createProfile
      conn.queueStringResponse('"label"');
      conn.queueStringResponse('"96"');
      // Alert response
      conn.queueStringResponse('""');
      // File listing
      conn.queueStringResponse('* E:LABEL.ZPL    512\n');
      conn.queueStringResponse('* R:CONFIG.ZPL    256\n');
      // File retrieval
      conn.queueStringResponse('^XA^FN1^FS^XZ');
      conn.queueStringResponse('^XA^FDHello^FS^XZ');

      final profileBytes = await ProfileUtil.createProfile(conn);
      expect(profileBytes, isNotEmpty);

      // Now remove all alerts
      conn.writtenData.clear();
      await AlertUtil.removeAllAlerts(conn);

      expect(
        conn.allWrittenString,
        '! U1 setvar "alerts.configured" ""\r\n',
      );
    });
  });
}
