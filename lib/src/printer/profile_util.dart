import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../connection/connection.dart';
import '../models/printer_alert.dart';
import '../models/printer_profile.dart';
import 'alert_util.dart';
import 'file_util.dart';
import 'profile_constants.dart';
import 'sgd.dart';
import 'zpl_sanitizer.dart';

/// Options for deleting printer files before loading a profile.
enum FileDeletionOption { all, cloneable, none }

/// Printer profile create/load operations.
///
/// Profiles are ZIP archives containing settings.json, alerts.json,
/// and cloneable printer files. Mirrors SDK's ProfileUtil.java.
class ProfileUtil {
  ProfileUtil._();

  /// Snapshot printer configuration to ZIP bytes.
  ///
  /// Captures SGD settings, alerts, and cloneable files from E: and R: drives.
  static Future<Uint8List> createProfile(
    Connection connection, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Fetching settings...');
    final settings = <String, String>{};
    for (final key in ProfileConstants.cloneableSettings) {
      try {
        settings[key] = await Sgd.get(key, connection);
      } catch (_) {}
    }

    onProgress?.call('Fetching alerts...');
    final alerts = await AlertUtil.getConfiguredAlerts(connection);

    onProgress?.call('Downloading files...');
    final files = <String, Uint8List>{};
    for (final drive in ['E:', 'R:']) {
      try {
        final objects = await FileUtil.listFiles(connection, drive: drive);
        for (final obj in objects) {
          if (!_isCloneable(obj.name)) continue;
          try {
            files[obj.name] = await FileUtil.getFile(connection, obj.name);
            onProgress?.call('Downloaded ${obj.name}');
          } catch (_) {}
        }
      } catch (_) {}
    }

    onProgress?.call('Creating ZIP...');
    return _buildZip(settings, alerts, files);
  }

  /// Alias for [createProfile] — SDK parity with createBackup.
  static Future<Uint8List> createBackup(
    Connection connection, {
    void Function(String status)? onProgress,
  }) => createProfile(connection, onProgress: onProgress);

  /// Restore printer configuration from ZIP profile bytes.
  ///
  /// Applies settings, uploads files, and configures alerts.
  static Future<void> loadProfile(
    Connection connection,
    Uint8List profileBytes, {
    FileDeletionOption deletionOption = FileDeletionOption.none,
    void Function(String status)? onProgress,
  }) async {
    final profile = _parseZip(profileBytes);

    if (deletionOption != FileDeletionOption.none) {
      onProgress?.call('Deleting existing files...');
      await _deleteFiles(connection, deletionOption);
    }

    onProgress?.call('Applying settings...');
    for (final entry in profile.settings.entries) {
      try {
        await Sgd.set(entry.key, entry.value, connection);
      } catch (_) {}
    }

    for (final entry in profile.files.entries) {
      onProgress?.call('Uploading ${entry.key}...');
      try {
        await FileUtil.storeFile(connection, entry.key, entry.value);
      } catch (_) {}
    }

    if (profile.alerts.isNotEmpty) {
      onProgress?.call('Configuring alerts...');
      await AlertUtil.configureAlerts(connection, profile.alerts);
    }
  }

  /// Alias for [loadProfile] — SDK parity with loadBackup.
  static Future<void> loadBackup(
    Connection connection,
    Uint8List profileBytes, {
    FileDeletionOption deletionOption = FileDeletionOption.none,
    void Function(String status)? onProgress,
  }) => loadProfile(
    connection,
    profileBytes,
    deletionOption: deletionOption,
    onProgress: onProgress,
  );

  static bool _isCloneable(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return false;
    return ProfileConstants.cloneableExtensions.contains(
      name.substring(dot + 1).toUpperCase(),
    );
  }

  static Uint8List _buildZip(
    Map<String, String> settings,
    List<PrinterAlert> alerts,
    Map<String, Uint8List> files,
  ) {
    final archive = Archive();

    archive.addFile(
      ArchiveFile.bytes('settings.json', utf8.encode(jsonEncode(settings))),
    );

    final alertsJson = alerts.map((a) => a.toSgdConfig()).toList();
    archive.addFile(
      ArchiveFile.bytes('alerts.json', utf8.encode(jsonEncode(alertsJson))),
    );

    for (final entry in files.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static PrinterProfile _parseZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, String> settings = {};
    List<PrinterAlert> alerts = [];
    final files = <String, Uint8List>{};

    for (final file in archive) {
      if (!file.isFile) continue;
      final content = file.content;

      if (file.name == 'settings.json') {
        final decoded =
            jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
        settings = decoded.map((k, v) => MapEntry(k, v.toString()));
      } else if (file.name == 'alerts.json') {
        // alerts.json is a JSON array of SGD config strings.
        // Re-parse via AlertUtil's existing SGD string parser by joining
        // into a semicolon-separated response and decoding it.
        try {
          final list = jsonDecode(utf8.decode(content)) as List<dynamic>;
          final joined = list.join(';');
          alerts = _parseAlertConfigs(joined);
        } catch (_) {}
      } else {
        files[file.name] = content;
      }
    }

    return PrinterProfile(settings: settings, alerts: alerts, files: files);
  }

  /// Parse semicolon-separated SGD alert config strings into PrinterAlert list.
  static List<PrinterAlert> _parseAlertConfigs(String joined) {
    final alerts = <PrinterAlert>[];
    final entries = joined.split(';');
    for (final entry in entries) {
      final parts = entry.split(',');
      if (parts.length < 6) continue;
      final condition = AlertCondition.fromSgd(parts[0]);
      if (condition == null) continue;
      final dest = AlertDestination.values.where(
        (d) => d.sgdValue == parts[1].trim().toUpperCase(),
      );
      if (dest.isEmpty) continue;
      alerts.add(
        PrinterAlert(
          condition: condition,
          destination: dest.first,
          onSet: parts[2].trim().toUpperCase() == 'YES',
          onClear: parts[3].trim().toUpperCase() == 'YES',
          destinationAddress: parts[4].trim(),
          port: int.tryParse(parts[5].trim()) ?? 0,
        ),
      );
    }
    return alerts;
  }

  static Future<void> _deleteFiles(
    Connection connection,
    FileDeletionOption option,
  ) async {
    for (final drive in ['E:', 'R:']) {
      try {
        final objects = await FileUtil.listFiles(connection, drive: drive);
        for (final obj in objects) {
          if (option == FileDeletionOption.cloneable &&
              !_isCloneable(obj.name)) {
            continue;
          }
          try {
            ZplSanitizer.validatePath(obj.name);
            await FileUtil.deleteFile(connection, obj.name);
          } catch (_) {}
        }
      } catch (_) {}
    }
  }
}
