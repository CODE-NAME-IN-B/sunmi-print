// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'SunmiPrint';

  @override
  String get printFile => 'طباعة ملف';

  @override
  String get printImage => 'طباعة صورة';

  @override
  String get newReceipt => 'إيصال جديد';

  @override
  String get printQueue => 'طابور الطباعة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get history => 'السجل';

  @override
  String get preview => 'معاينة';

  @override
  String get print => 'طباعة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة محاولة';

  @override
  String get delete => 'حذف';

  @override
  String get printerDisconnected => 'الطابعة غير متصلة';

  @override
  String get noPaper => 'نفاد الورق - يرجى إضافة ورق';

  @override
  String get printerOverheat => 'الطابعة ساخنة جداً - انتظر قليلاً';

  @override
  String get printerError => 'خطأ في الطابعة - تحقق من الاتصال';

  @override
  String get addToQueue => 'تمت إضافة المهمة إلى طابور الطباعة';

  @override
  String get printSuccess => 'تمت الطباعة بنجاح';

  @override
  String get printFailed => 'فشلت الطباعة';

  @override
  String get dithering => 'تطبيق Floyd-Steinberg Dithering';

  @override
  String get ditheringSubtitle => 'يحسن جودة الشعارات والصور';

  @override
  String get autoCut => 'قص تلقائي بعد الطباعة';

  @override
  String get copies => 'عدد النسخ';

  @override
  String get printerWidth => 'عرض الطابعة';

  @override
  String get width58 => '58 مم';

  @override
  String get width80 => '80 مم';

  @override
  String get pdfDpi => 'دقة رندرة PDF';

  @override
  String get density => 'كثافة الطباعة';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'غامق';

  @override
  String get reconnect => 'إعادة الاتصال بالطابعة';

  @override
  String get noJobs => 'لا توجد مهام في الطابور';

  @override
  String get clearCompleted => 'مسح المهام المنتهية';

  @override
  String get noHistory => 'لا يوجد سجل طباعة بعد';

  @override
  String get storeName => 'اسم المتجر';

  @override
  String get receiptBody => 'نص الإيصال';

  @override
  String get footer => 'تذييل';

  @override
  String get includeLogo => 'إضافة شعار';

  @override
  String get includeQR => 'إضافة QR Code';

  @override
  String get printReceipt => 'طباعة الإيصال';

  @override
  String pageOf(Object current, Object total) {
    return 'صفحة $current من $total';
  }

  @override
  String get errorProcessing => 'فشل معالجة الملف';

  @override
  String errorPrinting(Object error) {
    return 'فشلت الطباعة: $error';
  }

  @override
  String get retryPrint => 'إعادة الطباعة';
}
