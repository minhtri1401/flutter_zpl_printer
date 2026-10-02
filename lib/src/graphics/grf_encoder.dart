import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// GRF (Graphic Retrieve Format) encoded bitmap data.
class GrfData {
  /// Hex-encoded monochrome bitmap.
  final String hexData;

  /// Raw monochrome bitmap bytes (before hex encoding).
  final Uint8List bitmapBytes;

  /// Total byte count of the bitmap.
  final int totalBytes;

  /// Bytes per row (ceil(width / 8)).
  final int bytesPerRow;

  final int width;
  final int height;

  const GrfData({
    required this.hexData,
    required this.bitmapBytes,
    required this.totalBytes,
    required this.bytesPerRow,
    required this.width,
    required this.height,
  });
}

/// Converts images (PNG/JPEG/BMP) to ZPL GRF hex format.
///
/// Mirrors SDK's `GraphicsConversionUtilZpl.getGrfData`.
class GrfEncoder {
  GrfEncoder._();

  /// Convert raw image bytes to GRF data.
  ///
  /// Decodes PNG/JPEG/BMP via the `image` package, converts to monochrome
  /// using luminance thresholding, and hex-encodes the result.
  ///
  /// [targetWidth] optionally resizes the image (preserving aspect ratio).
  /// [threshold] controls black/white cutoff (0–255, default 128).
  static GrfData encode(
    Uint8List imageBytes, {
    int? targetWidth,
    int threshold = 128,
  }) {
    var decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw ArgumentError('Unable to decode image');
    }

    // Resize if requested
    if (targetWidth != null && targetWidth != decoded.width) {
      decoded = img.copyResize(decoded, width: targetWidth);
    }

    final width = decoded.width;
    final height = decoded.height;
    final bytesPerRow = (width + 7) ~/ 8;
    final totalBytes = bytesPerRow * height;
    final bitmap = Uint8List(totalBytes);

    // Convert to monochrome: luminance < threshold -> black (bit = 1)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = decoded.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        // ITU-R BT.601 luminance
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
        if (luminance < threshold) {
          // Set bit (MSB first within each byte)
          final byteIndex = y * bytesPerRow + (x ~/ 8);
          final bitIndex = 7 - (x % 8);
          bitmap[byteIndex] |= (1 << bitIndex);
        }
      }
    }

    // Hex encode
    final hex = StringBuffer();
    for (final byte in bitmap) {
      hex.write(byte.toRadixString(16).padLeft(2, '0').toUpperCase());
    }

    return GrfData(
      hexData: hex.toString(),
      bitmapBytes: bitmap,
      totalBytes: totalBytes,
      bytesPerRow: bytesPerRow,
      width: width,
      height: height,
    );
  }
}
