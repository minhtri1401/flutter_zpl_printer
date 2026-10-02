/// Parse a Zebra printer's serial + model out of the advanced-discovery
/// ASCII blob returned via UDP port 4201.
///
/// Zebra advertises different name shapes on different transports:
///   - BLE: clean serial, e.g. `WMZKN210306204`
///   - UDP advanced-discovery: raw concatenated packet, e.g.
///     `:,.ZBRWMZKN210306204ZTC ZQ620-203dpi CPCLV85.20.24`
///
/// This file exposes three pure functions. They mirror Zebra's own
/// Setup Utility (`PrinterRepository._getRegexForName`
/// uses the regex `(?<=ZTC\s?).*(?=\s)`).
///
/// The sentinel **`ZTC`** (Zebra Technologies Corp) always precedes the
/// model token in the advanced-discovery packet — true across every
/// Zebra printer family (ZQ, ZD, ZT, ZR, GK, GX, …).
library;

/// 2–5 uppercase letters followed by 9+ digits. Matches the Zebra serial
/// shape in both clean BLE names and UDP advanced-discovery blobs.
///
/// `[A-Z]{2,5}\d{9,}` is specific enough that names like
/// `iPhone15A123456789` don't collide (single uppercase letter at the
/// boundary fails the `{2,5}` minimum).
final _serialPattern = RegExp(r'[A-Z]{2,5}\d{9,}');

/// Captures everything after `ZTC` (with optional whitespace) up to the
/// next whitespace: model + DPI suffix.
final _modelWithDpiPattern = RegExp(r'ZTC\s?(\S+?)(?:\s|$)');

/// Bare model without DPI suffix (e.g. `ZQ620` instead of
/// `ZQ620-203dpi`).
final _bareModelPattern = RegExp(r'ZTC\s?([A-Z]{1,3}\d+[A-Za-z]*)');

/// Extract a Zebra printer serial from [raw]. Returns `null` if no
/// serial-shaped token is found.
String? extractZebraSerial(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return _serialPattern.firstMatch(raw)?.group(0);
}

/// Extract the Zebra model with DPI suffix (e.g. `ZQ620-203dpi`,
/// `ZD421-300dpi`, `GK420d`). Returns `null` if the `ZTC` sentinel is
/// absent (e.g. a clean BLE name like `WMZKN210306204`).
String? extractZebraModel(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final captured = _modelWithDpiPattern.firstMatch(raw)?.group(1);
  if (captured == null || captured.isEmpty) return null;
  return captured;
}

/// Bare model without DPI (`ZQ620` from `ZQ620-203dpi`).
String? extractBareZebraModel(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  return _bareModelPattern.firstMatch(raw)?.group(1);
}

/// Display-quality printer name derived from [raw].
///
/// Prefers `MODEL (SERIAL)` when both can be extracted. Falls back to
/// whichever is available, then to the cleaned raw. Returns
/// `'Zebra Printer'` when nothing usable is present.
String friendlyZebraName(String? raw) {
  if (raw == null || raw.isEmpty) return 'Zebra Printer';
  final model = extractZebraModel(raw);
  final serial = extractZebraSerial(raw);
  if (model != null && serial != null) return '$model ($serial)';
  if (model != null) return model;
  if (serial != null) return serial;
  final cleaned = raw.replaceFirst(RegExp(r'^[^A-Za-z0-9]+'), '').trim();
  return cleaned.isEmpty ? 'Zebra Printer' : cleaned;
}
