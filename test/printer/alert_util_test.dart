import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

void main() {
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

  group('AlertUtil.configureAlerts', () {
    test('sends SGD alerts.add for each alert', () async {
      final alerts = [
        const PrinterAlert(
          condition: AlertCondition.paperOut,
          destination: AlertDestination.tcp,
          destinationAddress: '192.168.1.100',
          port: 9100,
        ),
      ];

      await AlertUtil.configureAlerts(conn, alerts);

      expect(
        conn.allWrittenString,
        '! U1 setvar "alerts.add" "PAPER_OUT,TCP,YES,NO,192.168.1.100,9100"\r\n',
      );
    });
  });

  group('AlertUtil.getConfiguredAlerts', () {
    test('parses alert response', () async {
      conn.queueStringResponse('"PAPER_OUT,TCP,YES,NO,192.168.1.100,9100"');

      final alerts = await AlertUtil.getConfiguredAlerts(conn);

      expect(alerts.length, 1);
      expect(alerts[0].condition, AlertCondition.paperOut);
      expect(alerts[0].destination, AlertDestination.tcp);
      expect(alerts[0].onSet, true);
      expect(alerts[0].onClear, false);
      expect(alerts[0].destinationAddress, '192.168.1.100');
      expect(alerts[0].port, 9100);
    });

    test('handles empty response', () async {
      conn.queueStringResponse('""');

      final alerts = await AlertUtil.getConfiguredAlerts(conn);

      expect(alerts, isEmpty);
    });
  });

  group('AlertUtil.removeAlerts', () {
    test('sends SGD alerts.remove', () async {
      final alerts = [
        const PrinterAlert(
          condition: AlertCondition.headOpen,
          destination: AlertDestination.email,
          onSet: true,
          onClear: true,
          destinationAddress: 'admin@example.com',
          port: 25,
        ),
      ];

      await AlertUtil.removeAlerts(conn, alerts);

      expect(
        conn.allWrittenString,
        '! U1 setvar "alerts.remove" "HEAD_OPEN,EMAIL,YES,YES,admin@example.com,25"\r\n',
      );
    });
  });

  group('PrinterAlert.toSgdConfig', () {
    test('formats correctly', () {
      const alert = PrinterAlert(
        condition: AlertCondition.ribbonOut,
        destination: AlertDestination.snmp,
        onSet: false,
        onClear: true,
        destinationAddress: '10.0.0.1',
        port: 162,
      );

      expect(alert.toSgdConfig(), 'RIBBON_OUT,SNMP,NO,YES,10.0.0.1,162');
    });
  });
}
