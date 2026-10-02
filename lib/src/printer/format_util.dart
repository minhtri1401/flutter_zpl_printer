import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import '../graphics/graphics_util.dart';
import '../models/field_description.dart';
import 'file_util.dart';
import 'zpl_sanitizer.dart';

/// Stored format (template) operations.
///
/// Mirrors SDK's `FormatUtil.java` and `FormatUtilLinkOs.java`.
class FormatUtil {
  FormatUtil._();

  /// Retrieve a stored format's ZPL content from the printer.
  ///
  /// Sends `^XA^HF{formatPath}^FS^XZ` and returns the raw ZPL.
  static Future<String> retrieveFormat(
    Connection connection,
    String formatPath,
  ) async {
    ZplSanitizer.validatePath(formatPath);
    final command = '^XA^HF$formatPath^FS^XZ';
    final data = Uint8List.fromList(utf8.encode(command));
    final response = await connection.sendAndWaitForResponse(data);
    // Strip control characters (STX/ETX/CR/LF)
    return utf8
        .decode(response, allowMalformed: true)
        .replaceAll(RegExp(r'[\x00-\x1f]'), '');
  }

  /// Parse variable fields from a ZPL format string.
  ///
  /// Finds all `^FN` occurrences and extracts field number + optional name.
  /// Returns sorted list by field number.
  static List<FieldDescription> getVariableFields(String formatZpl) {
    final pattern = RegExp(r'\^FN(\d+)(?:"([^"]*)")?');
    final fields = <FieldDescription>[];
    final seen = <int>{};

    for (final match in pattern.allMatches(formatZpl)) {
      final number = int.parse(match.group(1)!);
      if (seen.add(number)) {
        fields.add(FieldDescription(
          fieldNumber: number,
          fieldName: match.group(2),
        ));
      }
    }

    fields.sort((a, b) => a.fieldNumber.compareTo(b.fieldNumber));
    return fields;
  }

  /// Print a stored format with variable data.
  ///
  /// Builds `^XA^XF{formatPath}^FN1^FD{vars[1]}^FS...^XZ` and sends it.
  static Future<void> printStoredFormat(
    Connection connection,
    String formatPath,
    Map<int, String> variables,
  ) async {
    ZplSanitizer.validatePath(formatPath);
    final buffer = StringBuffer('^XA^XF$formatPath');
    for (final entry in variables.entries) {
      final safeValue = ZplSanitizer.sanitizeFieldData(entry.value);
      buffer.write('^FN${entry.key}^FD$safeValue^FS');
    }
    buffer.write('^XZ');
    await connection.write(Uint8List.fromList(utf8.encode(buffer.toString())));
  }

  /// Print a stored format using named variables (convenience).
  ///
  /// Looks up field numbers by name from the ZPL source, then delegates
  /// to [printStoredFormat].
  static Future<void> printStoredFormatByName(
    Connection connection,
    String formatPath,
    Map<String, String> namedVariables,
    String formatZpl,
  ) async {
    final fields = getVariableFields(formatZpl);
    final numbered = <int, String>{};
    for (final entry in namedVariables.entries) {
      final field = fields.where((f) => f.fieldName == entry.key).firstOrNull;
      if (field != null) {
        numbered[field.fieldNumber] = entry.value;
      }
    }
    await printStoredFormat(connection, formatPath, numbered);
  }

  /// List all stored formats (*.ZPL files) on a drive.
  static Future<List<String>> listFormats(
    Connection connection, {
    String drive = 'E:',
  }) async {
    final objects = await FileUtil.listFiles(connection, drive: drive);
    return objects
        .where((o) => o.name.toUpperCase().endsWith('.ZPL'))
        .map((o) => o.name)
        .toList();
  }

  /// Print a stored format with variable text and image data.
  ///
  /// Images are stored temporarily as `R:SDK{nn}.GRF`, referenced
  /// in format variable fields via `^XG`. Temp files are cleaned up after print.
  static Future<void> printStoredFormatWithVarGraphics(
    Connection connection,
    String formatPath, {
    Map<int, Uint8List> imageVars = const {},
    Map<int, String> textVars = const {},
  }) async {
    ZplSanitizer.validatePath(formatPath);
    final tempFiles = <String>[];
    final mergedVars = Map<int, String>.from(textVars);

    var imgIndex = 1;
    for (final entry in imageVars.entries) {
      final grfPath = 'R:SDK${imgIndex.toString().padLeft(2, '0')}.GRF';
      await GraphicsUtil.storeImage(connection, grfPath, entry.value);
      tempFiles.add(grfPath);
      mergedVars[entry.key] = grfPath;
      imgIndex++;
    }

    try {
      await _printFormatWithImageVars(
          connection, formatPath, mergedVars, imageVars.keys.toSet());
    } finally {
      for (final path in tempFiles) {
        try {
          await FileUtil.deleteFile(connection, path);
        } catch (_) {}
      }
    }
  }

  static Future<void> _printFormatWithImageVars(
    Connection connection,
    String formatPath,
    Map<int, String> vars,
    Set<int> imageFieldNumbers,
  ) async {
    var zpl = await retrieveFormat(connection, formatPath);
    zpl = zpl.replaceAll(RegExp(r'\^DF[^\^]*'), '');

    for (final entry in vars.entries) {
      final fnPattern =
          RegExp(r'\^FN' + entry.key.toString() + r'(?=[^\d]|$)');
      if (imageFieldNumbers.contains(entry.key)) {
        zpl = zpl.replaceAll(fnPattern, '^XG${entry.value},1,1');
      } else {
        final safeValue = ZplSanitizer.sanitizeFieldData(entry.value);
        zpl = zpl.replaceAll(fnPattern, '^FD$safeValue');
      }
    }

    await connection.write(Uint8List.fromList(utf8.encode(zpl)));
  }
}
