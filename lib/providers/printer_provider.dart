import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/printer_profile.dart';
import '../services/printer_service.dart';

final printerServiceProvider = Provider<PrinterService>((ref) {
  return PrinterService.instance;
});

/// Live connection state of whichever transport is active.
final printerStatusProvider = StreamProvider<PrinterConnectionStatus>((ref) {
  return ref.watch(printerServiceProvider).statusStream;
});

/// Which transport won the startup race: on-device SDK or Bluetooth Classic.
final printerTransportProvider = StreamProvider<PrinterTransport>((ref) {
  return ref.watch(printerServiceProvider).transportStream;
});

/// The remembered printer choices: which Bluetooth printer was last used and
/// whether the user pinned the app to a specific transport.
final printerProfileProvider = StreamProvider<PrinterProfile>((ref) {
  return ref.watch(printerServiceProvider).profileStream;
});
