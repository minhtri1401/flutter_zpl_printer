import 'dart:typed_data';
import 'printer_alert.dart';

/// In-memory representation of a printer profile (settings + files + alerts).
class PrinterProfile {
  final Map<String, String> settings;
  final List<PrinterAlert> alerts;
  final Map<String, Uint8List> files; // printer path -> file bytes

  const PrinterProfile({
    required this.settings,
    required this.alerts,
    required this.files,
  });
}
