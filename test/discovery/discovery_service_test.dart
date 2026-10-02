import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/discovery/discovered_printer.dart';
import 'package:flutter_zpl_printer/src/discovery/discovery_service.dart';

void main() {
  group('DiscoveryService.mergeSources', () {
    test('emits results from a healthy source when another errors', () async {
      final bleController = StreamController<DiscoveredPrinter>();
      final tcpController = StreamController<DiscoveredPrinter>();

      final merged = DiscoveryService.mergeSources([
        bleController.stream,
        tcpController.stream,
      ]);

      final collected = <DiscoveredPrinter>[];
      final errors = <Object>[];
      final done = Completer<void>();
      merged.listen(
        collected.add,
        onError: errors.add,
        onDone: done.complete,
      );

      // Source A (the "TCP" one) fails immediately, as when Wi-Fi is off.
      tcpController.addError(StateError('no network interface'));
      await tcpController.close();

      // Source B (the "BLE" one) keeps producing results afterwards.
      bleController.add(DiscoveredPrinter(
        address: 'AA:BB:CC:DD:EE:FF',
        name: 'Zebra BLE',
        connectionType: ConnectionType.ble,
      ));
      await bleController.close();

      await done.future.timeout(const Duration(seconds: 2));

      expect(errors, isEmpty, reason: 'per-source error must not surface');
      expect(collected, hasLength(1));
      expect(collected.single.address, 'AA:BB:CC:DD:EE:FF');
    });

    test('deduplicates by address across sources', () async {
      final a = Stream<DiscoveredPrinter>.fromIterable([
        DiscoveredPrinter(
          address: '10.0.0.1',
          name: 'Zebra',
          connectionType: ConnectionType.tcp,
        ),
      ]);
      final b = Stream<DiscoveredPrinter>.fromIterable([
        DiscoveredPrinter(
          address: '10.0.0.1',
          name: 'Zebra dup',
          connectionType: ConnectionType.tcp,
        ),
      ]);

      final merged = await DiscoveryService.mergeSources([a, b]).toList();
      expect(merged, hasLength(1));
    });
  });

  group('DiscoveryService.discoverAll transport filtering', () {
    test('empty transports set closes without emitting', () async {
      final stream = DiscoveryService.discoverAll(
        transports: const <DiscoveryTransport>{},
        timeout: const Duration(milliseconds: 50),
      );
      final results = await stream.toList();
      expect(results, isEmpty);
    });

    test('dedups broadcast and multicast returning same address', () async {
      final broadcast = Stream<DiscoveredPrinter>.fromIterable([
        DiscoveredPrinter(
          address: '10.0.0.42',
          name: 'Zebra ZQ620',
          connectionType: ConnectionType.tcp,
        ),
      ]);
      final multicast = Stream<DiscoveredPrinter>.fromIterable([
        DiscoveredPrinter(
          address: '10.0.0.42',
          name: 'Zebra ZQ620 (via multicast)',
          connectionType: ConnectionType.tcp,
        ),
      ]);

      final merged =
          await DiscoveryService.mergeSources([broadcast, multicast]).toList();
      expect(merged, hasLength(1));
      expect(merged.single.address, '10.0.0.42');
    });
  });

  group('DiscoveryTransport enum', () {
    test('usb is first in declaration (priority tier 1)', () {
      expect(DiscoveryTransport.values.first, DiscoveryTransport.usb);
    });

    test('enum has 4 values: usb, udpBroadcast, udpMulticast, ble', () {
      expect(DiscoveryTransport.values, [
        DiscoveryTransport.usb,
        DiscoveryTransport.udpBroadcast,
        DiscoveryTransport.udpMulticast,
        DiscoveryTransport.ble,
      ]);
    });
  });
}
