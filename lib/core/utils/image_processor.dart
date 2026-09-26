import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'bitmap_utils.dart';

class ImageProcessor {
  ImageProcessor._();

  static const int width58mm = 384;
  static const int width80mm = 576;

  static Uint8List processForPrinter(
    Uint8List imageBytes, {
    required int printerWidthPx,
    bool applyDithering = true,
  }) {
    final original = img.decodeImage(imageBytes);
    if (original == null) {
      throw ArgumentError('تعذر فك تشفير الصورة — قد تكون الصورة تالفة أو بصيغة غير مدعومة');
    }

    final gray = img.grayscale(original);

    final double aspectRatio = gray.width / gray.height;
    final int targetWidth = printerWidthPx;
    final int targetHeight = (targetWidth / aspectRatio).round();

    final resized = img.copyResize(
      gray,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    final processed = applyDithering
        ? floydSteinbergDither(resized)
        : threshold(resized);

    return bitmapToBytes(processed);
  }
}
