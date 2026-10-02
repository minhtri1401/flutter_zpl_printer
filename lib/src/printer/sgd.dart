import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import '../connection/response_validators.dart';

/// SGD (Set-Get-Do) protocol implementation.
///
/// Text-based command protocol over a Connection.
/// Mirrors SDK's `com.zebra.sdk.printer.SGD`.
class Sgd {
  Sgd._();

  /// GET a printer setting value.
  ///
  /// Sends `! U1 getvar "$setting"\r\n` and returns the unquoted response.
  static Future<String> get(String setting, Connection connection) async {
    final command = '! U1 getvar "$setting"\r\n';
    final data = Uint8List.fromList(utf8.encode(command));

    final response = await connection.sendAndWaitForValidResponse(
      data,
      validator: ResponseValidators.sgd(),
    );

    return _stripQuotes(utf8.decode(response));
  }

  /// SET a printer setting value (fire-and-forget).
  ///
  /// Sends `! U1 setvar "$setting" "$value"\r\n`.
  static Future<void> set(
    String setting,
    String value,
    Connection connection,
  ) async {
    final command = '! U1 setvar "$setting" "$value"\r\n';
    final data = Uint8List.fromList(utf8.encode(command));
    await connection.write(data);
  }

  /// Execute a DO command.
  ///
  /// Sends `! U1 do "$setting" "$value"\r\n` and returns the unquoted response.
  static Future<String> doCommand(
    String setting,
    String value,
    Connection connection,
  ) async {
    final command = '! U1 do "$setting" "$value"\r\n';
    final data = Uint8List.fromList(utf8.encode(command));

    final response = await connection.sendAndWaitForValidResponse(
      data,
      validator: ResponseValidators.sgd(),
    );

    return _stripQuotes(utf8.decode(response));
  }

  /// Remove surrounding quotes from an SGD response and collapse
  /// duplicate-reply artefacts.
  ///
  /// On some BLE transports (macOS CoreBluetooth in particular) the
  /// notification characteristic delivers a single `getvar` reply as
  /// several concatenated `"value"` copies — e.g. six stacked
  /// `"ZQ620"` frames arriving for one read. After stripping the
  /// outer quote pair, the result looks like `ZQ620""ZQ620""ZQ620…`.
  /// Splitting on the internal `""` seam and taking the first token
  /// recovers the single intended value in both the clean case
  /// (no duplicates) and the duplicated case.
  static String _stripQuotes(String value) {
    var result = value.trim();
    if (result.startsWith('"') && result.endsWith('"') && result.length >= 2) {
      result = result.substring(1, result.length - 1);
    }
    final seam = result.indexOf('""');
    if (seam >= 0) {
      result = result.substring(0, seam);
    }
    return result;
  }
}
