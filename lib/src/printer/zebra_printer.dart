import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_zpl_generator/flutter_zpl_generator.dart';

import '../connection/connection.dart';
import '../graphics/graphics_util.dart';
import '../models/printer_metadata_key.dart';
import '../models/printer_object.dart';
import '../models/storage_info.dart';
import 'file_util.dart';
import 'format_util.dart';
import 'printer_language.dart';
import 'printer_status.dart';
import 'sgd.dart';

/// High-level API for interacting with a Zebra printer.
///
/// Operates on abstract [Connection] -- transport-agnostic.
/// Mirrors SDK's `ZebraPrinter` + `ZebraPrinterFactory`.
class ZebraPrinter {
  Connection connection;
  PrinterLanguage? _language;

  ZebraPrinter(this.connection);

  /// Connect to a printer and detect its language.
  ///
  /// Opens the connection, queries printer language, returns ready instance.
  static Future<ZebraPrinter> connect(Connection connection) async {
    await connection.open();
    final printer = ZebraPrinter(connection);
    try {
      await printer.getLanguage();
    } catch (_) {
      // Language detection failure is non-fatal; default to ZPL
      printer._language = PrinterLanguage.zpl;
    }
    return printer;
  }

  /// Get the printer's current status.
  Future<PrinterStatus> getStatus() => PrinterStatus.query(connection);

  /// Get (or detect) the printer control language.
  Future<PrinterLanguage> getLanguage() async {
    if (_language != null) return _language!;
    final value = await Sgd.get('device.languages', connection);
    _language = PrinterLanguage.fromString(value);
    return _language!;
  }

  /// Send raw ZPL string to the printer.
  Future<void> printZpl(String zpl) async {
    final data = Uint8List.fromList(utf8.encode(zpl));
    await connection.write(data);
  }

  /// Build [label] with `flutter_zpl_generator` and send it.
  ///
  /// Equivalent to `printZpl(await label.build())`.
  Future<void> printLabel(ZplGenerator label) async =>
      printZpl(await label.build());

  /// Send a raw command string to the printer (alias for [printZpl]).
  Future<void> sendCommand(String command) => printZpl(command);

  /// Get a printer setting via SGD.
  Future<String> getSetting(String name) => Sgd.get(name, connection);

  /// Set a printer setting via SGD.
  Future<void> setSetting(String name, String value) =>
      Sgd.set(name, value, connection);

  /// Execute a DO command via SGD.
  Future<String> doCommand(String name, String value) =>
      Sgd.doCommand(name, value, connection);

  // -- ToolsUtil methods (SDK: ToolsUtil.java, ToolsUtilLinkOs.java) --

  /// Run media calibration. Sends `~JC`.
  Future<void> calibrate() => printZpl('~JC');

  /// Restore factory defaults. Sends `^JUF`.
  Future<void> restoreDefaults() => printZpl('^JUF');

  /// Print a configuration label. Sends `~WC`.
  Future<void> printConfigurationLabel() => printZpl('~WC');

  /// Reset the printer via SGD `device.reset`.
  Future<void> reset() => doCommand('device.reset', '');

  /// Print a directory listing label. Sends `^WD`.
  Future<void> printDirectoryLabel() => printZpl('^WD');

  /// Reset network settings via SGD.
  Future<void> resetNetwork() =>
      Sgd.set('device.reset_network', '', connection);

  /// Print a network configuration label via SGD.
  Future<void> printNetworkConfigLabel() =>
      Sgd.doCommand('device.printnetworkconfiglabel', '', connection);

  /// Restore network defaults via SGD.
  Future<void> restoreNetworkDefaults() =>
      Sgd.set('internal_wired.restore_defaults', '', connection);

  /// Set the printer's real-time clock.
  Future<void> setClock(DateTime dateTime) async {
    final date =
        '${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.year}';
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
    await Sgd.set('rtc.date', date, connection);
    await Sgd.set('rtc.time', time, connection);
  }

