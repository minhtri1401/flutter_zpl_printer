import 'dart:typed_data';

import 'connection_config.dart';
import '../exceptions/connection_exception.dart';

/// Callback to determine if a response is complete.
/// Mirrors SDK's `ResponseValidator.isResponseComplete(byte[])`.
typedef ResponseValidator = bool Function(Uint8List data);

/// Abstract connection interface for Zebra printers.
///
/// Mirrors SDK's `Connection` + `ConnectionA` pattern.
/// Subclasses implement transport-specific open/close/read/write.
/// Chunked write and sendAndWait logic are provided here.
abstract class Connection {
  ConnectionConfig config;

  Connection({ConnectionConfig? config})
      : config = config ?? const ConnectionConfig();

  /// Open the connection to the printer.
  Future<void> open();

  /// Close the connection.
  Future<void> close();

  /// Whether the connection is currently open.
  bool get isConnected;

  /// Number of bytes available to read without blocking.
  Future<int> bytesAvailable();

  /// Read all available bytes from the connection. Returns null if none.
  Future<Uint8List?> read();

  /// Write raw bytes to the underlying transport (single chunk, no splitting).
  Future<void> writeRaw(Uint8List data);

  /// Human-readable description (e.g. "TCP:192.168.1.10:9100").
  String get connectionDescription;

  /// Write data with chunking matching SDK's ConnectionA behavior.
  /// Splits into [config.maxChunkSize] byte chunks with [config.interChunkDelayMs] delay.
  Future<void> write(Uint8List data) async {
    if (!isConnected) {
      throw ConnectionClosedException();
    }
    final chunkSize = config.maxChunkSize;
    int offset = 0;
    int remaining = data.length;

    while (remaining > 0) {
      final size = remaining > chunkSize ? chunkSize : remaining;
      final chunk = Uint8List.sublistView(data, offset, offset + size);
      await writeRaw(chunk);
      if (config.interChunkDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: config.interChunkDelayMs));
      }
      offset += size;
      remaining -= size;
    }
  }

  /// Wait until data is available or timeout expires.
  /// Polls every 50ms matching SDK's `Sleeper.sleep(50L)`.
  Future<void> waitForData(int timeoutMs) async {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (await bytesAvailable() == 0 && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Send data and wait for response, optionally checking for an end-of-response marker.
  /// Matches SDK's `ConnectionA.sendAndWaitForResponse`.
  /// Outer deadline prevents infinite hang when printer trickles data.
  Future<Uint8List> sendAndWaitForResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    String? endOfResponseMarker,
  }) async {
    if (!isConnected) {
      throw ConnectionClosedException('No Printer Connection');
    }
    final initTimeout = initialTimeout ?? config.maxTimeoutForRead;
    final moreTimeout = readTimeout ?? config.timeToWaitForMoreData;
    // Outer deadline: initial timeout + 10x more-data waits max
    final outerDeadline = DateTime.now().add(
      Duration(milliseconds: initTimeout + moreTimeout * 10),
    );

    await write(data);
    await waitForData(initTimeout);

    final buffer = BytesBuilder();
    while (await bytesAvailable() > 0) {
      final chunk = await read();
      if (chunk != null) {
        buffer.add(chunk);
      }
      if (_shouldWaitForData(buffer.toBytes(), endOfResponseMarker)) {
        if (DateTime.now().isAfter(outerDeadline)) break;
        await waitForData(moreTimeout);
      }
    }
    return buffer.takeBytes();
  }

  /// Send data and wait for a valid response as determined by [validator].
  /// Matches SDK's `ConnectionA.sendAndWaitForValidResponse`.
  /// Outer deadline prevents infinite hang when printer trickles data.
  Future<Uint8List> sendAndWaitForValidResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    required ResponseValidator validator,
  }) async {
    if (!isConnected) {
      throw ConnectionClosedException('No Printer Connection');
    }
    final initTimeout = initialTimeout ?? config.maxTimeoutForRead;
    final moreTimeout = readTimeout ?? config.timeToWaitForMoreData;
    final outerDeadline = DateTime.now().add(
      Duration(milliseconds: initTimeout + moreTimeout * 10),
    );

    await write(data);
    await waitForData(initTimeout);

    final buffer = BytesBuilder();
    while (await bytesAvailable() > 0) {
      final chunk = await read();
      if (chunk != null) {
        buffer.add(chunk);
      }
      if (!validator(buffer.toBytes())) {
        if (DateTime.now().isAfter(outerDeadline)) break;
        await waitForData(moreTimeout);
      }
    }
    return buffer.takeBytes();
  }

  bool _shouldWaitForData(Uint8List accumulated, String? endMarker) {
    if (endMarker == null) return true;
    final str = String.fromCharCodes(accumulated);
    return !str.contains(endMarker);
  }
}
