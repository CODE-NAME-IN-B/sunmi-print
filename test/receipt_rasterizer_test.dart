import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sunmi_print_app/core/utils/bitmap_utils.dart';

/// A fresh [LuminancePlane] is all zeroes, which reads as "burned" because
/// zero is below the dithering threshold. Tests want blank paper unless they
/// say otherwise, so start from white.
LuminancePlane blankPlane(int width, int height) {
  final plane = LuminancePlane(width, height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      plane.set(x, y, 255);
    }
  }
  return plane;
}

void burn(LuminancePlane plane, int x, int y) => plane.set(x, y, 0);

void main() {
  group('unpackOneBitToRgba', () {
    test('round-trips a packed plane without losing or inventing dots', () {
      // A width that is not a multiple of 8, so the row padding path is
      // exercised rather than assumed.
      const width = 13;
      const height = 5;
      final plane = blankPlane(width, height);

      final lit = <List<int>>[
        [0, 1, 2, 3, 4, 5, 6, 7],
        [8],
        [0, 12],
        [3, 4, 5, 6],
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      ];
      for (int y = 0; y < lit.length; y++) {
        for (final x in lit[y]) {
          burn(plane, x, y);
        }
      }

      final packed = packOneBit(plane);
      final rgba = unpackOneBitToRgba(packed, width: width, height: height);

      expect(rgba.length, width * height * 4);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final o = (y * width + x) * 4;
          final expected = lit[y].contains(x) ? 0x00 : 0xFF;
          expect(rgba[o], expected, reason: 'red at ($x, $y)');
          expect(rgba[o + 1], expected, reason: 'green at ($x, $y)');
          expect(rgba[o + 2], expected, reason: 'blue at ($x, $y)');
          expect(rgba[o + 3], 0xFF, reason: 'alpha at ($x, $y)');
        }
      }
    });

    test('is MSB first and pads each row to a byte boundary', () {
      const width = 9;
      const height = 2;
      final plane = blankPlane(width, height);
      burn(plane, 0, 0);

      final packed = packOneBit(plane);

      // Two bytes per row: 9 dots do not fit in one.
      expect(packed.length, 4);
      // x=0 is the most significant bit of the first byte.
      expect(packed[0], 0x80);
      // The pad bit of the first row and the whole second row stay clear.
      expect(packed[1], 0x00);
      expect(packed[2], 0x00);
      expect(packed[3], 0x00);
    });
  });

  group('unpackOneBitToPng', () {
    test('produces a PNG an image decoder can actually read', () {
      const width = 8;
      const height = 2;
      final plane = blankPlane(width, height);
      burn(plane, 0, 0);
      burn(plane, 3, 1);

      final png = unpackOneBitToPng(
        packOneBit(plane),
        width: width,
        height: height,
      );

      // PNG signature. This is the whole point of the helper: a packed 1-bit
      // buffer handed to `Image.memory` decodes to nothing.
      expect(png.sublist(0, 8), [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);

      final decoded = img.decodePng(png);
      expect(decoded, isNotNull);
      expect(decoded!.width, width);
      expect(decoded.height, height);

      int at(int x, int y) => decoded.getPixel(x, y).r.toInt();
      expect(at(0, 0), 0, reason: 'burned dot is black');
      expect(at(1, 0), 255, reason: 'unburned dot is white');
      expect(at(3, 1), 0, reason: 'burned dot is black');
      expect(at(0, 1), 255, reason: 'unburned dot is white');
    });
  });

  group('unpackOneBitToRgba input handling', () {
    test('rejects a buffer that cannot hold the requested geometry', () {
      // A 1-bit 8x8 page is 8 bytes. Asking for a taller page would index
      // past the end, so this has to fail loudly rather than print garbage.
      final packed = Uint8List(8);

      expect(
        () => unpackOneBitToRgba(packed, width: 8, height: 9),
        throwsA(isA<RangeError>()),
      );
    });
  });
}
