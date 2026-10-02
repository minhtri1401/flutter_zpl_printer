import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

/// Mock connection for testing printer operations without hardware.
///
/// Records all written data and returns queued responses.
class MockConnection extends Connection {
  final List<Uint8List> writtenData = [];
  final Queue<Uint8List> responseQueue = Queue();
  bool _isConnected = false;
  bool openCalled = false;
  bool closeCalled = false;

  int openCallCount = 0;
  int failOpenCount = 0;

  MockConnection({super.config});

  /// Simulate a disconnect (for reconnect testing).
  void simulateDisconnect() => _isConnected = false;

  /// Enqueue a canned response that will be returned by [read].
  void queueResponse(Uint8List data) => responseQueue.add(data);

  /// Enqueue a string response (convenience).
  void queueStringResponse(String data) =>
      queueResponse(Uint8List.fromList(data.codeUnits));

  @override
  bool get isConnected => _isConnected;

  @override
  String get connectionDescription => 'Mock';

  @override
  Future<void> open() async {
    openCalled = true;
    openCallCount++;
    if (failOpenCount > 0) {
      failOpenCount--;
      throw ConnectionException('Mock open failure');
    }
    _isConnected = true;
  }

  @override
  Future<void> close() async {
    closeCalled = true;
    _isConnected = false;
  }

  @override
  Future<void> writeRaw(Uint8List data) async {
    writtenData.add(Uint8List.fromList(data));
  }

  @override
  Future<Uint8List?> read() async {
    if (responseQueue.isEmpty) return null;
    return responseQueue.removeFirst();
  }

  @override
  Future<int> bytesAvailable() async =>
      responseQueue.isEmpty ? 0 : responseQueue.first.length;

  /// Get all written data concatenated as a single byte list.
  Uint8List get allWrittenBytes {
    final builder = BytesBuilder();
    for (final data in writtenData) {
      builder.add(data);
    }
    return builder.toBytes();
  }

  /// Get all written data as a single string.
  String get allWrittenString => String.fromCharCodes(allWrittenBytes);
}
