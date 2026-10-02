import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

import '../mocks/mock_connection.dart';

/// Build a canned ~HS response matching real Zebra printer output.
///
/// Real format: 3 lines, each prefixed by STX (0x02) and terminated by ETX (0x03).
/// After parsing: STX filtered, ETX→comma, producing one long comma-separated string.
///
/// Field indices (0-based) from SDK's PrinterStatusZpl.java:
///   [1]=paperOut [2]=paused [3]=labelLength [4]=formatsInBuffer
///   [5]=bufferFull [7]=partialFormat [10]=headCold [11]=headTooHot
///   [14]=headOpen [15]=ribbonOut [17]=printMode [20]=labelsRemaining
Uint8List buildHsResponse({
  String paperOut = '0',
  String paused = '0',
  String labelLength = '831',
  String formatsInBuffer = '0',
  String bufferFull = '0',
  String partialFormat = '0',
  String headCold = '0',
  String headTooHot = '0',
  String headOpen = '0',
  String ribbonOut = '0',
  String printMode = '2', // tearOff
  String labelsRemaining = '0',
}) {
  // Line 1: produces fields[0..11] after STX filter + ETX→comma
  // fields: [0]=030, [1]=paperOut, [2]=paused, [3]=labelLength,
  //   [4]=formatsInBuffer, [5]=bufferFull, [6]=0, [7]=partialFormat,
  //   [8]=000, [9]=0, [10]=headCold, [11]=headTooHot
  final line1 =
      '\x02030,$paperOut,$paused,$labelLength,$formatsInBuffer,$bufferFull,0,$partialFormat,000,0,$headCold,$headTooHot\x03';

  // Line 2: produces fields[12..22]
  // fields: [12]=0, [13]=0, [14]=headOpen, [15]=ribbonOut, [16]=0,
  //   [17]=printMode, [18]=6, [19]=0, [20]=labelsRemaining, [21]=1, [22]=000
  final line2 =
      '\x020,0,$headOpen,$ribbonOut,0,$printMode,6,0,$labelsRemaining,1,000\x03';

  // Line 3: produces fields[23..24] (padding to reach 25+)
  final line3 = '\x02030,0\x03';

  return Uint8List.fromList('$line1$line2$line3'.codeUnits);
}

