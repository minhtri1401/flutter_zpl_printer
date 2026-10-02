/// Printer control language. Matches SDK's `PrinterLanguage`.
enum PrinterLanguage {
  zpl,
  cpcl,
  linePrint;

  /// Parse from SGD response string.
  static PrinterLanguage fromString(String value) {
    final lower = value.toLowerCase().trim();
    if (lower.contains('zpl')) return PrinterLanguage.zpl;
    if (lower.contains('cpcl')) return PrinterLanguage.cpcl;
    if (lower.contains('line_print')) return PrinterLanguage.linePrint;
    return PrinterLanguage.zpl; // default
  }
}
