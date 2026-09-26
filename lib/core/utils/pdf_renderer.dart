import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:pdf_render/pdf_render.dart';
import 'package:image/image.dart' as img;
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

  static const int defaultDpi = 203;

  static Stream<PdfRenderResult> renderPages({
    required String filePath,
    int dpi = defaultDpi,
    int printerWidthPx = 384,
    int startPage = 0,
  }) async* {
    final file = File(filePath);
    final pdfDoc = await PdfDocument.openFile(file.path);
    final int totalPages = pdfDoc.pageCount;

    try {
      for (int i = startPage; i < totalPages; i++) {
        final page = await pdfDoc.getPage(i + 1);
        final render = await page.render(
          width: (page.width * dpi / 72).round(),
          height: (page.height * dpi / 72).round(),
        );

        final rawBytes = render.pixels;
        final decoded = img.Image.fromBytes(
          width: render.width,
          height: render.height,
          bytes: rawBytes.buffer,
          numChannels: 4,
        );

        final gray = img.grayscale(decoded);

        final double aspectRatio = gray.width / gray.height;
        final int targetWidth = printerWidthPx;
        final int targetHeight = (targetWidth / aspectRatio).round();

        final resized = img.copyResize(
          gray,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear,
        );

        final dithered = floydSteinbergDither(resized);

        final int w = dithered.width;
        final int h = dithered.height;
        final Uint8List bitmapData = bitmapToBytes(dithered);

        render.dispose();

        yield PdfRenderResult(
          pageNumber: i + 1,
          totalPages: totalPages,
          bitmapData: bitmapData,
          width: w,
          height: h,
        );
      }
    } finally {
      await pdfDoc.dispose();
    }
  }
}