  // -- File operations (SDK: FileUtil.java, FileUtilLinkOs.java) --

  /// List files on a printer drive.
  Future<List<PrinterObject>> listFiles({String drive = 'E:'}) =>
      FileUtil.listFiles(connection, drive: drive);

  /// Retrieve all file names across R: and E: drives.
  Future<List<String>> retrieveFileNames() =>
      FileUtil.retrieveFileNames(connection);

  /// Retrieve file names filtered by extension(s).
  Future<List<String>> retrieveFileNamesByExtension(List<String> extensions) =>
      FileUtil.retrieveFileNamesByExtension(connection, extensions);

  /// Store a file on the printer filesystem.
  Future<void> storeFile(String path, Uint8List data) =>
      FileUtil.storeFile(connection, path, data);

  /// Delete a file from the printer.
  Future<void> deleteFile(String path) => FileUtil.deleteFile(connection, path);

  /// Retrieve a file from the printer.
  Future<Uint8List> getFile(String path) => FileUtil.getFile(connection, path);

  /// Get storage capacity info for a drive.
  Future<StorageInfo> getStorageInfo(String drive) =>
      FileUtil.getStorageInfo(connection, drive);

  // -- Graphics operations (SDK: GraphicsUtil.java) --

  /// Print an image (PNG, JPEG, ...) at position ([x], [y]).
  ///
  /// Built with `flutter_zpl_generator`: the graphic is downloaded to printer
  /// memory with `~DG` (uncompressed hex) before `^XA`, then placed with
  /// `^XG`. This is the image path tested on hardware, and the one Link-OS
  /// mobile printers need.
  ///
  /// [targetWidth] resizes the image (dots). [dithering] defaults to
  /// threshold: Floyd-Steinberg's dense dot coverage can trip print-head
  /// thermal protection on some mobile printers. [graphicName] is the name
  /// the graphic is stored under in printer memory.
  ///
  /// For full control (label width, print mode, more fields), build a
  /// [ZplGenerator] yourself and call [printLabel].
  Future<void> printImage(
    Uint8List imageBytes, {
    int x = 0,
    int y = 0,
    int? targetWidth,
    ZplDitheringAlgorithm dithering = ZplDitheringAlgorithm.threshold,
    String graphicName = 'IMG',
  }) =>
      printLabel(ZplGenerator(commands: [
        ZplImageDownload(
          image: imageBytes,
          graphicName: graphicName,
          targetWidth: targetWidth,
          ditheringAlgorithm: dithering,
        ),
        ZplImageRecall(x: x, y: y, graphicName: graphicName),
      ]));

  /// Store an image on the printer as a GRF file.
  Future<void> storeImage(String path, Uint8List imageBytes) =>
      GraphicsUtil.storeImage(connection, path, imageBytes);

  // -- Format operations (SDK: FormatUtil.java) --

  /// Print a stored format with variable data.
  Future<void> printStoredFormat(
    String formatPath,
    Map<int, String> variables,
  ) => FormatUtil.printStoredFormat(connection, formatPath, variables);

  /// Retrieve a stored format's ZPL content.
  Future<String> retrieveFormat(String formatPath) =>
      FormatUtil.retrieveFormat(connection, formatPath);

  // -- Metadata --

  /// Query common printer metadata via SGD.
  ///
  /// Returns a map with keys like `device.friendly_name`, `appl.name`,
  /// `device.product_name`, `device.unique_id`.
  Future<Map<PrinterMetadataKey, String>> getMetadata({
    List<PrinterMetadataKey>? keys,
  }) async {
    final keysToFetch = keys ?? PrinterMetadataKey.values;
    final result = <PrinterMetadataKey, String>{};
    for (final key in keysToFetch) {
      try {
        result[key] = await getSetting(key.value);
      } catch (_) {
        // Skip settings that are unavailable on this printer
      }
    }
    return result;
  }

  /// Disconnect from the printer.
  Future<void> disconnect() => connection.close();
}
