class AppConstants {
  AppConstants._();

  static const String appName = 'SunmiPrint';
  static const String appVersion = '1.0.9';
  static const String githubUsername = 'CODE-NAME-IN-B';
  static const String githubReleasesUrl =
      'https://api.github.com/repos/$githubUsername/sunmi-print/releases/latest';
  static const String downloadBaseUrl =
      'https://github.com/$githubUsername/sunmi-print/releases/latest/download';
  static const String developerGitHubUrl = 'https://github.com/$githubUsername';
  static const String developerWebsiteUrl = 'https://mindeset.vercel.app/';
  static const String developerKofiUrl = 'https://ko-fi.com/codenameibn';

  static const int printWidth58mm = 384;
  static const int printWidth80mm = 576;
  static const int defaultPrintDensity = 3;
  static const int maxPrintDensity = 5;
  static const int minPrintDensity = 1;
  static const int maxRetryCount = 2;
  static const int pdfDefaultDpi = 203;
  static const int imageProcessingTimeoutMs = 2000;

  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxQueue = 'print_queue';
  static const String hiveBoxHistory = 'print_history';
}
