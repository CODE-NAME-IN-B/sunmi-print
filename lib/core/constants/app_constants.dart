class AppConstants {
  AppConstants._();

  static const String appName = 'SunmiPrint';
  static const String appVersion = '1.1.0';
  static const String githubUsername = 'CODE-NAME-IN-B';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubUsername/sunmi-print/releases/latest';
  static const String downloadBaseUrl =
      'https://github.com/$githubUsername/sunmi-print/releases/latest/download';
  static const String developerGitHubUrl = 'https://github.com/$githubUsername';
  static const String developerWebsiteUrl = 'https://mindeset.vercel.app/';
  static const String developerKofiUrl = 'https://ko-fi.com/codenameibn';

  /// Legacy dot widths, kept for migrations and for the ESC/POS defaults of
  /// the most common rolls (48mm of 58mm paper, 72mm of 80mm paper).
  static const int printWidth58mm = 384;
  static const int printWidth80mm = 576;

  static const int defaultPrintDensity = 3;
  static const int maxPrintDensity = 5;
  static const int minPrintDensity = 1;
  static const int maxRetryCount = 2;
  static const int pdfDefaultDpi = 203;
  static const int imageProcessingTimeoutMs = 2000;

  // ---------------------------------------------------------------------
  // Paper geometry (see PrinterSettings.pixelWidth for the full formula)
  // ---------------------------------------------------------------------

  /// Printable width of a 58mm roll. Real hardware leaves ~2mm of margin per
  /// side, so only 48mm is addressable by the printhead.
  static const int printableWidth58mm = 48;
  static const int printableWidth80mm = 72;
  static const int printableWidth100mm = 80;

  static const int minPaperWidthMm = 20;
  static const int maxPaperWidthMm = 120;
  static const int minPixelWidth = 80;
  static const int maxPixelWidth = 1280;

  /// Guards against unbounded canvases when a pathological custom width or
  /// DPI is entered (a 120mm roll at 300dpi is already ~1400 dots wide).
  static const int maxPrintHeightPx = 8000;

  static const List<int> supportedDpi = <int>[203, 300];

  // ---------------------------------------------------------------------
  // Bluetooth Classic transport tuning
  // ---------------------------------------------------------------------

  /// A first attempt plus two automatic retries. Cheap printers often keep
  /// their radio asleep and only answer the third RFCOMM channel open.
  static const int connectionRetryAttempts = 3;
  static const Duration connectionRetryDelay = Duration(milliseconds: 700);

  /// RFCOMM writes larger than this overflow the printer's small input buffer.
  static const int sppChunkSize = 512;

  /// Breathing room between chunks, equivalent to RawBT's "delay between
  /// packets" setting.
  static const Duration sppChunkDelay = Duration(milliseconds: 25);

  static const Duration sppCommandTimeout = Duration(seconds: 15);
  static const Duration printTimeout = Duration(seconds: 45);
  static const Duration sunmiStatusTimeout = Duration(seconds: 10);

  // ---------------------------------------------------------------------
  // Storage
  // ---------------------------------------------------------------------

  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxQueue = 'print_queue';
  static const String hiveBoxHistory = 'print_history';

  static const String hiveKeyPrinterSettings = 'printerSettings';
  static const String hiveKeyPrinterProfile = 'printerProfile';
  static const String hiveKeyQueue = 'queue';

  /// Guard rail for `file_picker` inputs before decoding.
  static const int maxFileSizeBytes = 20 * 1024 * 1024;
}
