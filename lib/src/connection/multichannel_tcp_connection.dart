import 'dart:typed_data';

import 'connection.dart';
import 'tcp_connection.dart';

/// Dual-channel TCP connection for concurrent print and status operations.
///
/// Port 9100 handles print data, port 9200 handles status/SGD queries.
/// Mirrors SDK's `MultichannelTcpConnection`.
class MultichannelTcpConnection extends Connection {
  final String host;
  final int printPort;
  final int statusPort;

  late final TcpConnection _printConnection;
  late final TcpConnection _statusConnection;

  MultichannelTcpConnection(
    this.host, {
    this.printPort = 9100,
    this.statusPort = 9200,
    super.config,
  }) {
    _printConnection = TcpConnection(host, printPort, config: config);
    _statusConnection = TcpConnection(host, statusPort, config: config);
  }

  /// Direct access to the print channel.
  Connection get printConnection => _printConnection;

  /// Direct access to the status channel.
  Connection get statusConnection => _statusConnection;

  @override
  bool get isConnected =>
      _printConnection.isConnected && _statusConnection.isConnected;

  @override
  String get connectionDescription => 'TCP_MULTI:$host:$printPort:$statusPort';

  @override
  Future<void> open() async {
    try {
      await _printConnection.open();
      await _statusConnection.open();
    } catch (e) {
      // Clean up on partial failure
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

  /// Send command on status channel and wait for response.
  ///
  /// Overrides base to route through status connection instead of print.
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

  /// Send command on status channel and wait for validated response.
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
