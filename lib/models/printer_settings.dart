class PrinterSettings {
  final int printDensity;
  final int copies;
  final bool autoCut;
  final bool applyDithering;
  final int pdfDpi;
  final String printerWidth;

  const PrinterSettings({
    this.printDensity = 3,
    this.copies = 1,
    this.autoCut = true,
    this.applyDithering = true,
    this.pdfDpi = 203,
    this.printerWidth = 'mm58',
  });

  PrinterSettings copyWith({
    int? printDensity,
    int? copies,
    bool? autoCut,
    bool? applyDithering,
    int? pdfDpi,
    String? printerWidth,
  }) {
    return PrinterSettings(
      printDensity: printDensity ?? this.printDensity,
      copies: copies ?? this.copies,
      autoCut: autoCut ?? this.autoCut,
      applyDithering: applyDithering ?? this.applyDithering,
      pdfDpi: pdfDpi ?? this.pdfDpi,
      printerWidth: printerWidth ?? this.printerWidth,
    );
  }

  int get pixelWidth =>
      printerWidth == 'mm80' ? 576 : 384;

  Map<String, dynamic> toJson() => {
        'printDensity': printDensity,
        'copies': copies,
        'autoCut': autoCut,
        'applyDithering': applyDithering,
        'pdfDpi': pdfDpi,
        'printerWidth': printerWidth,
      };

  factory PrinterSettings.fromJson(Map<String, dynamic> json) =>
      PrinterSettings(
        printDensity: json['printDensity'] as int? ?? 3,
        copies: json['copies'] as int? ?? 1,
        autoCut: json['autoCut'] as bool? ?? true,
        applyDithering: json['applyDithering'] as bool? ?? true,
        pdfDpi: json['pdfDpi'] as int? ?? 203,
        printerWidth: json['printerWidth'] as String? ?? 'mm58',
      );
}
