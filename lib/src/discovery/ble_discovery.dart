import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:universal_ble/universal_ble.dart' as uble;
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void _log(String message) {
  developer.log(message, name: 'flutter_zpl_printer.ble');
}

/// BLE discovery for Zebra printers using `universal_ble`.
///
/// Filters by 16-bit service UUID `0xFE79` (expanded to 128-bit:
/// `0000fe79-0000-1000-8000-00805f9b34fb`), which Zebra printers advertise
/// as a Complete List of 16-bit Service UUIDs (AD type 0x03).
class BleDiscovery {
  BleDiscovery._();

  /// Debug toggle: when true, [discover] emits EVERY device on the
  /// `scanStream` regardless of whether it looks like a Zebra
  /// printer. Combined with [debugDisableServiceFilter] this lets a
  /// developer verify the underlying BLE scanner is actually working
  /// on a platform before worrying about UUID matching. Leave
  /// `false` in production — consumers will see wristbands,
  /// headphones, etc. in the Nearby list.
  static bool debugAllowAllDevices = false;

  /// Returns true if [device] advertises the Zebra BLE service UUID (0xFE79).
  ///
  /// universal_ble normalises all advertised service UUIDs to their full
  /// 128-bit form in [uble.BleDevice.services], so we compare against the
  /// full form. Both 'fe79' and '0000fe79-...' inputs are normalised before
  /// comparison by universal_ble's BleUuidParser.
  static bool _isZebraDevice(uble.BleDevice device) {
    if (device.name == null) return false;
    final target = ZebraBluetoothConstants.zebraBleServiceUuid;
    final shortTarget = ZebraBluetoothConstants.zebraBleServiceUuidShort;
    return device.services.any(
      (s) => s.toLowerCase() == target || s.toLowerCase().contains(shortTarget),
    );
  }

  /// Discover Zebra printers via BLE scan.
  ///
  /// Returns a stream of discovered printers. Auto-stops after [timeout].
  ///
  /// [withServices] is forwarded to `UniversalBle.startScan` as a
  /// `ScanFilter`. Pass `null` (default) to scan without a service
  /// filter — behaviour matches the pre-change call site. Pass a
  /// list of 128-bit service UUIDs to filter at the OS level. On
  /// Apple platforms (iOS/macOS) CoreBluetooth requires a filter to
  /// surface devices whose advertisements contain only manufacturer
  /// data, so callers scanning for Zebra printers should use
  /// [discoverZebra] rather than this primitive directly.
  static Stream<DiscoveredPrinter> discover({
    Duration timeout = const Duration(seconds: 30),
    List<String>? withServices,
  }) {
    late StreamController<DiscoveredPrinter> controller;
    Timer? timer;
    StreamSubscription<uble.BleDevice>? scanSub;
    final seen = <String>{};

    controller = StreamController<DiscoveredPrinter>(
      onListen: () async {
        _log(
          '[discover] onListen platform=$defaultTargetPlatform '
          'withServices=${withServices ?? '(none)'} '
          'timeout=${timeout.inSeconds}s',
        );
        try {
          // Log adapter state first — if Bluetooth is unauthorised
          // (common on fresh macOS installs where the system prompt
          // was dismissed) startScan will resolve silently but no
          // devices ever arrive.
          try {
            final state =
                await uble.UniversalBle.getBluetoothAvailabilityState();
            _log('[discover] bluetoothAvailability=$state');
          } catch (e) {
            _log('[discover] bluetoothAvailability query failed: $e');
          }
          scanSub = uble.UniversalBle.scanStream.listen((device) {
            final isZebra = _isZebraDevice(device);
            _log(
              '[discover] scanStream device="${device.name}" '
              'id=${device.deviceId} services=${device.services} '
              'isZebra=$isZebra allowAll=$debugAllowAllDevices',
            );
            if (seen.contains(device.deviceId)) return;
            // When `debugAllowAllDevices` is on, every device (named or
            // unnamed, Zebra or not) passes through. That lets a
            // developer confirm universal_ble's scanStream is
            // actually delivering anything on macOS.
            if (!debugAllowAllDevices && !isZebra) return;
            seen.add(device.deviceId);

            controller.add(
              DiscoveredPrinter(
                address: device.deviceId,
                name: device.name,
                connectionType: ConnectionType.ble,
              ),
            );
          });

          await uble.UniversalBle.startScan(
            scanFilter: withServices == null
                ? null
                : uble.ScanFilter(withServices: withServices),
          );
          _log('[discover] startScan resolved');

          timer = Timer(timeout, () async {
            _log(
              '[discover] timeout fired after ${timeout.inSeconds}s, '
              'seen=${seen.length}',
            );
            await uble.UniversalBle.stopScan();
            await scanSub?.cancel();
            await controller.close();
          });
        } catch (e, st) {
          _log('[discover] ERROR $e\n$st');
          controller.addError(e);
          await controller.close();
        }
      },
      onCancel: () async {
        _log('[discover] onCancel (seen=${seen.length})');
        timer?.cancel();
        await uble.UniversalBle.stopScan();
        await scanSub?.cancel();
      },
    );

    return controller.stream;
  }

  /// Debug toggle: when true, [discoverZebra] scans with NO service
  /// filter regardless of platform. Set this to diagnose whether a
  /// "no devices found" result on Apple is a filter/advertisement
  /// matching issue (the filter is too strict, but raw devices do
  /// arrive) versus a deeper plugin/permission issue (nothing arrives
  /// even unfiltered). Leave `false` in production.
  static bool debugDisableServiceFilter = false;

  /// Discover Zebra BLE printers with the correct platform-specific
  /// scan filter.
  ///
  /// On Apple (iOS/macOS), CoreBluetooth requires
  /// `scanForPeripheralsWithServices:` to receive a non-empty list or
  /// it strips devices whose advertisements carry only manufacturer
  /// data (the common Zebra case). We pass the Zebra advertisement
  /// UUID (`0x0000FE79-…`) to make the printer visible.
  ///
  /// On Android, Linux, and Windows the same filter breaks matching
  /// because Zebra's `0xFE79` advertisement is short-form and the
  /// native BLE stack rejects devices whose resolved service UUID
  /// list doesn't exactly contain the 128-bit form. Scanning without
  /// a filter works on those platforms, so we omit it.
  ///
  /// Use this instead of [discover] when looking for Zebra printers.
  static Stream<DiscoveredPrinter> discoverZebra({
    Duration timeout = const Duration(seconds: 30),
  }) {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final filter = (apple && !debugDisableServiceFilter)
        ? const [ZebraBluetoothConstants.zebraBleServiceUuid]
        : null;
    _log(
      '[discoverZebra] platform=$defaultTargetPlatform '
      'apple=$apple debugDisableServiceFilter=$debugDisableServiceFilter '
      'filter=${filter ?? '(none)'}',
    );
    return discover(timeout: timeout, withServices: filter);
  }
}
