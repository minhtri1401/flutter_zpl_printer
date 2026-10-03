import 'dart:typed_data';

import 'ble_connection.dart';
import 'bluetooth_constants.dart';
import 'connection.dart';

/// Dual-channel BLE connection for concurrent print and status operations.
///
/// Print channel uses characteristics 4a81/4a82, status channel uses 4a83/4a84.
/// Both channels share the same BLE device and service.
/// Mirrors SDK's `MultichannelBluetoothLeConnection`.
///
/// **iOS caveat**: `universal_ble` may have data routing issues with multiple
/// subscriptions on the same service. The `characteristicValueStream` is scoped
/// per-characteristic, but if leakage is observed, test on Android first.
class MultichannelBleConnection extends Connection {
  final String deviceId;

  late final BleConnection _printConnection;
  late final BleConnection _statusConnection;

  MultichannelBleConnection(this.deviceId, {super.config}) {
    _printConnection = BleConnection(
      deviceId,
      readCharUuid: ZebraBluetoothConstants.dataFromPrinterCharUuid,
      writeCharUuid: ZebraBluetoothConstants.dataToPrinterCharUuid,
      config: config,
    );
    _statusConnection = BleConnection(
      deviceId,
      readCharUuid: ZebraBluetoothConstants.statusFromPrinterCharUuid,
      writeCharUuid: ZebraBluetoothConstants.statusToPrinterCharUuid,
      config: config,
    );
  }

  /// Direct access to the print channel.
  Connection get printConnection => _printConnection;

  /// Direct access to the status channel.
  Connection get statusConnection => _statusConnection;

  @override
  bool get isConnected =>
      _printConnection.isConnected && _statusConnection.isConnected;

  @override
  String get connectionDescription => 'BLE_MULTI:$deviceId';

  @override
  Future<void> open() async {
    try {
      await _printConnection.open();
      await _statusConnection.open();
    } catch (e) {
      await _printConnection.close().catchError((_) {});
      await _statusConnection.close().catchError((_) {});
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    await _printConnection.close().catchError((_) {});
    await _statusConnection.close().catchError((_) {});
  }

  // -- Print channel: write operations --

  @override
  Future<void> write(Uint8List data) => _printConnection.write(data);

  @override
  Future<void> writeRaw(Uint8List data) => _printConnection.writeRaw(data);

  // -- Status channel: read/response operations --

  @override
  Future<Uint8List?> read() => _statusConnection.read();

  @override
  Future<int> bytesAvailable() => _statusConnection.bytesAvailable();

  @override
  Future<Uint8List> sendAndWaitForResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    String? endOfResponseMarker,
  }) => _statusConnection.sendAndWaitForResponse(
    data,
    initialTimeout: initialTimeout,
    readTimeout: readTimeout,
    endOfResponseMarker: endOfResponseMarker,
  );

  @override
  Future<Uint8List> sendAndWaitForValidResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    required ResponseValidator validator,
  }) => _statusConnection.sendAndWaitForValidResponse(
    data,
    initialTimeout: initialTimeout,
    readTimeout: readTimeout,
    validator: validator,
  );
}
