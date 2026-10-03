import 'dart:typed_data';

import '../connection/connection.dart';
import 'file_util.dart';
import 'sgd.dart';

/// Firmware update operations for Zebra printers.
///
/// Mirrors SDK's `FirmwareUpdaterLinkOs.java`.
///
/// **WARNING:** After firmware upload, the printer reboots automatically.
/// The connection will be lost. Caller is responsible for reconnection
/// (e.g., wrap connection in ReconnectableConnection).
///
/// **WARNING:** Caller must ensure firmware file is valid for the target
/// printer model. No integrity check is performed.
class FirmwareUtil {
  FirmwareUtil._();

  /// Get the current firmware version string via SGD `appl.name`.
  static Future<String> getCurrentFirmwareVersion(Connection connection) =>
      Sgd.get('appl.name', connection);

  /// Update firmware if [firmwareName] differs from the installed version.
  ///
  /// Returns `true` if firmware was sent, `false` if version already matches.
  /// After upload, printer reboots — connection will be lost.
  static Future<bool> updateFirmware(
    Connection connection,
    Uint8List firmwareBytes, {
    required String firmwareName,
    void Function(int sent, int total)? onProgress,
  }) async {
    final currentVersion = await getCurrentFirmwareVersion(connection);
    if (_isSameVersion(currentVersion, firmwareName)) return false;
    await _sendFirmware(connection, firmwareBytes, onProgress);
    return true;
  }

  /// Send firmware unconditionally, skipping version check.
  ///
  /// After upload, printer reboots — connection will be lost.
  static Future<void> updateFirmwareUnconditionally(
    Connection connection,
    Uint8List firmwareBytes, {
    void Function(int sent, int total)? onProgress,
  }) => _sendFirmware(connection, firmwareBytes, onProgress);

  static bool _isSameVersion(String currentVersion, String firmwareName) {
    // Strip file extension from firmware filename for comparison.
    // Use equality (not contains) to avoid false matches like "V7" in "V75.x".
    final normalized = firmwareName
        .toUpperCase()
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .trim();
    final current = currentVersion.toUpperCase().trim();
    return current == normalized;
  }

  static Future<void> _sendFirmware(
    Connection connection,
    Uint8List data,
    void Function(int, int)? onProgress,
  ) => FileUtil.sendFileContents(connection, data, onProgress: onProgress);
}
