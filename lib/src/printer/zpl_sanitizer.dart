/// ZPL command injection prevention.
///
/// User-supplied strings (file paths, drive names, addresses) must be
/// validated before interpolation into ZPL command strings.
class ZplSanitizer {
  ZplSanitizer._();

  /// Characters that can break out of a ZPL command context.
  static final _dangerousChars = RegExp(r'[\^~\x00-\x1f]');

  /// Validate a printer file path (e.g. `E:LABEL.ZPL`).
  ///
  /// Throws [ArgumentError] if the path contains ZPL control characters
  /// (`^`, `~`) that could inject commands.
  static String validatePath(String path) {
    if (_dangerousChars.hasMatch(path)) {
      throw ArgumentError.value(
        path,
        'path',
        'Contains invalid characters for ZPL path',
      );
    }
    return path;
  }

  /// Validate a drive name (e.g. `E:`, `R:`).
  static String validateDrive(String drive) {
    if (!RegExp(r'^[A-Za-z]:$').hasMatch(drive)) {
      throw ArgumentError.value(drive, 'drive', 'Invalid drive format');
    }
    return drive;
  }

  /// Validate a value before embedding in ZPL field data (`^FD`).
  ///
  /// Strips `^` and `~` to prevent command injection in field data.
  static String sanitizeFieldData(String value) {
    return value.replaceAll(RegExp(r'[\^~]'), '');
  }
}
