// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SunmiPrint';

  @override
  String get printFile => 'Print File';

  @override
  String get printImage => 'Print Image';

  @override
  String get newReceipt => 'New Receipt';

  @override
  String get printQueue => 'Print Queue';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'History';

  @override
  String get preview => 'Preview';

  @override
  String get print => 'Print';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get printerDisconnected => 'Printer not connected';

  @override
  String get noPaper => 'Out of paper - please add paper';

  @override
  String get printerOverheat => 'Printer is overheating - please wait';

  @override
  String get printerError => 'Printer error - check connection';

  @override
  String get addToQueue => 'Added to print queue';

  @override
  String get printSuccess => 'Printed successfully';

  @override
  String get printFailed => 'Print failed';

  @override
  String get dithering => 'Floyd-Steinberg Dithering';

  @override
  String get ditheringSubtitle => 'Improves logo and image quality';

  @override
  String get autoCut => 'Auto cut after printing';

  @override
  String get copies => 'Copies';

  @override
  String get printerWidth => 'Printer Width';

  @override
  String get width58 => '58 mm';

  @override
  String get width80 => '80 mm';

  @override
  String get pdfDpi => 'PDF Render DPI';

  @override
  String get density => 'Print Density';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get reconnect => 'Reconnect to printer';

  @override
  String get noJobs => 'No print jobs';

  @override
  String get clearCompleted => 'Clear completed';

  @override
  String get noHistory => 'No print history yet';

  @override
  String get storeName => 'Store Name';

  @override
  String get receiptBody => 'Receipt Body';

  @override
  String get footer => 'Footer';

  @override
  String get includeLogo => 'Include Logo';

  @override
  String get includeQR => 'Include QR Code';

  @override
  String get printReceipt => 'Print Receipt';

  @override
  String pageOf(Object current, Object total) {
    return 'Page $current of $total';
  }

  @override
  String get errorProcessing => 'Failed to process file';

  @override
  String errorPrinting(Object error) {
    return 'Print failed: $error';
  }

  @override
  String get retryPrint => 'Retry Print';
}
