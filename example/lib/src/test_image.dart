import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Draws a small black-and-white test picture and returns it as PNG bytes.
///
/// Solid shapes, thin lines, and text make it easy to spot a bad image
/// encoding on a printed label. Generated in code so the example needs no
/// asset files.
Uint8List buildTestImagePng({int width = 400, int height = 200}) {
  final black = img.ColorRgb8(0, 0, 0);
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  img.drawRect(
    image,
    x1: 0,
    y1: 0,
    x2: width - 1,
    y2: height - 1,
    color: black,
    thickness: 4,
  );
  img.fillCircle(image, x: 60, y: height ~/ 2, radius: 40, color: black);
  img.fillRect(image, x1: 120, y1: 30, x2: 180, y2: 90, color: black);
  for (var x = 120; x <= 180; x += 6) {
    img.drawLine(image, x1: x, y1: 110, x2: x, y2: 170, color: black);
  }
  img.drawString(
    image,
    'flutter_zpl_printer',
    font: img.arial24,
    x: 200,
    y: 60,
    color: black,
  );
  img.drawString(
    image,
    'image test',
    font: img.arial24,
    x: 200,
    y: 110,
    color: black,
  );

  return img.encodePng(image);
}
