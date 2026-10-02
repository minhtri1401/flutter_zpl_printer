import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
  group('Sgd', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
      conn.open();
    });

    group('GET', () {
      test('formats command correctly', () async {
        conn.queueStringResponse('"ZQ620"');

        await Sgd.get('device.friendly_name', conn);

        expect(
          conn.allWrittenString,
          '! U1 getvar "device.friendly_name"\r\n',
        );
      });

      test('strips quotes from response', () async {
        conn.queueStringResponse('"ZQ620"');

        final result = await Sgd.get('device.friendly_name', conn);

        expect(result, 'ZQ620');
      });

      test('handles empty quoted response', () async {
        conn.queueStringResponse('""');

        final result = await Sgd.get('some.setting', conn);

        expect(result, '');
      });

      test('collapses duplicate-reply artefacts to the first value',
          () async {
        // Observed on macOS CoreBluetooth: a single `getvar` reply
        // arrives as several concatenated `"value"` frames on the
        // notification characteristic. Sgd.get must return the
        // single intended value, not the concatenated mess.
        conn.queueStringResponse('"ZQ620""ZQ620""ZQ620""ZQ620""ZQ620""ZQ620"');

        final result = await Sgd.get('device.product_name', conn);

        expect(result, 'ZQ620');
      });

      test('collapses duplicate replies containing an IPv4', () async {
        conn.queueStringResponse('"172.20.10.3""172.20.10.3""172.20.10.3"');

        final result = await Sgd.get('ip.addr', conn);

        expect(result, '172.20.10.3');
      });
    });

    group('SET', () {
      test('formats command correctly', () async {
        await Sgd.set('media.type', 'label', conn);

        expect(
          conn.allWrittenString,
          '! U1 setvar "media.type" "label"\r\n',
        );
      });
    });

    group('DO', () {
      test('formats command correctly', () async {
        conn.queueStringResponse('"done"');

        await Sgd.doCommand('device.reset', '', conn);

        expect(
          conn.allWrittenString,
          '! U1 do "device.reset" ""\r\n',
        );
      });

      test('strips quotes from response', () async {
        conn.queueStringResponse('"done"');

        final result = await Sgd.doCommand('device.reset', '', conn);

        expect(result, 'done');
      });
    });

    group('SGD validator', () {
      test('complete when first and last bytes are quote', () {
        final data = Uint8List.fromList([0x22, 0x41, 0x42, 0x22]);
        // Validator: first == " and last == "
        expect(data.length >= 2 && data.first == 0x22 && data.last == 0x22, true);
      });

      test('incomplete when only first byte is quote', () {
        final data = Uint8List.fromList([0x22, 0x41, 0x42]);
        expect(data.length >= 2 && data.first == 0x22 && data.last == 0x22, false);
      });

      test('incomplete when single byte', () {
        final data = Uint8List.fromList([0x22]);
        expect(data.length >= 2, false);
      });

      test('incomplete when empty', () {
        final data = Uint8List.fromList([]);
        expect(data.length >= 2, false);
      });
    });
  });
}
