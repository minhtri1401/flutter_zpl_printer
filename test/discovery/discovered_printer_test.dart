import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('DiscoveredPrinter', () {
    test('creates TCP printer', () {
      final printer = DiscoveredPrinter(
        address: '192.168.1.100',
        name: 'ZQ620',
        connectionType: ConnectionType.tcp,
        port: 9100,
      );

      expect(printer.address, '192.168.1.100');
      expect(printer.name, 'ZQ620');
      expect(printer.connectionType, ConnectionType.tcp);
      expect(printer.port, 9100);
    });

    test('creates BLE printer', () {
      final printer = DiscoveredPrinter(
        address: 'AA:BB:CC:DD:EE:FF',
        name: 'ZD421',
        connectionType: ConnectionType.ble,
      );

      expect(printer.address, 'AA:BB:CC:DD:EE:FF');
      expect(printer.connectionType, ConnectionType.ble);
    });

    test('createConnection returns TcpConnection for TCP type', () {
      final printer = DiscoveredPrinter(
        address: '192.168.1.100',
        connectionType: ConnectionType.tcp,
        port: 9100,
      );

      final conn = printer.createConnection();

      expect(conn, isA<TcpConnection>());
      expect((conn as TcpConnection).host, '192.168.1.100');
      expect(conn.port, 9100);
    });

    test('createConnection returns BleConnection for BLE type', () {
      final printer = DiscoveredPrinter(
        address: 'AA:BB:CC:DD:EE:FF',
        connectionType: ConnectionType.ble,
      );

      final conn = printer.createConnection();

      expect(conn, isA<BleConnection>());
      expect((conn as BleConnection).deviceId, 'AA:BB:CC:DD:EE:FF');
    });

    test('equality based on address and connectionType', () {
      final a = DiscoveredPrinter(
        address: '192.168.1.100',
        name: 'Printer A',
        connectionType: ConnectionType.tcp,
      );
      final b = DiscoveredPrinter(
        address: '192.168.1.100',
        name: 'Printer B',
        connectionType: ConnectionType.tcp,
      );
      final c = DiscoveredPrinter(
        address: '192.168.1.100',
        connectionType: ConnectionType.ble,
      );

      expect(a, equals(b)); // same address + type
      expect(a, isNot(equals(c))); // different type
    });

    test('default port is 9100', () {
      final printer = DiscoveredPrinter(
        address: '192.168.1.100',
        connectionType: ConnectionType.tcp,
      );

      expect(printer.port, 9100);
    });
  });

  group('ConnectionType.usb additions', () {
    test('enum declares tcp, ble, usb in that order (ordinals 0,1,2)', () {
      expect(ConnectionType.values,
          [ConnectionType.tcp, ConnectionType.ble, ConnectionType.usb]);
      expect(ConnectionType.tcp.index, 0);
      expect(ConnectionType.ble.index, 1);
      expect(ConnectionType.usb.index, 2);
    });

    test('displayName', () {
      expect(ConnectionType.tcp.displayName, 'Wi-Fi');
      expect(ConnectionType.ble.displayName, 'Bluetooth');
      expect(ConnectionType.usb.displayName, 'USB');
    });

    test('isWired / isWireless', () {
      expect(ConnectionType.usb.isWired, isTrue);
      expect(ConnectionType.tcp.isWired, isFalse);
      expect(ConnectionType.ble.isWired, isFalse);
      expect(ConnectionType.tcp.isWireless, isTrue);
      expect(ConnectionType.usb.isWireless, isFalse);
    });

    test('createConnection for usb returns UsbConnection', () {
      final p = DiscoveredPrinter(
        address: 'usb://0A5F:0027/XX',
        connectionType: ConnectionType.usb,
      );
      final c = p.createConnection();
      expect(c, isA<UsbConnection>());
      expect((c as UsbConnection).address.vendorId, 0x0A5F);
      expect(c.address.serialNumber, 'XX');
    });
  });

  group('DiscoveredPrinter getters prefer discoveryData for USB', () {
    test('.model prefers discoveryData["model"] over name regex', () {
      final p = DiscoveredPrinter(
        address: 'usb://0A5F:0027',
        connectionType: ConnectionType.usb,
        name: 'random-no-ZTC-sentinel',
        discoveryData: {'model': 'ZQ620-203dpi'},
      );
      expect(p.model, 'ZQ620-203dpi');
    });

    test('.serial prefers discoveryData["serial"] over name regex', () {
      final p = DiscoveredPrinter(
        address: 'usb://0A5F:0027',
        connectionType: ConnectionType.usb,
        name: 'random',
        discoveryData: {'serial': 'XXYZ'},
      );
      expect(p.serial, 'XXYZ');
    });

    test('.friendlyName composes "model (serial)" when both present', () {
      final p = DiscoveredPrinter(
        address: 'usb://0A5F:0027',
        connectionType: ConnectionType.usb,
        name: 'ZQ620-203dpi',
        discoveryData: {'model': 'ZQ620-203dpi', 'serial': 'XX123'},
      );
      expect(p.friendlyName, 'ZQ620-203dpi (XX123)');
    });

    test('.model falls back to regex when discoveryData missing', () {
      final p = DiscoveredPrinter(
        address: '192.168.1.10',
        connectionType: ConnectionType.tcp,
        name: ':,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24',
      );
      // The existing zebra_name_parser regex extracts the model.
      expect(p.model, isNotNull);
      expect(p.model, contains('ZQ620'));
    });
  });
}
