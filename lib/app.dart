import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/print_queue_screen.dart';
import 'screens/print_history_screen.dart';
import 'screens/receipt_editor_screen.dart';
import 'screens/bluetooth_discovery_screen.dart';
import 'screens/about_screen.dart';
import 'screens/preview_screen.dart';

class SunmiPrintApp extends StatelessWidget {
  const SunmiPrintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SunmiPrint',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          case '/queue':
            return MaterialPageRoute(builder: (_) => const PrintQueueScreen());
          case '/receipt-editor':
            return MaterialPageRoute(builder: (_) => const ReceiptEditorScreen());
          case '/history':
            return MaterialPageRoute(builder: (_) => const HistoryScreen());
          case '/bluetooth':
            return MaterialPageRoute(builder: (_) => const BluetoothDiscoveryScreen());
          case '/about':
            return MaterialPageRoute(builder: (_) => const AboutScreen());
          case '/preview':
            return MaterialPageRoute(builder: (_) => const PreviewScreen(), settings: settings);
          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
