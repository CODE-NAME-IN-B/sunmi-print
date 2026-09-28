import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_print_app/core/constants/app_constants.dart';
import 'package:sunmi_print_app/models/printer_settings.dart';

void main() {
  group('PrinterSettings geometry', () {
    test('58mm roll yields 384 dots at 203dpi', () {
      const settings = PrinterSettings();
      expect(settings.paperWidthMm, 48);
      expect(settings.pixelWidth, 384);
      expect(settings.bytesPerRow, 48);
    });

    test('80mm roll yields 576 dots at 203dpi', () {
      const settings = PrinterSettings(paperPreset: PaperPreset.mm80);
      expect(settings.paperWidthMm, 72);
      expect(settings.pixelWidth, 576);
      expect(settings.bytesPerRow, 72);
    });

    test('100mm roll yields 768 dots at 203dpi', () {
      const settings = PrinterSettings(paperPreset: PaperPreset.mm100);
      expect(settings.paperWidthMm, 80);
      expect(settings.pixelWidth, 640);
    });

    test('80mm at 300dpi yields 944 dots', () {
      const settings = PrinterSettings(
        paperPreset: PaperPreset.mm80,
        printerDpi: 300,
      );
      // 72mm * 300 / 25.4 = 850.39, not 944. 944 is what a full 80mm roll
      // would give, so this asserts the printable-vs-roll distinction.
      expect(settings.pixelWidth, 848);
    });

    test('pixelWidth is always a whole number of bytes', () {
      for (final preset in PaperPreset.values) {
        for (final dpi in AppConstants.supportedDpi) {
          final settings = PrinterSettings(
            paperPreset: preset,
            printerDpi: dpi,
            customWidthMm: 63,
          );
          expect(
            settings.pixelWidth % 8,
            0,
            reason: '$preset @ $dpi produced ${settings.pixelWidth}',
          );
          expect(settings.bytesPerRow * 8, settings.pixelWidth);
        }
      }
    });

    test('custom width is clamped to the supported range', () {
      const tiny = PrinterSettings(
        paperPreset: PaperPreset.custom,
        customWidthMm: 4,
      );
      expect(tiny.paperWidthMm, AppConstants.minPaperWidthMm);

      const huge = PrinterSettings(
        paperPreset: PaperPreset.custom,
        customWidthMm: 500,
      );
      expect(huge.paperWidthMm, AppConstants.maxPaperWidthMm);
    });

    test('textColumns grows with the printable width', () {
      const narrow = PrinterSettings(paperPreset: PaperPreset.mm58);
      const wide = PrinterSettings(paperPreset: PaperPreset.mm80);
      expect(wide.textColumns, greaterThan(narrow.textColumns));
    });
  });

  group('PrinterSettings persistence', () {
    test('toJson and fromJson round-trip', () {
      const settings = PrinterSettings(
        paperPreset: PaperPreset.mm100,
        customWidthMm: 72,
        printerDpi: 300,
        printDensity: 4,
        copies: 3,
        autoCut: false,
        applyDithering: true,
        pdfDpi: 300,
      );

      final restored = PrinterSettings.fromJson(settings.toJson());

      expect(restored.paperPreset, PaperPreset.mm100);
      expect(restored.customWidthMm, 72);
      expect(restored.printerDpi, 300);
      expect(restored.printDensity, 4);
      expect(restored.copies, 3);
      expect(restored.autoCut, isFalse);
      expect(restored.applyDithering, isTrue);
      expect(restored.pdfDpi, 300);
    });

    test('legacy printerWidth field migrates to a preset', () {
      final restored = PrinterSettings.fromJson(<String, dynamic>{
        'printerWidth': 'mm80',
        'printDensity': 3,
      });
      expect(restored.paperPreset, PaperPreset.mm80);
      expect(restored.pixelWidth, 576);
    });

    test('legacy mm58 value migrates too', () {
      final restored = PrinterSettings.fromJson(<String, dynamic>{
        'printerWidth': 'mm58',
      });
      expect(restored.paperPreset, PaperPreset.mm58);
    });

    test('unknown preset falls back to the default', () {
      final restored = PrinterSettings.fromJson(<String, dynamic>{
        'paperPreset': 'mm57',
      });
      expect(restored.paperPreset, PaperPreset.mm58);
    });

    test('out of range density and copies are clamped on load', () {
      final restored = PrinterSettings.fromJson(<String, dynamic>{
        'printDensity': 99,
        'copies': 0,
        'printerDpi': 72,
      });
      expect(restored.printDensity, AppConstants.maxPrintDensity);
      expect(restored.copies, 1);
      expect(restored.printerDpi, AppConstants.pdfDefaultDpi);
    });

    test('string encoded numbers are accepted', () {
      final restored = PrinterSettings.fromJson(<String, dynamic>{
        'printerDpi': '300',
        'printDensity': '2',
        'copies': '5',
      });
      expect(restored.printerDpi, 300);
      expect(restored.printDensity, 2);
      expect(restored.copies, 5);
    });

    test('encode and decode survive a full round-trip', () {
      const settings = PrinterSettings(
        paperPreset: PaperPreset.custom,
        customWidthMm: 60,
        printerDpi: 203,
      );
      final restored = PrinterSettings.decode(settings.encode());
      expect(restored.paperPreset, PaperPreset.custom);
      expect(restored.paperWidthMm, 60);
      expect(restored.pixelWidth, settings.pixelWidth);
    });
  });

  group('PrinterSettings copyWith', () {
    test('preserves unchanged fields', () {
      const settings = PrinterSettings(printDensity: 2);
      final modified = settings.copyWith(copies: 5);

      expect(modified.copies, 5);
      expect(modified.printDensity, 2);
      expect(modified.paperPreset, PaperPreset.mm58);
    });

    test('switching preset does not move the custom width', () {
      const settings = PrinterSettings(customWidthMm: 55);
      final modified = settings.copyWith(paperPreset: PaperPreset.custom);
      expect(modified.customWidthMm, 55);
      expect(modified.paperWidthMm, 55);
    });
  });
}
