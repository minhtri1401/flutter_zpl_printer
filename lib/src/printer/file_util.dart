import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import '../models/printer_object.dart';
import '../models/storage_info.dart';
import 'sgd.dart';
import 'zpl_sanitizer.dart';

/// Printer filesystem operations.
///
/// Mirrors SDK's `FileUtil.java` and `FileUtilLinkOs.java`.
/// All methods are static and operate on a [Connection].
class FileUtil {
  FileUtil._();

  /// List files on a specific drive.
  ///
  /// Sends `^XA^HW{drive}*.*^XZ` (host directory list), which returns the
  /// listing to the host. `^WD` would print a directory label instead.
  static Future<List<PrinterObject>> listFiles(
    Connection connection, {
    String drive = 'E:',
  }) async {
    ZplSanitizer.validateDrive(drive);
    final command = '^XA^HW$drive*.*^XZ';
    final data = Uint8List.fromList(utf8.encode(command));
    // The listing is framed by STX ... ETX.
    final response = await connection.sendAndWaitForResponse(
      data,
      endOfResponseMarker: '\x03',
    );
    return _parseFileList(utf8.decode(response, allowMalformed: true));
  }

  /// Retrieve all file names across R: and E: drives.
  static Future<List<String>> retrieveFileNames(Connection connection) async {
    final files = <String>[];
    for (final drive in ['E:', 'R:']) {
      try {
        final objects = await listFiles(connection, drive: drive);
        files.addAll(objects.map((o) => o.name));
      } catch (_) {
        // Drive may not be available
      }
    }
    return files;
  }

  /// Retrieve file names filtered by extension(s) (case-insensitive).
  static Future<List<String>> retrieveFileNamesByExtension(
    Connection connection,
    List<String> extensions,
  ) async {
    final allNames = await retrieveFileNames(connection);
    final upperExts = extensions.map((e) => e.toUpperCase()).toSet();
    return allNames.where((name) {
      final dot = name.lastIndexOf('.');
      if (dot < 0) return false;
      return upperExts.contains(name.substring(dot + 1).toUpperCase());
    }).toList();
  }

  /// Send raw bytes to the printer (e.g. a ZPL template file).
  static Future<void> sendFileContents(
    Connection connection,
    Uint8List data, {
    void Function(int sent, int total)? onProgress,
  }) async {
    const chunkSize = 1024;
    int offset = 0;
    while (offset < data.length) {
      final end = (offset + chunkSize > data.length)
          ? data.length
          : offset + chunkSize;
      final chunk = Uint8List.sublistView(data, offset, end);
      await connection.write(chunk);
      offset = end;
      onProgress?.call(offset, data.length);
    }
  }

  /// Store a file on the printer filesystem using `~DY` command.
  static Future<void> storeFile(
    Connection connection,
    String targetPath,
    Uint8List data,
  ) async {
    ZplSanitizer.validatePath(targetPath);
    final header = '~DY$targetPath,B,P,${data.length},0,:';
    final headerBytes = utf8.encode(header);
    final payload = Uint8List(headerBytes.length + data.length);
    payload.setAll(0, headerBytes);
    payload.setAll(headerBytes.length, data);
    await connection.write(payload);
  }

  /// Retrieve a file's contents from the printer via SGD.
  static Future<Uint8List> getFile(
    Connection connection,
    String filePath,
  ) async {
    ZplSanitizer.validatePath(filePath);
    // Verify file exists by checking its type
    await Sgd.doCommand('file.type', filePath, connection);
    // Retrieve contents
    final command = '! U1 do "file.get" "$filePath"\r\n';
    final data = Uint8List.fromList(utf8.encode(command));
    final fileData = await connection.sendAndWaitForResponse(data);
    // Strip any SGD response wrapper (quotes)
    if (fileData.length >= 2 &&
        fileData.first == 0x22 &&
        fileData.last == 0x22) {
      return Uint8List.sublistView(fileData, 1, fileData.length - 1);
    }
    return fileData;
  }

  /// Delete a file from the printer.
  ///
  /// Sends `^XA^ID{filePath}^FS^XZ`.
  static Future<void> deleteFile(Connection connection, String filePath) async {
    ZplSanitizer.validatePath(filePath);
    final command = '^XA^ID$filePath^FS^XZ';
    await connection.write(Uint8List.fromList(utf8.encode(command)));
  }

  /// Get storage capacity info for a drive.
  ///
  /// Queries SGD `file.space{drive}` and parses free/total bytes.
  static Future<StorageInfo> getStorageInfo(
    Connection connection,
    String drive,
  ) async {
    ZplSanitizer.validateDrive(drive);
    final response = await Sgd.get('file.space$drive', connection);
    // Response format: "free,total" or similar
    final parts = response.split(',');
    final free = int.tryParse(parts[0].trim()) ?? 0;
    final total = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return StorageInfo(drive: drive, freeBytes: free, totalBytes: total);
  }

  /// Parse a file listing response into [PrinterObject] list.
  static List<PrinterObject> _parseFileList(String response) {
    final objects = <PrinterObject>[];
    // Strip control characters (STX, ETX, CR, LF around fields)
    final cleaned = response.replaceAll(RegExp(r'[\x00-\x1f]'), '\n');
    final lines = cleaned.split('\n').where((l) => l.trim().isNotEmpty);

    for (final line in lines) {
      // ^HW output:
      //   - DIR E:*.*                  header
      //   * E:FILENAME.ZPL    1234     one line per file
      //   -794624 bytes free E:ONBOARD FLASH
      var trimmed = line.trim();
      if (trimmed.startsWith('-')) continue; // header / free-space footer
      if (trimmed.startsWith('*')) trimmed = trimmed.substring(1).trimLeft();
      final match = RegExp(r'^(\S+)\s+(\d+)').firstMatch(trimmed);
      if (match != null) {
        objects.add(
          PrinterObject(
            name: match.group(1)!,
            sizeBytes: int.parse(match.group(2)!),
          ),
        );
      }
    }
    return objects;
  }
}
