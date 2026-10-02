import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_generator/flutter_zpl_generator.dart' as zpl;
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';
import 'package:flutter_zpl_printer_example/src/test_image.dart';

void main() {
  test('test picture encodes through both image paths', () async {
    final png = buildTestImagePng();

    final grf = GrfEncoder.encode(png, targetWidth: 384);
    expect(grf.bytesPerRow, 48);
    expect(grf.hexData, isNotEmpty);

    final label = await zpl.ZplGenerator(
      config: const zpl.ZplConfiguration(printWidth: 384),
      autoLabelLengthFromFirstImage: true,
      commands: [
        zpl.ZplImageDownload(image: png, targetWidth: 384),
        const zpl.ZplImageRecall(),
      ],
    ).build();
    expect(label, startsWith('~DGIMG,'));
    expect(label, contains('^XGIMG'));
  });
}
