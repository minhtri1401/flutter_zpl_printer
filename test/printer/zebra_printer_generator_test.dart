import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:image/image.dart' as img;

import '../mocks/mock_connection.dart';

Uint8List _png() {
  final image = img.Image(width: 16, height: 4);
  img.fill(image, color: img.ColorRgb8(0, 0, 0));
  return img.encodePng(image);
}

void main() {
  late MockConnection conn;
  late ZebraPrinter printer;

  setUp(() async {
    conn = MockConnection(
      config: const ConnectionConfig(
        maxTimeoutForRead: 200,
        timeToWaitForMoreData: 50,
        interChunkDelayMs: 0,
      ),
    );
    await conn.open();
    printer = ZebraPrinter(conn);
  });

  test('barrel re-exports flutter_zpl_generator (one import)', () {
    // Compiles only if the generator types are visible through the barrel.
    const recall = ZplImageRecall();
    expect(recall.graphicName, 'IMG');
    expect(ZplPrintMode.tearOff, isNotNull); // generator's label setting
    expect(PrinterPrintMode.tearOff, isNotNull); // printer's ~HS status value
  });

  test('printLabel sends the built ZPL', () async {
    final label = ZplGenerator(
      config: const ZplConfiguration(printWidth: 400),
      commands: [ZplText(x: 10, y: 10, text: 'Hello')],
    );

    await printer.printLabel(label);

    expect(conn.allWrittenString, await label.build());
    expect(conn.allWrittenString, contains('^FDHello^FS'));
  });

  test('printImage downloads with ~DG before ^XA, then recalls with ^XG', () async {
    await printer.printImage(_png(), x: 10, y: 20);

    final zpl = conn.allWrittenString;
    expect(zpl, startsWith('~DGIMG,'));
    expect(zpl.indexOf('~DGIMG,'), lessThan(zpl.indexOf('^XA')));
    expect(zpl, contains('^FO10,20'));
    expect(zpl, contains('^XGIMG,1,1^FS'));
    expect(zpl, isNot(contains(':Z64:'))); // uncompressed hex
    expect(zpl.trimRight(), endsWith('^XZ'));
  });

  test('printImage honours graphicName', () async {
    await printer.printImage(_png(), graphicName: 'LOGO');

    expect(conn.allWrittenString, startsWith('~DGLOGO,'));
    expect(conn.allWrittenString, contains('^XGLOGO,1,1^FS'));
  });
}
