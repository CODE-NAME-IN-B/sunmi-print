import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf_render/pdf_render.dart';

import '../constants/app_constants.dart';
import 'bitmap_utils.dart';

class PdfRenderResult {
  final int pageNumber;
  final int totalPages;
  final Uint8List bitmapData;
  final int width;
  final int height;

  PdfRenderResult({
    required this.pageNumber,
    required this.totalPages,
    required this.bitmapData,
    required this.width,
    required this.height,
  });
}

class PdfRenderer {
  PdfRenderer._();

  static const int defaultDpi = AppConstants.pdfDefaultDpi;

  /// Renders each page of [filePath] as a 1-bit buffer sized for the printhead.
  ///
  /// Pages are yielded one at a time and the native render handle is released
  /// immediately afterwards, so a 200 page document never holds more than one
  /// page of pixels in memory.
  static Stream<PdfRenderResult> renderPages({
    required String filePath,
    int dpi = defaultDpi,
    int printerWidthPx = AppConstants.printWidth58mm,
    bool applyDithering = true,
    int startPage = 0,
  }) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('ملف PDF غير موجود: $filePath');
    }

    final pdfDoc = await PdfDocument.openFile(file.path);
    final int totalPages = pdfDoc.pageCount;
    final int safeStart = startPage.clamp(0, totalPages);

    try {
      for (int i = safeStart; i < totalPages; i++) {
        final page = await pdfDoc.getPage(i + 1);
        PdfPageImage? render;
        try {
          render = await page.render(
            width: (page.width * dpi / 72).round(),
            height: (page.height * dpi / 72).round(),
          );

          final decoded = img.Image.fromBytes(
            width: render.width,
            height: render.height,
            bytes: render.pixels.buffer,
            numChannels: 4,
          );

          final gray = img.grayscale(decoded);
          final targetWidth = printerWidthPx.clamp(
            AppConstants.minPixelWidth,
            AppConstants.maxPixelWidth,
          );

          var scale = targetWidth / gray.width;
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

          final bitmapData = toOneBit(resized, dither: applyDithering);

          yield PdfRenderResult(
            pageNumber: i + 1,
            totalPages: totalPages,
            bitmapData: bitmapData,
            width: targetWidth,
            height: targetHeight,
          );
        } finally {
          render?.dispose();
        }
      }
    } finally {
      await pdfDoc.dispose();
    }
  }
}
