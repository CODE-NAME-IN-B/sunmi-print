import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../core/constants/app_constants.dart';
import '../models/printer_settings.dart';

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, PrinterSettings>((ref) {
      return SettingsNotifier();
    });

class SettingsNotifier extends StateNotifier<PrinterSettings> {
  Box<String>? _box;
  bool _isLoaded = false;

  SettingsNotifier() : super(const PrinterSettings()) {
    _load();
  }

  bool get isLoaded => _isLoaded;

  Future<Box<String>> get _store async {
    _box ??= await Hive.openBox<String>(AppConstants.hiveBoxSettings);
    return _box!;
  }

  Future<void> _load() async {
    try {
      final box = await _store;
      final saved = box.get('printerSettings');
      if (saved != null) {
        state = PrinterSettings.fromJson(
          jsonDecode(saved) as Map<String, dynamic>,
        );
      }
      _isLoaded = true;
    } catch (e) {
      debugPrint('SettingsNotifier: Failed to load settings: $e');
      _isLoaded = true;
    }
  }

  Future<void> _save() async {
    try {
      final box = await _store;
      await box.put('printerSettings', jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('SettingsNotifier: Failed to save settings: $e');
    }
  }

  void updateSettings(PrinterSettings settings) {
    state = settings;
    _save();
  }
}
