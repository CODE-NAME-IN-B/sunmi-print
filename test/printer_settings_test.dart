import 'package:flutter_test/flutter_test.dart';
import 'package:sunmi_print_app/models/printer_settings.dart';

void main() {
  group('PrinterSettings', () {
    test('default pixelWidth is 384 for 58mm', () {
      const settings = PrinterSettings();
      expect(settings.pixelWidth, 384);
    });

    test('pixelWidth is 576 for 80mm', () {
      const settings = PrinterSettings(printerWidth: 'mm80');
      expect(settings.pixelWidth, 576);
    });

    test('toJson and fromJson round-trip', () {
      const settings = PrinterSettings(
        printDensity: 4,
        copies: 3,
        autoCut: false,
        applyDithering: true,
        pdfDpi: 203,
        printerWidth: 'mm80',
      );

      final json = settings.toJson();
      final restored = PrinterSettings.fromJson(json);

      expect(restored.printDensity, 4);
      expect(restored.copies, 3);
      expect(restored.autoCut, false);
      expect(restored.applyDithering, true);
      expect(restored.pdfDpi, 203);
      expect(restored.printerWidth, 'mm80');
    });

    test('copyWith preserves unchanged fields', () {
      const settings = PrinterSettings(printDensity: 2);
      final modified = settings.copyWith(copies: 5);

      expect(modified.copies, 5);
      expect(modified.printDensity, 2);
      expect(modified.printerWidth, 'mm58');
    });
  });
}
