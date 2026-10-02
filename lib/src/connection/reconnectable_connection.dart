import 'dart:convert';
import 'dart:typed_data';

import 'connection.dart';
import 'response_validators.dart';
import '../exceptions/connection_exception.dart';

/// Fired before each reconnect attempt.
typedef ReconnectCallback = void Function(int attempt, Duration nextDelay);

/// Fired after successful reconnect.
typedef ReconnectedCallback = void Function(int totalAttempts);

/// Fired when all retry attempts are exhausted.
typedef ReconnectFailedCallback = void Function(
    int totalAttempts, Object error);

/// Thrown after a successful reconnect (no auto-retry by design).
///
/// Callers catch this to know the connection was re-established
/// and should retry their operation explicitly.
class ReconnectSuccessException extends ConnectionException {
  final int reconnectAttempts;

  ReconnectSuccessException(this.reconnectAttempts)
      : super(
            'Connection re-established after $reconnectAttempts attempt(s). '
            'Retry your operation.');
}

/// Wrapper that auto-reconnects on disconnect with exponential backoff.
///
/// Transport-agnostic: wraps any [Connection] subclass (TCP, BLE, multichannel).
/// After reconnect, throws [ReconnectSuccessException] -- caller decides what to retry.
class ReconnectableConnection extends Connection {
  final Connection _inner;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final ReconnectCallback? onReconnecting;
  final ReconnectedCallback? onReconnected;
  final ReconnectFailedCallback? onReconnectFailed;

  int _reconnectAttempts = 0;

  /// Number of reconnect attempts since last successful operation.
  int get reconnectAttempts => _reconnectAttempts;

  ReconnectableConnection(
    this._inner, {
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.onReconnecting,
    this.onReconnected,
    this.onReconnectFailed,
  }) : super(config: _inner.config);

  @override
  bool get isConnected => _inner.isConnected;

  @override
  String get connectionDescription => _inner.connectionDescription;

  @override
  Future<void> open() => _inner.open();

  @override
  Future<void> close() => _inner.close();

  @override
  Future<Uint8List?> read() => _inner.read();

  @override
  Future<int> bytesAvailable() => _inner.bytesAvailable();

  @override
  Future<void> writeRaw(Uint8List data) => _inner.writeRaw(data);

  @override
  Future<void> write(Uint8List data) async {
    try {
      await _inner.write(data);
      _reconnectAttempts = 0;
    } on ConnectionException {
      await _reconnect();
      throw ReconnectSuccessException(_reconnectAttempts);
    }
  }

  @override
  Future<Uint8List> sendAndWaitForResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    String? endOfResponseMarker,
  }) async {
    try {
      final result = await _inner.sendAndWaitForResponse(
        data,
        initialTimeout: initialTimeout,
        readTimeout: readTimeout,
        endOfResponseMarker: endOfResponseMarker,
      );
      _reconnectAttempts = 0;
      return result;
    } on ConnectionException {
      await _reconnect();
      throw ReconnectSuccessException(_reconnectAttempts);
    }
  }

  @override
  Future<Uint8List> sendAndWaitForValidResponse(
    Uint8List data, {
    int? initialTimeout,
    int? readTimeout,
    required ResponseValidator validator,
  }) async {
    try {
      final result = await _inner.sendAndWaitForValidResponse(
        data,
        initialTimeout: initialTimeout,
        readTimeout: readTimeout,
        validator: validator,
      );
      _reconnectAttempts = 0;
      return result;
    } on ConnectionException {
      await _reconnect();
      throw ReconnectSuccessException(_reconnectAttempts);
    }
  }

  /// Attempt reconnect with exponential backoff.
  Future<void> _reconnect() async {
    // Close current connection (ignore errors)
    await _inner.close().catchError((_) {});

    Object? lastError;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      final delay = _backoffDelay(attempt);
      onReconnecting?.call(attempt, delay);

      await Future.delayed(delay);

      try {
        await _inner.open();
        // Verify with SGD ping
        await _ping();
        _reconnectAttempts = attempt;
        onReconnected?.call(attempt);
        return;
      } catch (e) {
        lastError = e;
        await _inner.close().catchError((_) {});
      }
    }

    _reconnectAttempts = maxRetries;
    final error = lastError ??
        ConnectionException('Reconnect failed - no attempts made');
    onReconnectFailed?.call(maxRetries, error);
    throw ConnectionException(
      'Reconnect failed after $maxRetries attempts',
      error,
    );
  }

  /// Exponential backoff: initialDelay * 2^(attempt-1), capped at maxDelay.
  Duration _backoffDelay(int attempt) {
    final ms = initialDelay.inMilliseconds * (1 << (attempt - 1));
    return Duration(
        milliseconds: ms > maxDelay.inMilliseconds
            ? maxDelay.inMilliseconds
            : ms);
  }

  /// Verify connection with SGD ping using semantic validator.
  Future<void> _ping() async {
    final ping =
        Uint8List.fromList(utf8.encode('! U1 getvar "appl.name"\r\n'));
    await _inner.sendAndWaitForValidResponse(
      ping,
      validator: ResponseValidators.sgd(),
    );
  }
}
