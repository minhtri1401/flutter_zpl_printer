import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

class _FakeUniversalBlePlatform extends Mock implements UniversalBlePlatform {}

class _FakeScanFilter extends Fake implements ScanFilter {}

class _FakePlatformConfig extends Fake implements PlatformConfig {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeUniversalBlePlatform platform;
  late StreamController<BleDevice> scanStreamController;

  setUpAll(() {
    registerFallbackValue(_FakeScanFilter());
    registerFallbackValue(_FakePlatformConfig());
  });

  setUp(() {
    platform = _FakeUniversalBlePlatform();
    scanStreamController = StreamController<BleDevice>.broadcast();
    when(
      () => platform.scanStream,
    ).thenAnswer((_) => scanStreamController.stream);
    when(
      () => platform.startScan(
        scanFilter: any(named: 'scanFilter'),
        platformConfig: any(named: 'platformConfig'),
      ),
    ).thenAnswer((_) async {});
    when(() => platform.stopScan()).thenAnswer((_) async {});

    UniversalBle.setInstance(platform);
  });

  tearDown(() async {
    await scanStreamController.close();
  });

  group('BleDiscovery.discover', () {
    test('passes null scanFilter when withServices is not provided', () async {
      final sub = BleDiscovery.discover(
        timeout: const Duration(milliseconds: 50),
      ).listen((_) {});
      // Let the onListen callback run to completion.
      await Future<void>.delayed(Duration.zero);

      verify(
        () => platform.startScan(
          scanFilter: null,
          platformConfig: any(named: 'platformConfig'),
        ),
      ).called(1);

      await sub.cancel();
    });

    test('wraps withServices into a ScanFilter and forwards it', () async {
      const uuids = ['0000fe79-0000-1000-8000-00805f9b34fb'];

      final sub = BleDiscovery.discover(
        timeout: const Duration(milliseconds: 50),
        withServices: uuids,
      ).listen((_) {});
      await Future<void>.delayed(Duration.zero);

      final captured = verify(
        () => platform.startScan(
          scanFilter: captureAny(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).captured;
      expect(captured, hasLength(1));
      final filter = captured.single as ScanFilter;
      expect(filter.withServices, uuids);

      await sub.cancel();
    });
  });

  group('BleDiscovery.discoverZebra', () {
    test('passes Zebra UUID filter on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final sub = BleDiscovery.discoverZebra(
        timeout: const Duration(milliseconds: 50),
      ).listen((_) {});
      await Future<void>.delayed(Duration.zero);

      final captured = verify(
        () => platform.startScan(
          scanFilter: captureAny(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).captured;
      final filter = captured.single as ScanFilter;
      expect(filter.withServices, [
        ZebraBluetoothConstants.zebraBleServiceUuid,
      ]);

      await sub.cancel();
    });

    test('passes Zebra UUID filter on macOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final sub = BleDiscovery.discoverZebra(
        timeout: const Duration(milliseconds: 50),
      ).listen((_) {});
      await Future<void>.delayed(Duration.zero);

      final captured = verify(
        () => platform.startScan(
          scanFilter: captureAny(named: 'scanFilter'),
          platformConfig: any(named: 'platformConfig'),
        ),
      ).captured;
      expect((captured.single as ScanFilter).withServices, [
        ZebraBluetoothConstants.zebraBleServiceUuid,
      ]);

      await sub.cancel();
    });

    test('passes no filter on Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final sub = BleDiscovery.discoverZebra(
        timeout: const Duration(milliseconds: 50),
      ).listen((_) {});
      await Future<void>.delayed(Duration.zero);

      verify(
        () => platform.startScan(
          scanFilter: null,
          platformConfig: any(named: 'platformConfig'),
        ),
      ).called(1);

      await sub.cancel();
    });
  });
}
