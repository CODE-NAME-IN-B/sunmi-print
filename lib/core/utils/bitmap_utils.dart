import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Luminance buffer used by the dithering pass. Kept as a flat list so the
/// inner loop stays monomorphic and allocation free.
class LuminancePlane {
  LuminancePlane(this.width, this.height) : data = Float32List(width * height);

  final int width;
  final int height;
  final Float32List data;

  double at(int x, int y) => data[y * width + x];

  void set(int x, int y, double value) => data[y * width + x] = value;
}

/// Reads the luminance of every pixel into a flat [LuminancePlane].
///
/// Works on the raw channel bytes instead of `getPixel` per coordinate, which
/// removes the per-pixel `Pixel` object allocation that dominated the previous
/// implementation.
LuminancePlane extractLuminance(img.Image image) {
  final plane = LuminancePlane(image.width, image.height);
  final data = plane.data;
  final channels = image.numChannels;
  final bytes = image.getBytes(order: img.ChannelOrder.rgba);

  final pixelCount = image.width * image.height;
  if (channels >= 3 && bytes.length >= pixelCount * 3) {
    // Interleaved RGB(A) source, the common case for decoded photos.
    for (int i = 0, p = 0; p < pixelCount; p++, i += channels) {
      data[p] = 0.299 * bytes[i] + 0.587 * bytes[i + 1] + 0.114 * bytes[i + 2];
    }
  } else if (bytes.length >= pixelCount) {
    for (int p = 0; p < pixelCount; p++) {
      data[p] = bytes[p].toDouble();
    }
  } else {
    // Last resort for exotic layouts: fall back to the generic accessor.
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        data[y * image.width + x] = img
            .getLuminance(image.getPixel(x, y))
            .toDouble();
      }
    }
  }

  return plane;
}

/// Floyd-Steinberg error diffusion over an existing luminance plane.
///
/// Mutates [plane] in place: every sample becomes either `0` or `255`.
void diffuseError(LuminancePlane plane, {int thresholdLevel = 128}) {
  final data = plane.data;
  final w = plane.width;
  final h = plane.height;
  final threshold = thresholdLevel.toDouble();

  for (int y = 0; y < h; y++) {
    final rowStart = y * w;
    // Serpentine scanning removes the directional artefacts plain
    // left-to-right diffusion leaves on gradients.
    final leftToRight = (y & 1) == 0;
    final hasNextRow = y + 1 < h;
    final nextRowStart = hasNextRow ? rowStart + w : 0;

    for (int step = 0; step < w; step++) {
      final x = leftToRight ? step : w - 1 - step;
      final index = rowStart + x;

      final oldValue = data[index];
      final newValue = oldValue < threshold ? 0.0 : 255.0;
      data[index] = newValue;
      final error = oldValue - newValue;
      if (error == 0) continue;

      // The kernel mirrors horizontally on right-to-left rows. Column indices
      // are validated individually: a neighbour in the next row is addressed as
      // `nextRowStart + column`, so checking the flat neighbour index alone
      // would let the column offset run off the end of the buffer.
      final nearX = leftToRight ? x + 1 : x - 1;
      if (nearX >= 0 && nearX < w) {
        data[rowStart + nearX] += error * 0.4375; // 7/16
      }

      if (!hasNextRow) continue;

      final farX = leftToRight ? x - 1 : x + 1;
      if (farX >= 0 && farX < w) {
        data[nextRowStart + farX] += error * 0.1875; // 3/16
      }
      data[nextRowStart + x] += error * 0.3125; // 5/16
      if (nearX >= 0 && nearX < w) {
        data[nextRowStart + nearX] += error * 0.0625; // 1/16
      }
    }
  }
}

/// Hard threshold without error diffusion. Cheaper, and better for content
/// that is already pure black and white (logos, generated QR codes).
void applyThreshold(LuminancePlane plane, {int thresholdLevel = 128}) {
  final data = plane.data;
  final threshold = thresholdLevel.toDouble();
  for (int i = 0; i < data.length; i++) {
    data[i] = data[i] < threshold ? 0.0 : 255.0;
  }
}

