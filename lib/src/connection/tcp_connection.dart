import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'connection.dart';
import 'connection_config.dart';
import '../exceptions/connection_exception.dart';

/// TCP connection to a Zebra printer.
///
/// Uses `dart:io Socket` for raw TCP. Default port 9100 (ZPL) or 6101 (CPCL).
/// Mirrors SDK's `TcpConnection` + `TcpZebraConnectorImpl`.
class TcpConnection extends Connection {
  final String host;
  final int port;

  Socket? _socket;
  final BytesBuilder _readBuffer = BytesBuilder();
  StreamSubscription<Uint8List>? _subscription;
  bool _isConnected = false;

  TcpConnection(this.host, this.port, {super.config});

  /// Factory for ZPL printers (port 9100).
  factory TcpConnection.zpl(String host, {ConnectionConfig? config}) =>
      TcpConnection(host, 9100, config: config);

  /// Factory for CPCL printers (port 6101).
  factory TcpConnection.cpcl(String host, {ConnectionConfig? config}) =>
      TcpConnection(host, 6101, config: config);

  @override
  bool get isConnected => _isConnected;

  @override
  String get connectionDescription => 'TCP:$host:$port';

  @override
  Future<void> open() async {
    if (_isConnected) return;
    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: config.maxTimeoutForRead),
      );
      _isConnected = true;

      _subscription = _socket!.listen(
        (data) => _readBuffer.add(data),
        onError: (error) {
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
        },
      );
    } catch (e) {
      _isConnected = false;
      throw ConnectionException('Could not connect to device: $e', e);
    }
  }

  @override
  Future<void> close() async {
    if (!_isConnected) return;
    _isConnected = false;
    await _subscription?.cancel();
    _subscription = null;
    _socket?.destroy();
    _socket = null;
    _readBuffer.clear();
  }

  @override
  Future<void> writeRaw(Uint8List data) async {
    if (_socket == null || !_isConnected) {
      throw ConnectionClosedException();
    }
    try {
      _socket!.add(data);
      await _socket!.flush();
    } catch (e) {
      throw ConnectionException('Error writing to connection: $e', e);
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
