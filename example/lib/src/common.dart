import 'package:flutter/material.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import 'printer_page.dart';

/// Turns any error thrown by the plugin into a message for the user.
///
/// [UsbDeviceBusyException.remediation] is worth surfacing as-is: it tells the
/// user how to fix the problem (for example, the Windows driver binding).
String describeError(Object error) {
  if (error is UsbDeviceBusyException) {
    return error.remediation ?? error.message;
  }
  if (error is UsbLibLoadException) {
    return '${error.message}\n\nlibusb could not be loaded. '
        'On Windows, place libusb-1.0.dll next to the app executable.';
  }
  if (error is ConnectionTimeoutException) {
    return 'Printer not responding. Check it is on and in range.';
  }
  if (error is ConnectionException) return error.message;
  return error.toString();
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(describeError(error))));
}

/// Connects to [connection] and opens the printer screen.
///
/// `ZebraPrinter.connect` opens the connection itself. Don't call
/// `connection.open()` first.
Future<void> connectAndOpen(
  BuildContext context,
  Connection connection, {
  required String title,
}) async {
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 24),
          Text('Connecting…'),
        ],
      ),
    ),
  );

  ZebraPrinter printer;
  try {
    printer = await ZebraPrinter.connect(connection);
  } catch (e) {
    navigator.pop();
    if (context.mounted) showError(context, e);
    return;
  }
  navigator.pop();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PrinterPage(printer: printer, title: title),
    ),
  );
}

/// List row for a discovered printer.
class PrinterTile extends StatelessWidget {
  const PrinterTile({super.key, required this.printer, required this.onTap});

  final DiscoveredPrinter printer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (printer.connectionType) {
      ConnectionType.ble => Icons.bluetooth,
      ConnectionType.tcp => Icons.wifi,
      ConnectionType.usb => Icons.usb,
    };
    return ListTile(
      leading: Icon(icon),
      title: Text(printer.friendlyName),
      subtitle: Text(printer.address),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Centered hint shown when a list is empty.
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured box for platform notes and known issues.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.message, this.warning = false});

  final String message;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      color: warning ? scheme.errorContainer : scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              warning ? Icons.warning_amber : Icons.info_outline,
              color: warning
                  ? scheme.onErrorContainer
                  : scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: warning
                      ? scheme.onErrorContainer
                      : scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
