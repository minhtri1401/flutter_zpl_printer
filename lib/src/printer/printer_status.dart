import 'dart:convert';
import 'dart:typed_data';

import '../connection/connection.dart';
import '../connection/response_validators.dart';
import '../exceptions/connection_exception.dart';
import '../models/printer_print_mode.dart';

/// Zebra printer status.
///
/// Parsed from `~HS` (Host Status) ZPL command response.
/// Field indices match SDK's `PrinterStatusZpl.java` exactly.
class PrinterStatus {
  final bool isReadyToPrint;
  final bool isPaperOut;
  final bool isPaused;
  final bool isHeadOpen;
  final bool isHeadTooHot;
  final bool isHeadCold;
  final bool isRibbonOut;
  final bool isReceiveBufferFull;
  final bool isPartialFormatInProgress;
  final int labelLengthInDots;
  final int numberOfFormatsInReceiveBuffer;
  final int labelsRemainingInBatch;
  final PrinterPrintMode printMode;

  const PrinterStatus({
    required this.isReadyToPrint,
    required this.isPaperOut,
    required this.isPaused,
    required this.isHeadOpen,
    required this.isHeadTooHot,
    required this.isHeadCold,
    required this.isRibbonOut,
    required this.isReceiveBufferFull,
    required this.isPartialFormatInProgress,
    required this.labelLengthInDots,
    required this.numberOfFormatsInReceiveBuffer,
    required this.labelsRemainingInBatch,
    required this.printMode,
  });

  /// Query printer status via `~HS` command.
  ///
  /// Parses the comma-separated response matching SDK's `PrinterStatusZpl`.
  static Future<PrinterStatus> query(Connection connection) async {
    // Send ~HS command (Host Status)
    final command = Uint8List.fromList(utf8.encode('~HS'));
    final response = await connection.sendAndWaitForValidResponse(
      command,
      validator: ResponseValidators.status(),
    );
    return _parseResponse(response);
  }

  /// Parse `~HS` response bytes into PrinterStatus.
  ///
  /// Response format: STX (0x02) prefix, ETX (0x03) line separators,
  /// comma-separated fields. Matches `PrinterStatusZpl.getPrinterStatus()`.
  static PrinterStatus _parseResponse(Uint8List responseBytes) {
    // Replace ETX (0x03) with comma, filter to printable ASCII
    final buffer = StringBuffer();
    for (final byte in responseBytes) {
      if (byte == 0x03) {
        buffer.write(',');
      } else if (byte > 31 && byte < 127) {
        buffer.write(String.fromCharCode(byte));
      }
    }

    final raw = buffer.toString();
    final fields = raw.split(',');

    if (fields.length < 25) {
      throw ConnectionException(
        'Malformed status response - unable to determine printer status',
      );
    }

    // Parse fields matching SDK's PrinterStatusZpl indices
    final isPaperOut = fields[1].trim() == '1';
    final isPaused = fields[2].trim() == '1';
    final labelLengthInDots = int.tryParse(fields[3].trim()) ?? 0;
    final numberOfFormatsInReceiveBuffer =
        int.tryParse(fields[4].trim()) ?? 0;
    final isReceiveBufferFull = fields[5].trim() == '1';
    final isPartialFormatInProgress = fields[7].trim() == '1';
    final isHeadCold = fields[10].trim() == '1';
    final isHeadTooHot = fields[11].trim() == '1';
    final isHeadOpen = fields[14].trim() == '1';
    final isRibbonOut = fields[15].trim() == '1';
    final printModeChar =
        fields[17].trim().isNotEmpty ? fields[17].trim() : '2';
    final labelsRemainingInBatch = int.tryParse(fields[20].trim()) ?? 0;

    final printMode = PrinterPrintMode.fromHsChar(printModeChar);

    // SDK: isReadyToPrint = NOT(paperOut OR paused OR bufferFull OR headTooHot OR headOpen OR ribbonOut)
    final isReadyToPrint = !isPaperOut &&
        !isPaused &&
        !isReceiveBufferFull &&
        !isHeadTooHot &&
        !isHeadOpen &&
        !isRibbonOut;

    return PrinterStatus(
      isReadyToPrint: isReadyToPrint,
      isPaperOut: isPaperOut,
      isPaused: isPaused,
      isHeadOpen: isHeadOpen,
      isHeadTooHot: isHeadTooHot,
      isHeadCold: isHeadCold,
      isRibbonOut: isRibbonOut,
      isReceiveBufferFull: isReceiveBufferFull,
      isPartialFormatInProgress: isPartialFormatInProgress,
      labelLengthInDots: labelLengthInDots,
      numberOfFormatsInReceiveBuffer: numberOfFormatsInReceiveBuffer,
      labelsRemainingInBatch: labelsRemainingInBatch,
      printMode: printMode,
    );
  }

  /// Human-readable status messages matching SDK's `PrinterStatusMessages`.
  ///
  /// Returns `['Ready To Print']` when ready, otherwise a list of active
  /// conditions (e.g. `['HEAD OPEN', 'PAPER OUT']`).
  /// Returns `['INVALID STATUS']` if no conditions are active but not ready.
  List<String> get statusMessages {
    if (isReadyToPrint) return ['Ready To Print'];
    final messages = <String>[];
    if (isHeadOpen) messages.add('HEAD OPEN');
    if (isHeadTooHot) messages.add('HEAD TOO HOT');
    if (isPaperOut) messages.add('PAPER OUT');
    if (isRibbonOut) messages.add('RIBBON OUT');
    if (isReceiveBufferFull) messages.add('RECEIVE BUFFER FULL');
    if (isPaused) messages.add('PAUSE');
    return messages.isEmpty ? ['INVALID STATUS'] : messages;
  }

  @override
  String toString() =>
      'PrinterStatus(ready=$isReadyToPrint, paper=${!isPaperOut}, '
      'head=${!isHeadOpen && !isHeadTooHot}, ribbon=${!isRibbonOut}, '
      'mode=$printMode)';
}
