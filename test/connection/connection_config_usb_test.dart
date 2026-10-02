import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/src/connection/connection_config.dart';

void main() {
  group('ConnectionConfig USB fields', () {
    test('defaults', () {
      const c = ConnectionConfig();
      expect(c.usbBulkTimeoutMs, 5000);
      expect(c.usbMaxChunkSize, 0);
      expect(c.usbStallRetries, 2);
      expect(c.usbDetachKernelDriver, isTrue);
    });

    test('overrides', () {
      const c = ConnectionConfig(
        usbBulkTimeoutMs: 2000,
        usbMaxChunkSize: 512,
        usbStallRetries: 0,
        usbDetachKernelDriver: false,
      );
      expect(c.usbBulkTimeoutMs, 2000);
      expect(c.usbMaxChunkSize, 512);
      expect(c.usbStallRetries, 0);
      expect(c.usbDetachKernelDriver, isFalse);
    });

    test('copyWith preserves USB fields', () {
      const original = ConnectionConfig(usbBulkTimeoutMs: 8000);
      final copy = original.copyWith(maxChunkSize: 2048);
      expect(copy.usbBulkTimeoutMs, 8000);
      expect(copy.maxChunkSize, 2048);
    });

    test('copyWith can override USB fields', () {
      const original = ConnectionConfig();
      final copy = original.copyWith(usbStallRetries: 5);
      expect(copy.usbStallRetries, 5);
    });

    test('non-USB defaults unchanged (regression)', () {
      const c = ConnectionConfig();
      expect(c.maxTimeoutForRead, 5000);
      expect(c.maxChunkSize, 1024);
    });
  });
}
