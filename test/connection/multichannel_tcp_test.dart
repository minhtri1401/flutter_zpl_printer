import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  group('MultichannelTcpConnection', () {
    test('connectionDescription includes both ports', () {
      final conn = MultichannelTcpConnection('192.168.1.10');
      expect(conn.connectionDescription, 'TCP_MULTI:192.168.1.10:9100:9200');
    });

    test('connectionDescription with custom ports', () {
      final conn = MultichannelTcpConnection(
        '10.0.0.1',
        printPort: 6101,
        statusPort: 6102,
      );
      expect(conn.connectionDescription, 'TCP_MULTI:10.0.0.1:6101:6102');
    });

    test('exposes printConnection and statusConnection', () {
      final conn = MultichannelTcpConnection('192.168.1.10');
      expect(conn.printConnection, isNotNull);
      expect(conn.statusConnection, isNotNull);
      expect(conn.printConnection.connectionDescription, 'TCP:192.168.1.10:9100');
      expect(conn.statusConnection.connectionDescription, 'TCP:192.168.1.10:9200');
    });

    test('isConnected false when not opened', () {
      final conn = MultichannelTcpConnection('192.168.1.10');
      expect(conn.isConnected, false);
    });
  });
}