void main() {
  group('PrinterStatus', () {
    late MockConnection conn;

    setUp(() {
      conn = MockConnection(
        config: const ConnectionConfig(
          maxTimeoutForRead: 200,
          timeToWaitForMoreData: 50,
          interChunkDelayMs: 0,
        ),
      );
      conn.open();
    });

    test('parses all-clear status correctly', () async {
      conn.queueResponse(buildHsResponse());

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, true);
      expect(status.isPaperOut, false);
      expect(status.isPaused, false);
      expect(status.isHeadOpen, false);
      expect(status.isHeadTooHot, false);
      expect(status.isHeadCold, false);
      expect(status.isRibbonOut, false);
      expect(status.isReceiveBufferFull, false);
      expect(status.isPartialFormatInProgress, false);
      expect(status.labelLengthInDots, 831);
      expect(status.numberOfFormatsInReceiveBuffer, 0);
      expect(status.labelsRemainingInBatch, 0);
      expect(status.printMode, ZplPrintMode.tearOff);
    });

    test('isReadyToPrint false when paperOut', () async {
      conn.queueResponse(buildHsResponse(paperOut: '1'));

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, false);
      expect(status.isPaperOut, true);
    });

    test('isReadyToPrint false when headOpen', () async {
      conn.queueResponse(buildHsResponse(headOpen: '1'));

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, false);
      expect(status.isHeadOpen, true);
    });

    test('isReadyToPrint false when headTooHot', () async {
      conn.queueResponse(buildHsResponse(headTooHot: '1'));

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, false);
      expect(status.isHeadTooHot, true);
    });

    test('isReadyToPrint false when ribbonOut', () async {
      conn.queueResponse(buildHsResponse(ribbonOut: '1'));

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, false);
      expect(status.isRibbonOut, true);
    });

    test('isReadyToPrint false when paused', () async {
      conn.queueResponse(buildHsResponse(paused: '1'));

      final status = await PrinterStatus.query(conn);

      expect(status.isReadyToPrint, false);
      expect(status.isPaused, true);
    });

    test('detects headCold', () async {
      conn.queueResponse(buildHsResponse(headCold: '1'));

      final status = await PrinterStatus.query(conn);

      // headCold doesn't affect isReadyToPrint in SDK
      expect(status.isReadyToPrint, true);
      expect(status.isHeadCold, true);
    });

    test('parses labelsRemainingInBatch', () async {
      conn.queueResponse(buildHsResponse(labelsRemaining: '42'));

      final status = await PrinterStatus.query(conn);

      expect(status.labelsRemainingInBatch, 42);
    });

    test('sends ~HS command', () async {
      conn.queueResponse(buildHsResponse());

      await PrinterStatus.query(conn);

      expect(conn.allWrittenString, '~HS');
    });

    test('throws on malformed response (too few fields)', () async {
      conn.queueResponse(Uint8List.fromList('short,response'.codeUnits));

      expect(
        () => PrinterStatus.query(conn),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('PrinterStatus.statusMessages', () {
    test('returns Ready To Print when ready', () {
      const status = PrinterStatus(
        isReadyToPrint: true,
        isPaperOut: false,
        isPaused: false,
        isHeadOpen: false,
        isHeadTooHot: false,
        isHeadCold: false,
        isRibbonOut: false,
        isReceiveBufferFull: false,
        isPartialFormatInProgress: false,
        labelLengthInDots: 0,
        numberOfFormatsInReceiveBuffer: 0,
        labelsRemainingInBatch: 0,
        printMode: ZplPrintMode.tearOff,
      );
      expect(status.statusMessages, ['Ready To Print']);
    });

    test('returns HEAD OPEN and PAPER OUT when both set', () {
      const status = PrinterStatus(
        isReadyToPrint: false,
        isPaperOut: true,
        isPaused: false,
        isHeadOpen: true,
        isHeadTooHot: false,
        isHeadCold: false,
        isRibbonOut: false,
        isReceiveBufferFull: false,
        isPartialFormatInProgress: false,
        labelLengthInDots: 0,
        numberOfFormatsInReceiveBuffer: 0,
        labelsRemainingInBatch: 0,
        printMode: ZplPrintMode.tearOff,
      );
      expect(status.statusMessages, ['HEAD OPEN', 'PAPER OUT']);
    });

    test('returns all conditions when everything is wrong', () {
      const status = PrinterStatus(
        isReadyToPrint: false,
        isPaperOut: true,
        isPaused: true,
        isHeadOpen: true,
        isHeadTooHot: true,
        isHeadCold: false,
        isRibbonOut: true,
        isReceiveBufferFull: true,
        isPartialFormatInProgress: false,
        labelLengthInDots: 0,
        numberOfFormatsInReceiveBuffer: 0,
        labelsRemainingInBatch: 0,
        printMode: ZplPrintMode.tearOff,
      );
      expect(status.statusMessages, [
        'HEAD OPEN',
        'HEAD TOO HOT',
        'PAPER OUT',
        'RIBBON OUT',
        'RECEIVE BUFFER FULL',
        'PAUSE',
      ]);
    });

    test('returns INVALID STATUS when not ready but no conditions', () {
      const status = PrinterStatus(
        isReadyToPrint: false,
        isPaperOut: false,
        isPaused: false,
        isHeadOpen: false,
        isHeadTooHot: false,
        isHeadCold: false,
        isRibbonOut: false,
        isReceiveBufferFull: false,
        isPartialFormatInProgress: false,
        labelLengthInDots: 0,
        numberOfFormatsInReceiveBuffer: 0,
        labelsRemainingInBatch: 0,
        printMode: ZplPrintMode.tearOff,
      );
      expect(status.statusMessages, ['INVALID STATUS']);
    });
  });

  group('ZplPrintMode.fromHsChar', () {
    test('maps all SDK print mode characters', () {
      expect(ZplPrintMode.fromHsChar('0'), ZplPrintMode.rewind);
      expect(ZplPrintMode.fromHsChar('1'), ZplPrintMode.peelOff);
      expect(ZplPrintMode.fromHsChar('2'), ZplPrintMode.tearOff);
      expect(ZplPrintMode.fromHsChar('3'), ZplPrintMode.cutter);
      expect(ZplPrintMode.fromHsChar('4'), ZplPrintMode.applicator);
      expect(ZplPrintMode.fromHsChar('5'), ZplPrintMode.delayedCut);
      expect(ZplPrintMode.fromHsChar('6'), ZplPrintMode.linerlessPeel);
      expect(ZplPrintMode.fromHsChar('7'), ZplPrintMode.linerlessRewind);
      expect(ZplPrintMode.fromHsChar('8'), ZplPrintMode.partialCutter);
      expect(ZplPrintMode.fromHsChar('9'), ZplPrintMode.rfid);
      expect(ZplPrintMode.fromHsChar('K'), ZplPrintMode.kiosk);
      expect(ZplPrintMode.fromHsChar('k'), ZplPrintMode.kiosk);
      expect(ZplPrintMode.fromHsChar('X'), ZplPrintMode.unknown);
    });
  });
}
