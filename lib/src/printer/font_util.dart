import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import 'zpl_sanitizer.dart';

/// Font download operations for Zebra printers.
///
/// Mirrors SDK's `FontUtil.java` and `FontConverterZpl.java`.
class FontUtil {
  FontUtil._();

  /// Download a TrueType font (.TTF) to the printer.
  ///
  /// Uses `~DY` command: `~DY{printerPath},T,T,{length},0,:{data}`.
  static Future<void> downloadTtfFont(
    Connection connection,
    Uint8List fontData,
    String printerPath,
  ) async {
    await _downloadFont(connection, fontData, printerPath, 'T', 'T');
  }

  /// Download a Zebra TrueType Extension font (.TTE) to the printer.
  ///
  /// Uses `~DY` command with TTE type markers.
  static Future<void> downloadTteFont(
    Connection connection,
    Uint8List fontData,
    String printerPath,
  ) async {
    await _downloadFont(connection, fontData, printerPath, 'T', 'E');
  }

  static Future<void> _downloadFont(
    Connection connection,
    Uint8List fontData,
    String printerPath,
    String format,
    String extension,
  ) async {
    ZplSanitizer.validatePath(printerPath);
    final header = '~DY$printerPath,$format,$extension,${fontData.length},0,:';
    final headerBytes = utf8.encode(header);
    final payload = Uint8List(headerBytes.length + fontData.length);
    payload.setAll(0, headerBytes);
    payload.setAll(headerBytes.length, fontData);
    await connection.write(payload);
  }
}
