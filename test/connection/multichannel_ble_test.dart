import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('MultichannelBleConnection', () {
    test('connectionDescription format', () {
      final conn = MultichannelBleConnection('AA:BB:CC:DD:EE:FF');
      expect(conn.connectionDescription, 'BLE_MULTI:AA:BB:CC:DD:EE:FF');
    });

    test('isConnected false when not opened', () {
      final conn = MultichannelBleConnection('AA:BB:CC:DD:EE:FF');
      expect(conn.isConnected, false);
    });

    test('exposes printConnection and statusConnection', () {
      final conn = MultichannelBleConnection('AA:BB:CC:DD:EE:FF');
      expect(conn.printConnection, isNotNull);
      expect(conn.statusConnection, isNotNull);
    });
  });

  group('BleConnection parameterization', () {
    test('uses default UUIDs when none provided', () {
      final conn = BleConnection('test-device');
      expect(
        conn.readCharUuid,
        ZebraBluetoothConstants.dataFromPrinterCharUuid,
      );
      expect(conn.writeCharUuid, ZebraBluetoothConstants.dataToPrinterCharUuid);
      expect(conn.serviceUuid, ZebraBluetoothConstants.zebraBleDataServiceUuid);
    });

    test('accepts custom UUIDs for status channel', () {
      final conn = BleConnection(
        'test-device',
        readCharUuid: ZebraBluetoothConstants.statusFromPrinterCharUuid,
        writeCharUuid: ZebraBluetoothConstants.statusToPrinterCharUuid,
      );
      expect(
        conn.readCharUuid,
        ZebraBluetoothConstants.statusFromPrinterCharUuid,
      );
      expect(
        conn.writeCharUuid,
        ZebraBluetoothConstants.statusToPrinterCharUuid,
      );
    });

    test(
      'connectionDescription includes channel suffix for non-default UUIDs',
      () {
        final conn = BleConnection(
          'test-device',
          writeCharUuid: ZebraBluetoothConstants.statusToPrinterCharUuid,
        );
        // Status write UUID is 38eb4a84, so suffix is "4a84"
        expect(conn.connectionDescription, 'BLE:test-device:4a84');
      },
    );

    test('connectionDescription is plain for default UUIDs', () {
      final conn = BleConnection('test-device');
      expect(conn.connectionDescription, 'BLE:test-device');
    });
  });

  group('ZebraBluetoothConstants', () {
    test('status UUIDs are defined', () {
      expect(
        ZebraBluetoothConstants.statusFromPrinterCharUuid,
        '38eb4a83-c570-11e3-9507-0002a5d5c51b',
      );
      expect(
        ZebraBluetoothConstants.statusToPrinterCharUuid,
        '38eb4a84-c570-11e3-9507-0002a5d5c51b',
      );
    });

    test('data service UUID is defined', () {
      expect(
        ZebraBluetoothConstants.zebraBleDataServiceUuid,
        '38eb4a80-c570-11e3-9507-0002a5d5c51b',
      );
    });
  });
}
