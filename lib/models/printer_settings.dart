import 'dart:convert';

import '../core/constants/app_constants.dart';

/// Roll sizes offered in the printer settings screen. [custom] lets the shop
/// owner type the printable width in millimetres directly, which is what
/// actually determines the dot width of the printhead.
enum PaperPreset { mm58, mm80, mm100, custom }

extension PaperPresetX on PaperPreset {
  /// The physical roll width advertised on the paper box.
  int get rollWidthMm => switch (this) {
    PaperPreset.mm58 => 58,
    PaperPreset.mm80 => 80,
    PaperPreset.mm100 => 100,
    PaperPreset.custom => AppConstants.minPaperWidthMm,
  };

  /// Printable width in millimetres for this preset. Rolls are wider than the
  /// area the printhead can address, so 58mm paper yields 48mm of dots.
  int printableWidthMm({required int customWidthMm}) => switch (this) {
    PaperPreset.mm58 => AppConstants.printableWidth58mm,
    PaperPreset.mm80 => AppConstants.printableWidth80mm,
    PaperPreset.mm100 => AppConstants.printableWidth100mm,
    PaperPreset.custom => customWidthMm,
  };
}

class PrinterSettings {
  final PaperPreset paperPreset;
  final int customWidthMm;
  final int printerDpi;
  final int printDensity;
  final int copies;
  final bool autoCut;
  final bool applyDithering;
  final int pdfDpi;

  const PrinterSettings({
    this.paperPreset = PaperPreset.mm58,
    this.customWidthMm = AppConstants.printableWidth58mm,
    this.printerDpi = AppConstants.pdfDefaultDpi,
    this.printDensity = AppConstants.defaultPrintDensity,
    this.copies = 1,
    this.autoCut = true,
    this.applyDithering = true,
    this.pdfDpi = AppConstants.pdfDefaultDpi,
  });

  PrinterSettings copyWith({
    PaperPreset? paperPreset,
    int? customWidthMm,
    int? printerDpi,
    int? printDensity,
    int? copies,
    bool? autoCut,
    bool? applyDithering,
    int? pdfDpi,
  }) {
    return PrinterSettings(
      paperPreset: paperPreset ?? this.paperPreset,
      customWidthMm: customWidthMm ?? this.customWidthMm,
      printerDpi: printerDpi ?? this.printerDpi,
      printDensity: printDensity ?? this.printDensity,
      copies: copies ?? this.copies,
      autoCut: autoCut ?? this.autoCut,
      applyDithering: applyDithering ?? this.applyDithering,
      pdfDpi: pdfDpi ?? this.pdfDpi,
    );
  }

  /// Printable width in millimetres, clamped to the range the hardware accepts.
  int get paperWidthMm => paperPreset
      .printableWidthMm(customWidthMm: customWidthMm)
      .clamp(AppConstants.minPaperWidthMm, AppConstants.maxPaperWidthMm);

  /// Dot width of a single printed line.
  ///
  /// `pixels = millimetres x dpi / 25.4`, rounded to the nearest whole byte of
  /// dots because the ESC/POS `GS v 0` command counts 8 pixels per byte.
  ///
  /// 48mm @ 203dpi -> 384, 72mm @ 203dpi -> 576, 80mm @ 300dpi -> 944.
  int get pixelWidth {
    final raw = (paperWidthMm * printerDpi / 25.4).round();
    final aligned = _roundToByte(raw);
    return aligned.clamp(
      AppConstants.minPixelWidth,
      AppConstants.maxPixelWidth,
    );
  }

  /// Bytes needed to carry one printed line of [pixelWidth] dots.
  int get bytesPerRow => pixelWidth ~/ 8;

  /// Character grid used by the receipt layout. Thermal heads print in fixed
  /// pitch cells, and the cell count is derived from the dot width so Arabic
  /// and Latin text share the same table.
  int get textColumns {
    if (printerDpi >= 300) return 64;
    return paperWidthMm >= 72 ? 48 : 32;
  }

  /// A safe upper bound for the rasterised page height, used to cap canvases.
  int get maxPrintHeightPx => AppConstants.maxPrintHeightPx;

  static int _roundToByte(int pixels) {
    if (pixels < 8) return 8;
    return ((pixels + 4) ~/ 8) * 8;
  }

  Map<String, dynamic> toJson() => {
    'paperPreset': paperPreset.name,
    'customWidthMm': customWidthMm,
    'printerDpi': printerDpi,
    'printDensity': printDensity,
    'copies': copies,
    'autoCut': autoCut,
    'applyDithering': applyDithering,
    'pdfDpi': pdfDpi,
  };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) {
    return PrinterSettings(
      paperPreset: _parsePreset(json),
      customWidthMm:
          _parseInt(json['customWidthMm']) ?? AppConstants.printableWidth58mm,
      printerDpi: _parseDpi(json['printerDpi']),
      printDensity:
          (_parseInt(json['printDensity']) ?? AppConstants.defaultPrintDensity)
              .clamp(
                AppConstants.minPrintDensity,
                AppConstants.maxPrintDensity,
              ),
      copies: (_parseInt(json['copies']) ?? 1).clamp(1, 99),
      autoCut: json['autoCut'] as bool? ?? true,
      applyDithering: json['applyDithering'] as bool? ?? true,
      pdfDpi: _parseDpi(json['pdfDpi']),
    );
  }

  /// Accepts the legacy `printerWidth` field ("mm58" / "mm80") written by
  /// earlier versions so saved settings survive the upgrade.
  static PaperPreset _parsePreset(Map<String, dynamic> json) {
    final name =
        json['paperPreset']?.toString() ?? json['printerWidth']?.toString();
    return PaperPreset.values.firstWhere(
      (preset) => preset.name == name,
      orElse: () => PaperPreset.mm58,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int _parseDpi(Object? value) {
    final parsed = _parseInt(value);
    if (parsed == null) return AppConstants.pdfDefaultDpi;
    return AppConstants.supportedDpi.contains(parsed)
        ? parsed
        : AppConstants.pdfDefaultDpi;
  }

  String encode() => jsonEncode(toJson());

  static PrinterSettings decode(String raw) =>
      PrinterSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