/// Packs a luminance plane into the 1-bit-per-pixel format consumed by the
/// ESC/POS `GS v 0` command.
///
/// ESC/POS counts one bit per dot, most significant bit first, and a set bit
/// means "burn this dot", so black pixels (low luminance) set their bit.
Uint8List packOneBit(LuminancePlane plane, {int thresholdLevel = 128}) {
  final w = plane.width;
  final h = plane.height;
  final bytesPerRow = (w + 7) ~/ 8;
  final out = Uint8List(bytesPerRow * h);
  final data = plane.data;
  final threshold = thresholdLevel;

  for (int y = 0; y < h; y++) {
    final rowStart = y * w;
    final outStart = y * bytesPerRow;
    for (int x = 0; x < w; x++) {
      if (data[rowStart + x] < threshold) {
        out[outStart + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }

  return out;
}

/// Expands a buffer produced by [packOneBit] back into RGBA.
///
/// This is the inverse of [packOneBit], including the MSB-first bit order and
/// the row padding. It exists so the on-screen preview can be rebuilt from the
/// exact bytes that go to the printhead, instead of holding on to the full
/// colour raster that produced them. A long receipt's colour raster is several
/// megabytes, while the packed form is one bit per dot and is what everything
/// downstream actually needs.
Uint8List unpackOneBitToRgba(
  List<int> packed, {
  required int width,
  required int height,
}) {
  final bytesPerRow = (width + 7) ~/ 8;
  final out = Uint8List(width * height * 4);

  for (int y = 0; y < height; y++) {
    final packedStart = y * bytesPerRow;
    final rowStart = y * width * 4;
    for (int x = 0; x < width; x++) {
      final bit = packed[packedStart + (x >> 3)] & (0x80 >> (x & 7));
      // A set bit means "burn this dot", so it becomes black.
      final value = bit == 0 ? 0xFF : 0x00;
      final o = rowStart + x * 4;
      out[o] = value;
      out[o + 1] = value;
      out[o + 2] = value;
      out[o + 3] = 0xFF;
    }
  }

  return out;
}

/// Encodes a buffer produced by [packOneBit] as a PNG.
///
/// A packed 1-bit buffer is not something an image decoder can read, so
/// anything that wants to *show* a receipt on screen rather than print it has
/// to go through here. Encoding PNG rather than a raw RGBA buffer means the
/// result can be handed straight to `Image.memory`, which decodes it off the
/// UI thread.
Uint8List unpackOneBitToPng(
  List<int> packed, {
  required int width,
  required int height,
  int level = 3,
}) {
  final rgba = unpackOneBitToRgba(packed, width: width, height: height);
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return Uint8List.fromList(img.encodePng(image, level: level));
}

/// Error-diffused 1-bit conversion of [image].
Uint8List ditherToOneBit(img.Image image, {int thresholdLevel = 128}) {
  final plane = extractLuminance(image);
  diffuseError(plane, thresholdLevel: thresholdLevel);
  return packOneBit(plane, thresholdLevel: thresholdLevel);
}

/// Plain threshold 1-bit conversion of [image].
Uint8List thresholdToOneBit(img.Image image, {int thresholdLevel = 128}) {
  final plane = extractLuminance(image);
  applyThreshold(plane, thresholdLevel: thresholdLevel);
  return packOneBit(plane, thresholdLevel: thresholdLevel);
}

/// Wraps a packed 1-bit buffer in a 1-bit Windows bitmap.
///
/// The on-device Sunmi SDK decodes whatever it is given with
/// `BitmapFactory.decodeByteArray`, so it needs a real image container rather
/// than a bare ESC/POS payload. A 1-bit BMP is the cheapest container Android
/// can decode, and it costs no compression pass.
///
/// The palette is written white-first so that "bit set" keeps meaning "burn
/// this dot", matching [packOneBit].
Uint8List packOneBitBmp(List<int> packed, {required int pixelWidth}) {
  final bytesPerRow = (pixelWidth + 7) ~/ 8;
  if (bytesPerRow == 0 || packed.length % bytesPerRow != 0) {
    throw ArgumentError(
      'packed 1-bit length is not a multiple of the row size',
    );
  }
  final height = packed.length ~/ bytesPerRow;

  // BMP rows are padded to a 4 byte boundary and stored bottom-up.
  final bmpRowBytes = ((bytesPerRow + 3) ~/ 4) * 4;
  final imageSize = bmpRowBytes * height;
  const headerSize =
      14 + 40 + 8; // file header + info header + 2 palette entries

  final out = Uint8List(headerSize + imageSize);
  final view = ByteData.view(out.buffer);

  // BITMAPFILEHEADER
  out[0] = 0x42; // 'B'
  out[1] = 0x4D; // 'M'
  view.setUint32(2, out.length, Endian.little);
  view.setUint32(10, headerSize, Endian.little);

  // BITMAPINFOHEADER
  view.setUint32(14, 40, Endian.little);
  view.setInt32(18, pixelWidth, Endian.little);
  view.setInt32(22, height, Endian.little); // positive => bottom-up
  view.setUint16(26, 1, Endian.little); // planes
  view.setUint16(28, 1, Endian.little); // bits per pixel
  view.setUint32(30, 0, Endian.little); // BI_RGB
  view.setUint32(34, imageSize, Endian.little);
  view.setInt32(38, 2835, Endian.little); // 72 DPI
  view.setInt32(42, 2835, Endian.little);

  // Palette: index 0 is white, index 1 is black.
  for (int i = 0; i < 4; i++) {
    out[54 + i] = 0xFF;
    out[58 + i] = 0x00;
  }

  var outRow = headerSize;
  var srcRow = height - 1;
  while (srcRow >= 0) {
    out.setRange(outRow, outRow + bytesPerRow, packed, srcRow * bytesPerRow);
    srcRow--;
    outRow += bmpRowBytes;
  }

  return out;
}

/// Converts [image] to 1-bit using [dither] when true, threshold otherwise.
Uint8List toOneBit(
  img.Image image, {
  bool dither = true,
  int thresholdLevel = 128,
}) => dither
    ? ditherToOneBit(image, thresholdLevel: thresholdLevel)
    : thresholdToOneBit(image, thresholdLevel: thresholdLevel);
