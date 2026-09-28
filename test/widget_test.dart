import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sunmi_print_app/app.dart';

void main() {
  late Directory hiveDir;

  // The vendor SDK talks over a method channel. Without a handler the call
  // never resolves in the test binding, which would leave every connection
  // future pending and make the async UI assertions time out.
  const sunmiChannel = MethodChannel('sunmi_printer_plus');
  const bluetoothChannel = MethodChannel('com.sunmiprint.app/bluetooth');

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('sunmiprint_hive');
    Hive.init(hiveDir.path);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sunmiChannel, (call) async {
          // Simulate a device with no internal printhead.
          if (call.method == 'bindingPrinter' ||
              call.method == 'rebindPrinter') {
            return false;
          }
          if (call.method == 'getStatus') return 5;
          if (call.method == 'getPaper') return 58;
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bluetoothChannel, (call) async {
          if (call.method == 'isBluetoothEnabled') return true;
          return null;
        });
  });

  tearDownAll(() async {
    await Hive.close();
    if (hiveDir.existsSync()) {
      hiveDir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SunmiPrintApp()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders the home screen with the printer offline', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('SunmiPrint'), findsWidgets);
    expect(find.text('الطابعة غير متصلة'), findsWidgets);

    await tester.scrollUntilVisible(find.text('إيصال جديد'), 200);
    expect(find.text('إيصال جديد'), findsOneWidget);
  });

  testWidgets('shows the current paper geometry on the home screen', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    // Default is the 58mm roll, which is 384 dots.
    expect(find.textContaining('384 بكسل'), findsWidgets);
  });

  testWidgets('navigates to settings and offers printer settings', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();

    expect(find.text('إعدادات الطابعة'), findsOneWidget);
    expect(find.text('البحث عن طابعة Bluetooth'), findsOneWidget);
  });

  testWidgets('reconnect row is reachable from settings', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('إعادة الاتصال'), 200);
    expect(find.text('إعادة الاتصال'), findsOneWidget);
    expect(find.text('محاولة إعادة الاتصال بالطابعة'), findsOneWidget);
  });

  testWidgets('print actions are disabled while the printer is offline', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.scrollUntilVisible(find.text('طباعة ملف'), 200);

    // The card must stay visible but inert while offline, which is what
    // `onTap: null` on the press wrapper expresses. Tapping it must not push
    // the preview route.
    final card = find
        .ancestor(of: find.text('طباعة ملف'), matching: find.byType(Card))
        .first;
    expect(card, findsOneWidget);

    await tester.tap(find.text('طباعة ملف'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('معاينة الطباعة'), findsNothing);
    expect(find.text('SunmiPrint'), findsWidgets);
  });
}
