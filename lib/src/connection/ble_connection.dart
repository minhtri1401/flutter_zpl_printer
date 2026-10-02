import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart' as uble;

import 'bluetooth_constants.dart';
import 'connection.dart';
import '../exceptions/connection_exception.dart';

/// BLE connection to a Zebra printer via `universal_ble`.
///
/// Uses per-device `characteristicValueStream` for incoming data,
/// allowing multiple simultaneous connections without callback collision.
class BleConnection extends Connection {
  final String deviceId;
  final String readCharUuid;
  final String writeCharUuid;
  final String serviceUuid;

  int _mtu = ZebraBluetoothConstants.bleDefaultMtu;
  final BytesBuilder _readBuffer = BytesBuilder();
  bool _isConnected = false;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Uint8List>? _valueSub;

  BleConnection(
    this.deviceId, {
    this.readCharUuid = ZebraBluetoothConstants.dataFromPrinterCharUuid,
    this.writeCharUuid = ZebraBluetoothConstants.dataToPrinterCharUuid,
    this.serviceUuid = ZebraBluetoothConstants.zebraBleDataServiceUuid,
    super.config,
  });

  @override
  bool get isConnected => _isConnected;

  @override
  String get connectionDescription {
    if (writeCharUuid == ZebraBluetoothConstants.dataToPrinterCharUuid) {
      return 'BLE:$deviceId';
    }
    final suffix = writeCharUuid.substring(4, 8);
    return 'BLE:$deviceId:$suffix';
  }

  /// Effective write chunk size (MTU minus ATT overhead).
  int get _writeChunkSize => _mtu - ZebraBluetoothConstants.bleAttOverhead;

  @override
  Future<void> open() async {
    if (_isConnected) return;
    try {
      _connectionSub = uble.UniversalBle.connectionStream(deviceId).listen((
        connected,
      ) {
        _isConnected = connected;
      });

      _valueSub =
          uble.UniversalBle.characteristicValueStream(
            deviceId,
            readCharUuid,
          ).listen((value) {
            _readBuffer.add(value);
          });

      await uble.UniversalBle.connect(deviceId);
      _isConnected = true;

      await Future.delayed(
        const Duration(
          milliseconds: ZebraBluetoothConstants.postConnectDelayMs,
        ),
      );

      _mtu = await uble.UniversalBle.requestMtu(
        deviceId,
        ZebraBluetoothConstants.defaultMtu,
      );

      final services = await uble.UniversalBle.discoverServices(deviceId);
      final zebraService = services.firstWhere(
        (s) => s.uuid.toLowerCase() == serviceUuid,
        orElse: () => throw ConnectionException(
          'Zebra BLE service not found on device $deviceId',
        ),
      );

      zebraService.characteristics.firstWhere(
        (c) => c.uuid.toLowerCase() == writeCharUuid,
        orElse: () => throw ConnectionException(
          'Zebra write characteristic not found on device $deviceId',
        ),
      );

      // Adding delay to prevent Android GATT_NO_RESOURCES (128) error
      // when writing CCCD descriptors too fast after service discovery.
      await Future.delayed(const Duration(milliseconds: 500));

      await uble.UniversalBle.subscribeIndications(
        deviceId,
        serviceUuid,
        readCharUuid,
      );
    } catch (e) {
      _isConnected = false;
      await _valueSub?.cancel();
      _valueSub = null;
      await _connectionSub?.cancel();
      _connectionSub = null;
      if (e is ConnectionException) rethrow;
      throw ConnectionException('Could not connect to BLE device: $e', e);
    }
  }

  @override
  Future<void> close() async {
    if (!_isConnected) return;

    await Future.delayed(
      const Duration(milliseconds: ZebraBluetoothConstants.preCloseDelayMs),
    );

    _isConnected = false;
    await _valueSub?.cancel();
    _valueSub = null;
    await _connectionSub?.cancel();
    _connectionSub = null;
    await uble.UniversalBle.disconnect(deviceId);
    _readBuffer.clear();
  }

  @override
  Future<void> write(Uint8List data) async {
    if (!_isConnected) {
      throw ConnectionClosedException();
    }
    final chunkSize = _writeChunkSize;
    int offset = 0;
    int remaining = data.length;

    while (remaining > 0) {
      final size = remaining > chunkSize ? chunkSize : remaining;
      final chunk = Uint8List.sublistView(data, offset, offset + size);
      await writeRaw(chunk);
      offset += size;
      remaining -= size;
    }
  }

  @override
  Future<void> writeRaw(Uint8List data) async {
    if (!_isConnected) {
      throw ConnectionClosedException();
    }
    try {
      await uble.UniversalBle.write(deviceId, serviceUuid, writeCharUuid, data);
    } catch (e) {
      throw ConnectionException('Error writing to BLE device: $e', e);
    }
  }

  @override
  Future<Uint8List?> read() async {
    if (_readBuffer.isEmpty) return null;
    return _readBuffer.takeBytes();
  }

  @override
  Future<int> bytesAvailable() async => _readBuffer.length;
}
