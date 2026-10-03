import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  group('ReconnectableConnection', () {
    late MockConnection inner;

    setUp(() {
      inner = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
    });

    test('normal write delegates to inner', () async {
      await inner.open();
      final conn = ReconnectableConnection(inner);

      await conn.write(Uint8List.fromList([1, 2, 3]));

      expect(inner.writtenData.length, greaterThan(0));
      expect(conn.reconnectAttempts, 0);
    });

    test(
      'disconnect during write triggers reconnect then throws ReconnectSuccessException',
      () async {
        await inner.open();
        final conn = ReconnectableConnection(
          inner,
          maxRetries: 3,
          initialDelay: Duration.zero,
        );

        // Simulate disconnect so next write fails
        inner.simulateDisconnect();
        // Queue SGD ping response for reconnect verification
        inner.queueStringResponse('"ZPL"');

        expect(
          () => conn.write(Uint8List.fromList([1, 2, 3])),
          throwsA(isA<ReconnectSuccessException>()),
        );
      },
    );

    test('reconnect succeeds after N open failures', () async {
      await inner.open();
      final conn = ReconnectableConnection(
        inner,
        maxRetries: 5,
        initialDelay: Duration.zero,
      );

      inner.simulateDisconnect();
      inner.failOpenCount = 2; // Fail first 2 opens
      // Queue ping response for successful attempt
      inner.queueStringResponse('"ZPL"');

      try {
        await conn.write(Uint8List.fromList([1]));
      } on ReconnectSuccessException catch (e) {
        expect(e.reconnectAttempts, 3); // Failed 2, succeeded on 3rd
        return;
      }
      fail('Expected ReconnectSuccessException');
    });

    test('max retries exhausted throws ConnectionException', () async {
      await inner.open();
      final conn = ReconnectableConnection(
        inner,
        maxRetries: 2,
        initialDelay: Duration.zero,
      );

      inner.simulateDisconnect();
      inner.failOpenCount = 999; // Always fail

      expect(
        () => conn.write(Uint8List.fromList([1])),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('onReconnecting callback fires', () async {
      await inner.open();
      final attempts = <int>[];
      final conn = ReconnectableConnection(
        inner,
        maxRetries: 3,
        initialDelay: Duration.zero,
        onReconnecting: (attempt, _) => attempts.add(attempt),
      );

      inner.simulateDisconnect();
      inner.queueStringResponse('"ZPL"');

      try {
        await conn.write(Uint8List.fromList([1]));
      } on ReconnectSuccessException {
        // expected
      }

      expect(attempts, [1]);
    });

    test('onReconnected callback fires on success', () async {
      await inner.open();
      int? reconnectedAt;
      final conn = ReconnectableConnection(
        inner,
        initialDelay: Duration.zero,
        onReconnected: (attempts) => reconnectedAt = attempts,
      );

      inner.simulateDisconnect();
      inner.queueStringResponse('"ZPL"');

      try {
        await conn.write(Uint8List.fromList([1]));
      } on ReconnectSuccessException {
        // expected
      }

      expect(reconnectedAt, 1);
    });

    test('onReconnectFailed callback fires on exhaustion', () async {
      await inner.open();
      int? failedAttempts;
      final conn = ReconnectableConnection(
        inner,
        maxRetries: 1,
        initialDelay: Duration.zero,
        onReconnectFailed: (attempts, _) => failedAttempts = attempts,
      );

      inner.simulateDisconnect();
      inner.failOpenCount = 999;

      try {
        await conn.write(Uint8List.fromList([1]));
      } on ConnectionException {
        // expected
      }

      expect(failedAttempts, 1);
    });

    test('maxRetries=0 does not throw null assertion error', () async {
      await inner.open();
      final conn = ReconnectableConnection(
        inner,
        maxRetries: 0,
        initialDelay: Duration.zero,
      );

      inner.simulateDisconnect();

      // Should throw ConnectionException, NOT a null assertion error
      expect(
        () => conn.write(Uint8List.fromList([1])),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('connectionDescription delegates to inner', () async {
      final conn = ReconnectableConnection(inner);
      expect(conn.connectionDescription, 'Mock');
    });

    test('isConnected delegates to inner', () async {
      final conn = ReconnectableConnection(inner);
      expect(conn.isConnected, false);
      await inner.open();
      expect(conn.isConnected, true);
    });
  });
}
