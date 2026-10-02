import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import '../printer/zpl_sanitizer.dart';
import 'grf_encoder.dart';
import 'z64_compressor.dart';

/// High-level graphics printing and storage operations.
///
/// Mirrors SDK's `GraphicsUtil.java`.
class GraphicsUtil {
  GraphicsUtil._();

  /// Print an image inline at position ([x], [y]).
  ///
  /// Converts to GRF and sends a `^GFA` command with the bitmap as ASCII hex,
  /// which every Zebra printer accepts.
  ///
  /// Set [useCompression] to send Z64 instead (smaller, faster over
  /// Bluetooth). Z64 follows Zebra's specification but has not been verified
  /// on a printer yet, so it is off by default.
  ///
  /// For production image printing, `flutter_zpl_generator` is the path
  /// tested on hardware: build the label with it and send it with
  /// `printZpl`.
  static Future<void> printImage(
    Connection connection,
    Uint8List imageBytes, {
    int x = 0,
    int y = 0,
    int? targetWidth,
    int threshold = 128,
    bool useCompression = false,
  }) async {
    final grf = GrfEncoder.encode(
      imageBytes,
      targetWidth: targetWidth,
      threshold: threshold,
    );

    String data;
    if (useCompression) {
      data = Z64Compressor.compress(grf.bitmapBytes);
    } else {
      data = grf.hexData;
    }

    final zpl = '^XA'
        '^FO$x,$y'
        '^GFA,${grf.totalBytes},${grf.totalBytes},${grf.bytesPerRow},$data'
        '^FS'
        '^XZ';
    await connection.write(Uint8List.fromList(utf8.encode(zpl)));
  }

  /// Store an image on the printer as a GRF file using `~DG`.
  static Future<void> storeImage(
    Connection connection,
    String targetPath,
    Uint8List imageBytes, {
    int? targetWidth,
    int threshold = 128,
  }) async {
    final grf = GrfEncoder.encode(
      imageBytes,
      targetWidth: targetWidth,
      threshold: threshold,
    );
    ZplSanitizer.validatePath(targetPath);
    final zpl =
        '~DG$targetPath,${grf.totalBytes},${grf.bytesPerRow},${grf.hexData}';
    await connection.write(Uint8List.fromList(utf8.encode(zpl)));
  }

  /// Print a previously stored graphic at position ([x], [y]).
  ///
  /// Uses `^XG` to recall the stored image.
  static Future<void> printStoredImage(
    Connection connection,
    String imagePath, {
    int x = 0,
    int y = 0,
    int scaleX = 1,
    int scaleY = 1,
  }) async {
    ZplSanitizer.validatePath(imagePath);
    final zpl = '^XA^FO$x,$y^XG$imagePath,$scaleX,$scaleY^FS^XZ';
    await connection.write(Uint8List.fromList(utf8.encode(zpl)));
  }
}
