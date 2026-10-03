import 'dart:typed_data';

import 'connection.dart';

/// Factory methods for common response validators.
///
/// Each method returns a [ResponseValidator] that detects when a
/// response is complete based on its format (SGD, JSON, status, etc.).
abstract class ResponseValidators {
  ResponseValidators._();

  /// SGD: complete when first and last byte are `"` (0x22).
  static ResponseValidator sgd() => (Uint8List data) {
    return data.length >= 2 && data.first == 0x22 && data.last == 0x22;
  };

  /// JSON: complete when brace depth returns to 0 after opening `{`.
  static ResponseValidator json() => (Uint8List data) {
    if (data.isEmpty) return false;
    int depth = 0;
    bool started = false;
    for (final byte in data) {
      if (byte == 0x7B) {
        depth++;
        started = true;
      }
      if (byte == 0x7D) depth--;
    }
    return started && depth == 0;
  };

  /// Status (`~HS`): complete when 3 ETX (0x03) bytes received.
  static ResponseValidator status() => (Uint8List data) {
    int etxCount = 0;
    for (final byte in data) {
      if (byte == 0x03) etxCount++;
    }
    return etxCount >= 3;
  };

  /// Multiline: complete when [expectedLines] newlines received.
  static ResponseValidator multiline(int expectedLines) => (Uint8List data) {
    int count = 0;
    for (final byte in data) {
      if (byte == 0x0A) count++;
    }
    return count >= expectedLines;
  };

  /// Generic: complete when data ends with [marker] byte sequence.
  static ResponseValidator endsWith(List<int> marker) => (Uint8List data) {
    if (data.length < marker.length) return false;
    for (int i = 0; i < marker.length; i++) {
      if (data[data.length - marker.length + i] != marker[i]) return false;
    }
    return true;
  };
}
