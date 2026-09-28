import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app.dart';
import 'services/printer_service.dart';
import 'services/print_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (Platform.isAndroid) {
    await _requestLegacyStorage();
  }

  await PrintQueueService.instance.initialize();

  // Desktop and CI runs have no printhead, so the app starts in a simulated
  // connected state. That keeps the print flow exercisable in a desktop build
  // without pretending a real transport exists.
  if (Platform.isAndroid) {
    // Fire and forget: every intermediate state is rendered by the UI, so
    // blocking the first frame on a binder call would only delay launch.
    unawaited(_initPrinter());
  } else {
    PrinterService.instance.simulateConnected();
  }

  runApp(const ProviderScope(child: SunmiPrintApp()));
}

Future<void> _initPrinter() async {
  try {
    await PrinterService.instance.initialize();
  } catch (e) {
    debugPrint('main: printer initialisation failed: $e');
  }
}

/// Bluetooth permissions are requested by the discovery screen, at the moment
/// they are needed, because a permission dialog on first launch before the user
/// has seen what the app does is the fastest way to get a permanent denial.
///
/// Only file access is requested up front: without it, a file picked on an old
/// release cannot be read back.
Future<void> _requestLegacyStorage() async {
  try {
    if (!Platform.isAndroid) return;
    final status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) return;
    await Permission.storage.request();
  } catch (e) {
    debugPrint('main: storage permission request failed: $e');
  }
}
