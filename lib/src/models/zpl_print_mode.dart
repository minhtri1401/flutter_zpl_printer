/// ZPL print mode enum matching SDK's `ZplPrintMode`.
///
/// Parsed from `~HS` status response field index 17.
enum ZplPrintMode {
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
  static ZplPrintMode fromHsChar(String char) {
    switch (char.toUpperCase()) {
      case '0':
        return ZplPrintMode.rewind;
      case '1':
        return ZplPrintMode.peelOff;
      case '2':
        return ZplPrintMode.tearOff;
      case '3':
        return ZplPrintMode.cutter;
      case '4':
        return ZplPrintMode.applicator;
      case '5':
        return ZplPrintMode.delayedCut;
      case '6':
        return ZplPrintMode.linerlessPeel;
      case '7':
        return ZplPrintMode.linerlessRewind;
      case '8':
        return ZplPrintMode.partialCutter;
      case '9':
        return ZplPrintMode.rfid;
      case 'K':
        return ZplPrintMode.kiosk;
      default:
        return ZplPrintMode.unknown;
    }
  }
}
