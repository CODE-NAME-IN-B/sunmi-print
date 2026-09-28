import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/printer_settings.dart';
import '../constants/app_constants.dart';
import 'bitmap_utils.dart';

/// Raised when the payload handed to the print pipeline cannot be turned into
/// a raster. Carries an Arabic message because it is surfaced verbatim in the
/// queue and on screen.
class ImageProcessingException implements Exception {
  const ImageProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImageProcessor {
  ImageProcessor._();

  static const int width58mm = AppConstants.printWidth58mm;
  static const int width80mm = AppConstants.printWidth80mm;

  /// Decodes [imageBytes], rescales it to exactly [printerWidthPx] dots while
  /// preserving the aspect ratio, and returns the 1-bit buffer.
  static Uint8List processForPrinter(
    Uint8List imageBytes, {
    required int printerWidthPx,
    bool applyDithering = true,
  }) {
    final original = img.decodeImage(imageBytes);
    if (original == null) {
      throw const ImageProcessingException(
        'تعذر فك تشفير الصورة — قد تكون الصورة تالفة أو بصيغة غير مدعومة',
      );
    }

    return processImageForPrinter(
      original,
      printerWidthPx: printerWidthPx,
      applyDithering: applyDithering,
    );
  }

  /// Same as [processForPrinter] for an already decoded image.
  static Uint8List processImageForPrinter(
    img.Image source, {
    required int printerWidthPx,
    bool applyDithering = true,
  }) {
    if (source.width <= 0 || source.height <= 0) {
      throw const ImageProcessingException('الصورة فارغة أو بأبعاد غير صالحة');
    }

    final targetWidth = printerWidthPx.clamp(
      AppConstants.minPixelWidth,
      AppConstants.maxPixelWidth,
    );

    final gray = img.grayscale(source);

    // Fit to the printhead width while preserving the aspect ratio. The height
    // is capped so a very tall image cannot allocate an unbounded canvas.
    double scale = targetWidth / gray.width;
    var targetHeight = (gray.height * scale).round();
    if (targetHeight > AppConstants.maxPrintHeightPx) {
      scale *= AppConstants.maxPrintHeightPx / targetHeight;
      targetHeight = AppConstants.maxPrintHeightPx;
    }
    if (targetHeight < 1) targetHeight = 1;

    final resized = img.copyResize(
      gray,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    return toOneBit(resized, dither: applyDithering);
  }

  /// Convenience wrapper that derives the target width from [settings].
  static Uint8List processForSettings(
    Uint8List imageBytes,
    PrinterSettings settings,
  ) => processForPrinter(
    imageBytes,
    printerWidthPx: settings.pixelWidth,
    applyDithering: settings.applyDithering,
  );
}
