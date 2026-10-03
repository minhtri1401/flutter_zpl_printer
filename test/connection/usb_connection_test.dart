import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/connection/connection_config.dart';
import 'package:flutter_zpl_printer/src/connection/usb_connection.dart';
import 'package:flutter_zpl_printer/src/connection/usb_device_address.dart';
import 'package:flutter_zpl_printer/src/exceptions/connection_exception.dart';
import 'package:flutter_zpl_printer/src/printer/sgd.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer_testing.dart';

UsbDeviceRecord _zqDevice({String serial = 'XX1', String path = '/p1'}) =>
    UsbDeviceRecord(
      vendorId: 0x0A5F,
      productId: 0x0027,
      path: path,
      hasPermission: true,
      manufacturer: 'Zebra',
      product: 'ZQ620-203dpi',
      serialNumber: serial,
      interfaceNumber: 0,
      bulkInEndpoint: 0x81,
      bulkOutEndpoint: 0x01,
      wMaxPacketSizeOut: 64,
    );

UsbConnection _conn(
  FakeUsbPlatform fake,
  UsbDeviceAddress addr, {
  ConnectionConfig? config,
}) => UsbConnection.withPlatform(addr, fake, config: config);

void main() {
  group('UsbConnection lifecycle', () {
    test('open succeeds → isConnected true', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      expect(c.isConnected, isTrue);
      await c.close();
      expect(c.isConnected, isFalse);
    });

    test('close is idempotent', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      await c.close();
      await c.close(); // must not throw
    });

    test('identity check throws on serial mismatch', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice(serial: 'ACTUAL'));
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/EXPECTED'));
      await expectLater(c.open(), throwsA(isA<UsbIdentityMismatchException>()));
      expect(c.isConnected, isFalse);
    });

    test('identity check skipped when address has no serial', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice(serial: 'ACTUAL'));
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027'));
      await c.open();
      expect(c.isConnected, isTrue);
    });

    test(
      'open propagates UsbPermissionDeniedException from platform',
      () async {
        final fake = FakeUsbPlatform()
          ..devices.add(_zqDevice())
          ..openError = UsbPermissionDeniedException('denied');
        final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
        await expectLater(
          c.open(),
          throwsA(isA<UsbPermissionDeniedException>()),
        );
      },
    );

    test('unsupported platform throws', () async {
      final fake = FakeUsbPlatform()..isSupportedResult = false;
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027'));
      await expectLater(
        c.open(),
        throwsA(isA<UsbUnsupportedOnPlatformException>()),
      );
    });

    test('requestPermission called when hasPermission is false', () async {
      final noPermDevice = UsbDeviceRecord(
        vendorId: 0x0A5F,
        productId: 0x0027,
        path: '/p1',
        hasPermission: false,
        product: 'ZQ620',
        serialNumber: null,
        interfaceNumber: 0,
        bulkInEndpoint: 0x81,
        bulkOutEndpoint: 0x01,
        wMaxPacketSizeOut: 64,
      );
      final fake = FakeUsbPlatform()
        ..devices.add(noPermDevice)
        ..permissionGrantResult = true;
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027'));
      await c.open();
      expect(c.isConnected, isTrue);
    });

    test(
      'requestPermission returning false throws UsbPermissionDeniedException',
      () async {
        final noPermDevice = UsbDeviceRecord(
          vendorId: 0x0A5F,
          productId: 0x0027,
          path: '/p1',
          hasPermission: false,
          serialNumber: null,
          interfaceNumber: 0,
          bulkInEndpoint: 0x81,
          bulkOutEndpoint: 0x01,
          wMaxPacketSizeOut: 64,
        );
        final fake = FakeUsbPlatform()
          ..devices.add(noPermDevice)
          ..permissionGrantResult = false;
        final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027'));
        await expectLater(
          c.open(),
          throwsA(isA<UsbPermissionDeniedException>()),
        );
      },
    );
  });

  group('UsbConnection I/O', () {
    test('writeRaw forwards bytes through platform', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      await c.writeRaw(Uint8List.fromList([1, 2, 3]));
      expect(fake.writesFor(1), hasLength(1));
      expect(fake.writesFor(1).first, [1, 2, 3]);
    });

    test('writeRaw throws ConnectionClosedException when not open', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await expectLater(
        c.writeRaw(Uint8List.fromList([1])),
        throwsA(isA<ConnectionClosedException>()),
      );
    });

    test('writeRaw retries once after STALL, then passes', () async {
      final fake = _StallOnceFake()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      await c.writeRaw(Uint8List.fromList([0xAA]));
      expect(fake.clearHaltCalls, 1);
    });

    test('writeRaw escalates after exhausting stall retries', () async {
      final fake = FakeUsbPlatform()
        ..devices.add(_zqDevice())
        ..writeError = UsbTransferStalledException();
      final c = _conn(
        fake,
        UsbDeviceAddress.parse('usb://0A5F:0027/XX1'),
        config: const ConnectionConfig(usbStallRetries: 0),
      );
      await c.open();
      await expectLater(
        c.writeRaw(Uint8List.fromList([1])),
        throwsA(isA<UsbTransferStalledException>()),
      );
    });

    test('read returns null when no data queued', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      expect(await c.read(), isNull);
    });

    test('read returns queued bytes', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      fake.queueRead(1, Uint8List.fromList([0xFF, 0xFE]));
      final data = await c.read();
      expect(data, [0xFF, 0xFE]);
    });

    test('unplug during writeRaw closes connection and rethrows', () async {
      final fake = FakeUsbPlatform()
        ..devices.add(_zqDevice())
        ..writeError = UsbDeviceUnpluggedException();
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      await expectLater(
        c.writeRaw(Uint8List.fromList([1])),
        throwsA(isA<UsbDeviceUnpluggedException>()),
      );
      expect(c.isConnected, isFalse);
    });

    test('unplug during read closes connection and rethrows', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(fake, UsbDeviceAddress.parse('usb://0A5F:0027/XX1'));
      await c.open();
      fake.readError = UsbDeviceUnpluggedException();
      await expectLater(c.read(), throwsA(isA<UsbDeviceUnpluggedException>()));
      expect(c.isConnected, isFalse);
    });

    test('request/response returns the printer reply (Sgd.get)', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(
        fake,
        UsbDeviceAddress.parse('usb://0A5F:0027/XX1'),
        config: const ConnectionConfig(
          maxTimeoutForRead: 500,
          timeToWaitForMoreData: 100,
        ),
      );
      await c.open();
      fake.queueRead(1, Uint8List.fromList('"ZQ620"'.codeUnits));
      expect(await Sgd.get('device.product_name', c), 'ZQ620');
    });

    test('reply split across bulk packets is reassembled', () async {
      final fake = FakeUsbPlatform()..devices.add(_zqDevice());
      final c = _conn(
        fake,
        UsbDeviceAddress.parse('usb://0A5F:0027/XX1'),
        config: const ConnectionConfig(
          maxTimeoutForRead: 500,
          timeToWaitForMoreData: 100,
        ),
      );
      await c.open();
      fake.queueRead(1, Uint8List.fromList('"V85.'.codeUnits));
      fake.queueRead(1, Uint8List.fromList('20.24"'.codeUnits));
      expect(await Sgd.get('appl.name', c), 'V85.20.24');
    });

    test(
      'open picks the printer whose serial matches when two share VID:PID',
      () async {
        final fake = FakeUsbPlatform()
          ..devices.add(_zqDevice(serial: 'SERIAL_A', path: '/p1'))
          ..devices.add(_zqDevice(serial: 'SERIAL_B', path: '/p2'));
        final c = _conn(
          fake,
          UsbDeviceAddress.parse('usb://0A5F:0027/SERIAL_B'),
        );
        await c
            .open(); // previously opened SERIAL_A and threw identity mismatch
        expect(c.isConnected, isTrue);
      },
    );

    test('connectionDescription formats VID:PID:SERIAL', () {
      final fake = FakeUsbPlatform();
      final c = UsbConnection.withPlatform(
        const UsbDeviceAddress(
          vendorId: 0x0A5F,
          productId: 0x0027,
          serialNumber: 'ABC',
        ),
        fake,
      );
      expect(c.connectionDescription, 'USB:A5F:27:ABC');
    });
  });
}

/// A FakeUsbPlatform that returns STALL on the first writeBytes, then succeeds.
class _StallOnceFake extends FakeUsbPlatform {
  int writeCalls = 0;
  int clearHaltCalls = 0;

  @override
  Future<void> writeBytes({
    required int handleId,
    required Uint8List data,
    required int timeoutMs,
  }) async {
    writeCalls++;
    if (writeCalls == 1) {
      throw UsbTransferStalledException();
    }
    return super.writeBytes(
      handleId: handleId,
      data: data,
      timeoutMs: timeoutMs,
    );
  }

  @override
  Future<void> clearHalt({required int handleId, required int endpoint}) async {
    clearHaltCalls++;
  }
}
