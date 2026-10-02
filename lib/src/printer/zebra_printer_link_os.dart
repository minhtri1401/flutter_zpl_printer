import 'dart:typed_data';

import '../models/link_os_version.dart';
import '../models/printer_alert.dart';
import 'alert_util.dart';
import 'firmware_util.dart';
import 'font_util.dart';
import 'format_util.dart';
import 'profile_util.dart';
import 'sgd.dart';
import 'zebra_printer.dart';

/// LinkOs and enterprise extensions for [ZebraPrinter].
extension ZebraPrinterLinkOs on ZebraPrinter {
  /// Get the Link-OS version, or `null` if not a Link-OS printer.
  Future<LinkOsVersion?> getLinkOsVersion() async {
    try {
      final version = await Sgd.get('appl.link_os_version', connection);
      return LinkOsVersion.parse(version);
    } catch (_) {
      return null;
    }
  }

  /// Download a TrueType font to the printer.
  Future<void> downloadTtfFont(Uint8List fontData, String printerPath) =>
      FontUtil.downloadTtfFont(connection, fontData, printerPath);

  /// Download a TTE font to the printer.
  Future<void> downloadTteFont(Uint8List fontData, String printerPath) =>
      FontUtil.downloadTteFont(connection, fontData, printerPath);

  /// Configure alerts on the printer.
  Future<void> configureAlerts(List<PrinterAlert> alerts) =>
      AlertUtil.configureAlerts(connection, alerts);

  /// Get currently configured alerts.
  Future<List<PrinterAlert>> getConfiguredAlerts() =>
      AlertUtil.getConfiguredAlerts(connection);

  /// Remove alerts from the printer.
  Future<void> removeAlerts(List<PrinterAlert> alerts) =>
      AlertUtil.removeAlerts(connection, alerts);

  /// Remove all configured alerts from the printer.
  Future<void> removeAllAlerts() => AlertUtil.removeAllAlerts(connection);

  /// Print a stored format with variable text and image data.
  Future<void> printStoredFormatWithVarGraphics(
    String formatPath, {
    Map<int, Uint8List> imageVars = const {},
    Map<int, String> textVars = const {},
  }) =>
      FormatUtil.printStoredFormatWithVarGraphics(
        connection,
        formatPath,
        imageVars: imageVars,
        textVars: textVars,
      );

  /// Snapshot printer configuration to ZIP bytes.
  Future<Uint8List> createProfile({void Function(String)? onProgress}) =>
      ProfileUtil.createProfile(connection, onProgress: onProgress);

  /// Alias for [createProfile] — SDK parity.
  Future<Uint8List> createBackup({void Function(String)? onProgress}) =>
      ProfileUtil.createProfile(connection, onProgress: onProgress);

  /// Restore printer configuration from profile ZIP bytes.
  Future<void> loadProfile(
    Uint8List profileBytes, {
    FileDeletionOption deletionOption = FileDeletionOption.none,
    void Function(String)? onProgress,
  }) =>
      ProfileUtil.loadProfile(connection, profileBytes,
          deletionOption: deletionOption, onProgress: onProgress);

  /// Alias for [loadProfile] — SDK parity.
  Future<void> loadBackup(
    Uint8List profileBytes, {
    FileDeletionOption deletionOption = FileDeletionOption.none,
    void Function(String)? onProgress,
  }) =>
      ProfileUtil.loadProfile(connection, profileBytes,
          deletionOption: deletionOption, onProgress: onProgress);

  /// Get current firmware version string.
  Future<String> getFirmwareVersion() =>
      FirmwareUtil.getCurrentFirmwareVersion(connection);

  /// Update firmware if version differs. Returns true if updated.
  /// Printer reboots after update — connection will be lost.
  Future<bool> updateFirmware(
    Uint8List firmwareBytes, {
    required String firmwareName,
    void Function(int sent, int total)? onProgress,
  }) =>
      FirmwareUtil.updateFirmware(connection, firmwareBytes,
          firmwareName: firmwareName, onProgress: onProgress);

  /// Send firmware unconditionally (skip version check).
  /// Printer reboots after update — connection will be lost.
  Future<void> updateFirmwareUnconditionally(
    Uint8List firmwareBytes, {
    void Function(int sent, int total)? onProgress,
  }) =>
      FirmwareUtil.updateFirmwareUnconditionally(connection, firmwareBytes,
          onProgress: onProgress);
}
