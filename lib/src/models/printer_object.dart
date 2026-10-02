/// Metadata for a file stored on the printer.
///
/// Returned by `FileUtil.listFiles`.
class PrinterObject {
  final String name;
  final int sizeBytes;

  const PrinterObject({required this.name, required this.sizeBytes});

  /// Drive letter prefix (e.g. `E:` or `R:`), or `null` if not present.
  String? get drive {
    final idx = name.indexOf(':');
    return idx >= 0 ? name.substring(0, idx + 1) : null;
  }

  /// File extension (without dot), or `null` if no extension.
  String? get extension {
    final dot = name.lastIndexOf('.');
    return dot >= 0 ? name.substring(dot + 1) : null;
  }

  /// File name without the drive prefix (e.g. `MYFORMAT.ZPL`).
  String get fileName {
    final colonIdx = name.indexOf(':');
    return colonIdx >= 0 ? name.substring(colonIdx + 1) : name;
  }

  @override
  String toString() => 'PrinterObject($name, $sizeBytes bytes)';
}
