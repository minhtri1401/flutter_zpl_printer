import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/discovery/discovered_printer.dart';
import 'package:flutter_zpl_printer/src/discovery/usb_discovery.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer_testing.dart';

UsbDeviceRecord _zq(String path, {String? serial, int vid = 0x0A5F, int pid = 0x0027}) =>
    UsbDeviceRecord(
      vendorId: vid,
      productId: pid,
      path: path,
      hasPermission: true,
      manufacturer: 'Zebra Technologies',
      product: 'ZQ620-203dpi',
      serialNumber: serial,
      interfaceNumber: 0,
      bulkInEndpoint: 0x81,
      bulkOutEndpoint: 0x01,
      wMaxPacketSizeOut: 64,
      driverBinding: null,
    );

void main() {
  group('UsbDiscovery.enumerateWith', () {
    test('emits one DiscoveredPrinter per Zebra device', () async {
      final fake = FakeUsbPlatform()..devices.add(_zq('/p1', serial: 'XX1'));
      final list =
          await UsbDiscovery.enumerateWith(platform: fake).toList();
      expect(list, hasLength(1));
      final p = list.first;
      expect(p.connectionType, ConnectionType.usb);
      expect(p.name, 'ZQ620-203dpi');
      expect(p.discoveryData['model'], 'ZQ620-203dpi');
      expect(p.discoveryData['serial'], 'XX1');
      expect(p.discoveryData['vendorId'], '0A5F');
      expect(p.discoveryData['manufacturer'], 'Zebra Technologies');
      expect(p.address, 'usb://0A5F:0027/XX1');
    });

    test('encodes address without serial when descriptor has none', () async {
      final fake = FakeUsbPlatform()..devices.add(_zq('/p1'));
      final list =
          await UsbDiscovery.enumerateWith(platform: fake).toList();
      expect(list, hasLength(1));
      expect(list.first.address, 'usb://0A5F:0027');
    });

    test('filters non-Zebra by default', () async {
      final fake = FakeUsbPlatform()
        ..devices.addAll([
          _zq('/z', serial: 'X'),
          _zq('/other', vid: 0x1234),
        ]);
      final list =
          await UsbDiscovery.enumerateWith(platform: fake).toList();
      expect(list, hasLength(1));
      expect(list.first.discoveryData['vendorId'], '0A5F');
    });

    test('includeNonZebra returns all', () async {
      final fake = FakeUsbPlatform()
        ..devices.addAll([_zq('/a', vid: 0x1234), _zq('/b')]);
      final list = await UsbDiscovery.enumerateWith(
        platform: fake,
        includeNonZebra: true,
      ).toList();
      expect(list, hasLength(2));
    });

    test('empty devices → empty stream that closes', () async {
      final fake = FakeUsbPlatform();
      final list =
          await UsbDiscovery.enumerateWith(platform: fake).toList();
      expect(list, isEmpty);
    });

    test('platform error surfaces as stream error then closes', () async {
      final fake = FakeUsbPlatform()
        ..enumerateError = StateError('fake enumerate failure');
      final errors = <Object>[];
      final done = Completer<void>();
      UsbDiscovery.enumerateWith(platform: fake).listen(
        (_) {},
        onError: errors.add,
        onDone: done.complete,
      );
      await done.future.timeout(const Duration(seconds: 1));
      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());
    });

    test('driverBinding propagates into discoveryData', () async {
      final device = UsbDeviceRecord(
        vendorId: 0x0A5F,
        productId: 0x0027,
        path: '/win',
        hasPermission: true,
        product: 'ZD421',
        serialNumber: 'YY1',
        interfaceNumber: 0,
        bulkInEndpoint: 0x81,
        bulkOutEndpoint: 0x01,
        wMaxPacketSizeOut: 64,
        driverBinding: 'USBPRINT',
      );
      final fake = FakeUsbPlatform()..devices.add(device);
      final list =
          await UsbDiscovery.enumerateWith(platform: fake).toList();
      expect(list.first.discoveryData['driverBinding'], 'USBPRINT');
    });
  });
}
