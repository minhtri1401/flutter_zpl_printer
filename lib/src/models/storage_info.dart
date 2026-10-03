/// Storage capacity information for a printer drive.
///
/// Mirrors SDK's `StorageInfo.java`. Drives include `R:` (RAM),
/// `E:` (Flash), `B:` (SD Card), `Z:` (internal).
class StorageInfo {
  final String drive;
  final int freeBytes;
  final int totalBytes;

  const StorageInfo({
    required this.drive,
    required this.freeBytes,
    required this.totalBytes,
  });

  /// Percentage of storage used (0.0–1.0).
  double get usedPercent =>
      totalBytes > 0 ? (totalBytes - freeBytes) / totalBytes : 0;

  @override
  String toString() => 'StorageInfo($drive free=$freeBytes total=$totalBytes)';
}
