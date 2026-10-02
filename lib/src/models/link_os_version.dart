/// Link-OS firmware version parsed from SGD `appl.link_os_version`.
///
/// Mirrors SDK's `LinkOsInformation.java`. Used for feature gating
/// (e.g. `FileUtilLinkOs` requires Link-OS 2.0+).
class LinkOsVersion {
  final int major;
  final int minor;
  final int micro;

  const LinkOsVersion({
    required this.major,
    required this.minor,
    this.micro = 0,
  });

  /// Whether this is a valid Link-OS version.
  bool get isLinkOs => major >= 0;

  /// Check if this version meets a minimum requirement.
  bool supports(int minMajor, int minMinor) =>
      major > minMajor || (major == minMajor && minor >= minMinor);

  /// Parse a version string like `"V3.1.0"` or `"3.1.0"`.
  ///
  /// Returns `null` if the string cannot be parsed.
  static LinkOsVersion? parse(String versionString) {
    final cleaned = versionString.trim().replaceFirst(RegExp(r'^[Vv]'), '');
    final parts = cleaned.split('.');
    if (parts.isEmpty) return null;

    final major = int.tryParse(parts[0]);
    if (major == null) return null;

    final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final micro = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;

    return LinkOsVersion(major: major, minor: minor, micro: micro);
  }

  @override
  String toString() => 'LinkOsVersion($major.$minor.$micro)';
}
