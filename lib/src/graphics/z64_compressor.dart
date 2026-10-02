import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Z64 compression for ZPL graphics (deflate + base64 + CRC16).
///
/// Reduces GRF transfer size by 60–80%.
class Z64Compressor {
  Z64Compressor._();

  /// Compress bitmap data using Z64 encoding.
  ///
  /// Returns `:Z64:{base64}:{crc16hex}` string.
  static String compress(Uint8List bitmapData) {
    // Deflate
    final deflated = zlib.encode(bitmapData);
    // Base64
    final b64 = base64Encode(deflated);
    // CRC16 of the original bitmap data
    final crc = crc16(bitmapData);
    final crcHex = crc.toRadixString(16).padLeft(4, '0').toUpperCase();
    return ':Z64:$b64:$crcHex';
  }

  /// CRC-16/CCITT-FALSE used by ZPL Z64 validation.
  static int crc16(Uint8List data) {
    int crc = 0xFFFF;
    for (final byte in data) {
      crc ^= (byte << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc;
  }
}
