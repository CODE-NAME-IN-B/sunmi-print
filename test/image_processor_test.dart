import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart';
import 'package:sunmi_print_app/core/utils/image_processor.dart';

void main() {
  group('ImageProcessor', () {
    test('processForPrinter returns non-empty data', () async {
      final testImage = _createTestImageBytes();
      final result = ImageProcessor.processForPrinter(
        testImage,
        printerWidthPx: 384,
      );
      expect(result, isNotEmpty);
    });

    test('processForPrinter output width matches expected bytes per row', () {
      const width = 384;
      final testImage = _createTestImageBytes();
      final result = ImageProcessor.processForPrinter(
        testImage,
        printerWidthPx: width,
      );
      const expectedBytesPerRow = (384 + 7) ~/ 8;
      expect(result.length % expectedBytesPerRow, 0);
    });
  });
}

Uint8List _createTestImageBytes() {
  final image = Image(width: 100, height: 100);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      final val = (x + y) % 2 == 0 ? 255 : 0;
      image.setPixelRgb(x, y, val, val, val);
    }
  }
  return encodePng(image);
}
