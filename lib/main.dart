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
    await _requestStoragePermissions();
  }

  await PrintQueueService.instance.initialize();

  if (!Platform.isAndroid) {
    PrinterService.instance.simulateConnected();
  } else {
    PrinterService.instance.initialize();
  }

  runApp(
    const ProviderScope(
      child: SunmiPrintApp(),
    ),
  );
}

Future<void> _requestStoragePermissions() async {
  final permissions = <Permission>[
    Permission.storage,
    Permission.photos,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ];

  await permissions.request();
}
