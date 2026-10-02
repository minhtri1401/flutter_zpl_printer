/// The printer's current print mode, as reported by the `~HS` host status
/// (field index 17).
///
/// Named `PrinterPrintMode` (it was `ZplPrintMode` before 0.2.0) so it
/// doesn't clash with `flutter_zpl_generator`'s `ZplPrintMode`, which is the
/// mode you *set* in a label's configuration.
enum PrinterPrintMode {
  rewind,
  peelOff,
  tearOff,
  cutter,
  applicator,
  delayedCut,
  linerlessPeel,
  linerlessRewind,
  partialCutter,
  rfid,
  kiosk,
  unknown;

  /// Parse from `~HS` response character. Matches SDK's `getPrintModeFromHs`.
  static PrinterPrintMode fromHsChar(String char) {
    switch (char.toUpperCase()) {
      case '0':
        return PrinterPrintMode.rewind;
      case '1':
        return PrinterPrintMode.peelOff;
      case '2':
        return PrinterPrintMode.tearOff;
      case '3':
        return PrinterPrintMode.cutter;
      case '4':
        return PrinterPrintMode.applicator;
      case '5':
        return PrinterPrintMode.delayedCut;
      case '6':
        return PrinterPrintMode.linerlessPeel;
      case '7':
        return PrinterPrintMode.linerlessRewind;
      case '8':
        return PrinterPrintMode.partialCutter;
      case '9':
        return PrinterPrintMode.rfid;
      case 'K':
        return PrinterPrintMode.kiosk;
      default:
        return PrinterPrintMode.unknown;
    }
  }
}
