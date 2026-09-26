import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'SunmiPrint'**
  String get appTitle;

  /// No description provided for @printFile.
  ///
  /// In en, this message translates to:
  /// **'Print File'**
  String get printFile;

  /// No description provided for @printImage.
  ///
  /// In en, this message translates to:
  /// **'Print Image'**
  String get printImage;

  /// No description provided for @newReceipt.
  ///
  /// In en, this message translates to:
  /// **'New Receipt'**
  String get newReceipt;

  /// No description provided for @printQueue.
  ///
  /// In en, this message translates to:
  /// **'Print Queue'**
  String get printQueue;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @print.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get print;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @printerDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Printer not connected'**
  String get printerDisconnected;

  /// No description provided for @noPaper.
  ///
  /// In en, this message translates to:
  /// **'Out of paper - please add paper'**
  String get noPaper;

  /// No description provided for @printerOverheat.
  ///
  /// In en, this message translates to:
  /// **'Printer is overheating - please wait'**
  String get printerOverheat;

  /// No description provided for @printerError.
  ///
  /// In en, this message translates to:
  /// **'Printer error - check connection'**
  String get printerError;

  /// No description provided for @addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added to print queue'**
  String get addToQueue;

  /// No description provided for @printSuccess.
  ///
  /// In en, this message translates to:
  /// **'Printed successfully'**
  String get printSuccess;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed'**
  String get printFailed;

  /// No description provided for @dithering.
  ///
  /// In en, this message translates to:
  /// **'Floyd-Steinberg Dithering'**
  String get dithering;

  /// No description provided for @ditheringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Improves logo and image quality'**
  String get ditheringSubtitle;

  /// No description provided for @autoCut.
  ///
  /// In en, this message translates to:
  /// **'Auto cut after printing'**
  String get autoCut;

  /// No description provided for @copies.
  ///
  /// In en, this message translates to:
  /// **'Copies'**
  String get copies;

  /// No description provided for @printerWidth.
  ///
  /// In en, this message translates to:
  /// **'Printer Width'**
  String get printerWidth;

  /// No description provided for @width58.
  ///
  /// In en, this message translates to:
  /// **'58 mm'**
  String get width58;

  /// No description provided for @width80.
  ///
  /// In en, this message translates to:
  /// **'80 mm'**
  String get width80;

  /// No description provided for @pdfDpi.
  ///
  /// In en, this message translates to:
  /// **'PDF Render DPI'**
  String get pdfDpi;

  /// No description provided for @density.
  ///
  /// In en, this message translates to:
  /// **'Print Density'**
  String get density;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect to printer'**
  String get reconnect;

  /// No description provided for @noJobs.
  ///
  /// In en, this message translates to:
  /// **'No print jobs'**
  String get noJobs;

  /// No description provided for @clearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompleted;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No print history yet'**
  String get noHistory;

  /// No description provided for @storeName.
  ///
  /// In en, this message translates to:
  /// **'Store Name'**
  String get storeName;

  /// No description provided for @receiptBody.
  ///
  /// In en, this message translates to:
  /// **'Receipt Body'**
  String get receiptBody;

  /// No description provided for @footer.
  ///
  /// In en, this message translates to:
  /// **'Footer'**
  String get footer;

  /// No description provided for @includeLogo.
  ///
  /// In en, this message translates to:
  /// **'Include Logo'**
  String get includeLogo;

  /// No description provided for @includeQR.
  ///
  /// In en, this message translates to:
  /// **'Include QR Code'**
  String get includeQR;

  /// No description provided for @printReceipt.
  ///
  /// In en, this message translates to:
  /// **'Print Receipt'**
  String get printReceipt;

  /// No description provided for @pageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageOf(Object current, Object total);

  /// No description provided for @errorProcessing.
  ///
  /// In en, this message translates to:
  /// **'Failed to process file'**
  String get errorProcessing;

  /// No description provided for @errorPrinting.
  ///
  /// In en, this message translates to:
  /// **'Print failed: {error}'**
  String errorPrinting(Object error);

  /// No description provided for @retryPrint.
  ///
  /// In en, this message translates to:
  /// **'Retry Print'**
  String get retryPrint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
