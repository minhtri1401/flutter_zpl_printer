import '../connection/connection.dart';
import '../models/printer_alert.dart';
import 'sgd.dart';

/// Alert management for Zebra printers.
///
/// Mirrors SDK's `AlertProvider.java`.
class AlertUtil {
  AlertUtil._();

  /// Configure alerts on the printer.
  ///
  /// Each alert is added via SGD `alerts.add` command.
  static Future<void> configureAlerts(
    Connection connection,
    List<PrinterAlert> alerts,
  ) async {
    for (final alert in alerts) {
      await Sgd.set('alerts.add', alert.toSgdConfig(), connection);
    }
  }

  /// Get currently configured alerts from the printer.
  ///
  /// Queries SGD `alerts.configured` and parses the response.
  static Future<List<PrinterAlert>> getConfiguredAlerts(
    Connection connection,
  ) async {
    final response = await Sgd.get('alerts.configured', connection);
    if (response.trim().isEmpty) return [];

    final alerts = <PrinterAlert>[];
    // Response is semicolon-separated alert entries
    final entries = response.split(';');
    for (final entry in entries) {
      final parts = entry.split(',');
      if (parts.length < 6) continue;

      final condition = AlertCondition.fromSgd(parts[0]);
      if (condition == null) continue;

      final destination = AlertDestination.values.where(
        (d) => d.sgdValue == parts[1].trim().toUpperCase(),
      );
      if (destination.isEmpty) continue;

      alerts.add(
        PrinterAlert(
          condition: condition,
          destination: destination.first,
          onSet: parts[2].trim().toUpperCase() == 'YES',
          onClear: parts[3].trim().toUpperCase() == 'YES',
          destinationAddress: parts[4].trim(),
          port: int.tryParse(parts[5].trim()) ?? 0,
        ),
      );
    }
    return alerts;
  }

  /// Remove specific alerts from the printer.
  static Future<void> removeAlerts(
    Connection connection,
    List<PrinterAlert> alerts,
  ) async {
    for (final alert in alerts) {
      await Sgd.set('alerts.remove', alert.toSgdConfig(), connection);
    }
  }

  /// Remove all configured alerts from the printer.
  static Future<void> removeAllAlerts(Connection connection) async {
    await Sgd.set('alerts.configured', '', connection);
  }
}
