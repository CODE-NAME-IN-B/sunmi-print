import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sunmi_print_app/core/constants/app_constants.dart';
import 'package:sunmi_print_app/models/printer_profile.dart';
import 'package:sunmi_print_app/models/receipt_document.dart';
import 'package:sunmi_print_app/models/printer_settings.dart';
import 'package:sunmi_print_app/services/printer_service.dart';

/// The service is a singleton, so these tests drive it through one instance and
/// assert on observable state rather than on call ordering.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sunmi = MethodChannel('sunmi_printer_plus');
  const bluetooth = MethodChannel('com.sunmiprint.app/bluetooth');

  late Directory hiveDir;
  late List<String> sunmiCalls;

  Future<void> useHive() async {
    hiveDir = await Directory.systemTemp.createTemp('sunmiprint_service');
    Hive.init(hiveDir.path);
    await Hive.deleteFromDisk();
  }

  /// The vendor plugin reports status and paper width as human readable
  /// strings, not enums, so the mock mirrors that shape rather than inventing a
  /// tidier one the real service would never see.
  void mockSunmi({
    required bool available,
    String status = 'Ready',
    String paper = '58mm',
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sunmi, (call) async {
          sunmiCalls.add(call.method);
          switch (call.method) {
            case 'rebindPrinter':
              return available;
            case 'getStatus':
              return status;
            case 'getPaper':
              return paper;
            case 'printImage':
            case 'printEscPos':
            case 'printText':
            case 'printQrcode':
            case 'printBarcode':
            case 'lineWrap':
            case 'cutPaper':
              return 'ok';
            default:
              return null;
          }
        });
  }

  setUp(() {
    sunmiCalls = <String>[];
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sunmi, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bluetooth, null);
    sunmiCalls.clear();
  });

  testWidgets('prefers the on-device SDK when it binds', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: true, paper: '58mm');
      final service = PrinterService.instance;
      await service.setTransportPreference(TransportPreference.auto);

      final transport = await service.initialize();

      expect(transport, PrinterTransport.sunmiSdk);
      expect(service.isConnected, isTrue);
      expect(service.transportLabelAr, isNotEmpty);
      // The vendor SDK must be the first thing tried, every time.
      expect(sunmiCalls, contains('rebindPrinter'));
    });
  });

  testWidgets('reports the vendor paper width so the UI can preselect a roll', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: true, paper: '80mm');
      final service = PrinterService.instance;

      await service.initialize();
      // The vendor reports the roll; the service returns the printable width
      // because that is what the dot maths needs.
      final width = await service.detectSunmiPaperWidthMm();

      expect(width, AppConstants.printableWidth80mm);
      expect(width, 72);
    });
  });

  testWidgets('maps a missing SDK onto no transport', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: false);
      final service = PrinterService.instance;
      await service.forgetBluetoothPrinter();
      await service.setTransportPreference(TransportPreference.auto);

      final transport = await service.initialize();

      expect(transport, PrinterTransport.none);
      expect(service.isConnected, isFalse);
      expect(service.status, PrinterConnectionStatus.disconnected);
    });
  });

  testWidgets('pinned to the SDK does not fall back to Bluetooth', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: false);
      final service = PrinterService.instance;
      await service.setTransportPreference(TransportPreference.sunmiSdk);

      final transport = await service.initialize();

      expect(transport, PrinterTransport.none);
    });
  });

  testWidgets('a no-paper SDK status is surfaced, not swallowed', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      // 3 is NOPAPER in the vendor status map.
      mockSunmi(available: true, status: 'NOPAPER');
      final service = PrinterService.instance;

      await service.initialize();

      expect(service.status, PrinterConnectionStatus.noPaper);
    });
  });

  testWidgets('a valid raster prints over the SDK', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: true);
      final service = PrinterService.instance;
      await service.initialize();

      const settings = PrinterSettings();
      const document = ReceiptDocument(
        header: 'SunmiPrint',
        lines: <ReceiptLine>[ReceiptLine.text('اختبار')],
      );

      final printed = await service.printReceipt(document, settings: settings);

      expect(printed, isTrue);
      // Text must reach the head as a raster, never as characters. `printImage`
      // is the only path that carries a page, and `printText` must not appear.
      expect(sunmiCalls, contains('printImage'));
      expect(sunmiCalls, isNot(contains('printText')));
    });
  });

  testWidgets('a QR code is sent as a printer symbol, not as dots', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: true);
      final service = PrinterService.instance;
      await service.initialize();

      final printed = await service.printQRCode('SUNMIPRINT-TEST');

      expect(printed, isTrue);
      expect(sunmiCalls, contains('printQrcode'));
    });
  });

  testWidgets('printing is refused while disconnected', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      mockSunmi(available: false);
      final service = PrinterService.instance;
      await service.setTransportPreference(TransportPreference.sunmiSdk);
      await service.initialize();
      sunmiCalls.clear();

      final printed = await service.printTestPage(
        settings: const PrinterSettings(),
      );

      expect(printed, isFalse);
      // Nothing should have been sent to a head that is not there.
      expect(sunmiCalls, isEmpty);
    });
  });

  testWidgets('the saved printer profile survives a reload', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      final service = PrinterService.instance;

      await service.setBluetoothPrinter('SUNMI-V80', 'AA:BB:CC:DD:EE:FF');
      await service.setTransportPreference(
        TransportPreference.bluetoothClassic,
      );

      final reloaded = PrinterProfile.decode(
        (await Hive.openBox<String>(
          AppConstants.hiveBoxSettings,
        )).get(AppConstants.hiveKeyPrinterProfile)!,
      );

      expect(reloaded.bluetoothPrinter?.name, 'SUNMI-V80');
      expect(reloaded.bluetoothPrinter?.address, 'AA:BB:CC:DD:EE:FF');
      expect(
        reloaded.transportPreference,
        TransportPreference.bluetoothClassic,
      );
    });
  });

  testWidgets('forgetting a printer clears the saved entry', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(() async {
      await useHive();
      final service = PrinterService.instance;
      await service.setBluetoothPrinter('SUNMI-V80', 'AA:BB:CC:DD:EE:FF');

      await service.forgetBluetoothPrinter();

      final reloaded = PrinterProfile.decode(
        (await Hive.openBox<String>(
          AppConstants.hiveBoxSettings,
        )).get(AppConstants.hiveKeyPrinterProfile)!,
      );
      expect(reloaded.hasBluetoothPrinter, isFalse);
    });
  });
}
