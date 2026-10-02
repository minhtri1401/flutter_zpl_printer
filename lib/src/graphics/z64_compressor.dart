import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Z64 compression for ZPL graphics (deflate + base64 + CRC16).
///
/// Per Zebra's ZPL II Programming Guide (B64 and Z64 Encoding), the CRC is
/// four hex digits "calculated over the :encoded_data field", i.e. the
/// Base64 text, and a mismatch is treated as an aborted download.
///
/// Reduces GRF transfer size by 60–80%.
class Z64Compressor {
  Z64Compressor._();

  /// Compress bitmap data using Z64 encoding.
  ///
  /// Returns `:Z64:{base64}:{crc16hex}` string.
  ///
  /// Not yet verified on a printer; `GraphicsUtil.printImage` leaves it off
  /// by default.
  static String compress(Uint8List bitmapData) {
    // Deflate
    final deflated = zlib.encode(bitmapData);
    // Base64
    final b64 = base64Encode(deflated);
    // CRC16 of the Base64 text (not the raw bitmap).
    final crc = crc16(ascii.encode(b64));
    final crcHex = crc.toRadixString(16).padLeft(4, '0').toUpperCase();
    return ':Z64:$b64:$crcHex';
  }

  /// CRC-16/XMODEM: polynomial 0x1021, initial value 0x0000, no
  /// reflection, no final XOR. Check value: `'123456789'` → `0x31C3`.
  ///
  /// Same variant as `flutter_zpl_generator` and the `zpl-image` reference
  /// implementation.
  static int crc16(List<int> data) {
    int crc = 0x0000;
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
