import 'dart:typed_data';
import 'package:image/image.dart' as img;

img.Image floydSteinbergDither(img.Image image) {
  final int w = image.width;
  final int h = image.height;

  final pixels = List.generate(
    h,
    (_) => List.filled(w, 0.0),
  );

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      pixels[y][x] = img.getLuminance(p).toDouble();
    }
  }

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final double oldPixel = pixels[y][x];
      final double newPixel = oldPixel < 128 ? 0.0 : 255.0;
      pixels[y][x] = newPixel;

      final double error = oldPixel - newPixel;

      if (x + 1 < w) pixels[y][x + 1] += error * (7 / 16);
      if (y + 1 < h) {
        if (x - 1 >= 0) pixels[y + 1][x - 1] += error * (3 / 16);
        pixels[y + 1][x] += error * (5 / 16);
        if (x + 1 < w) pixels[y + 1][x + 1] += error * (1 / 16);
      }
    }
  }

  final output = img.Image(width: w, height: h);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final int val = pixels[y][x] < 128 ? 0 : 255;
      output.setPixelRgb(x, y, val, val, val);
    }
  }

  return output;
}

Uint8List bitmapToBytes(img.Image image) {
  final int w = image.width;
  final int h = image.height;
  final int bytesPerRow = (w + 7) ~/ 8;
  final Uint8List data = Uint8List(bytesPerRow * h);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final pixel = image.getPixel(x, y);
      final luminance = img.getLuminance(pixel);
      if (luminance < 128) {
        final int byteIndex = y * bytesPerRow + x ~/ 8;
        final int bitIndex = 7 - (x % 8);
        data[byteIndex] |= (1 << bitIndex);
      }
    }
  }

  return data;
}

img.Image threshold(img.Image image) {
  final int w = image.width;
  final int h = image.height;
  final output = img.Image(width: w, height: h);

  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final luminance = img.getLuminance(p);
      final int val = luminance < 128 ? 0 : 255;
      output.setPixelRgb(x, y, val, val, val);
    }
  }

  return output;
}
