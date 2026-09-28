import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Which transport the user wants the app to use.
enum TransportPreference {
  /// Try the on-device SDK first, fall back to a remembered Bluetooth printer.
  auto,

  /// Only the printer built into the device.
  sunmiSdk,

  /// Only a Bluetooth Classic printer, even if the device has an internal one.
  bluetoothClassic,
}

/// A Bluetooth Classic printer the user has paired with the app.
@immutable
class SavedPrinter {
  const SavedPrinter({
    required this.name,
    required this.address,
    required this.savedAt,
  });

  final String name;
  final String address;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'savedAt': savedAt.toIso8601String(),
  };

  factory SavedPrinter.fromJson(Map<String, dynamic> json) => SavedPrinter(
    name: json['name']?.toString() ?? 'Unknown',
    address: json['address']?.toString() ?? '',
    savedAt:
        DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );

  String encode() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      other is SavedPrinter && other.address == address;

  @override
  int get hashCode => address.hashCode;
}

/// The remembered printer choices, persisted so the app can reconnect without
/// re-running discovery on every launch.
@immutable
class PrinterProfile {
  const PrinterProfile({
    this.bluetoothPrinter,
    this.transportPreference = TransportPreference.auto,
  });

  final SavedPrinter? bluetoothPrinter;
  final TransportPreference transportPreference;

  bool get hasBluetoothPrinter => (bluetoothPrinter?.address ?? '').isNotEmpty;

  PrinterProfile copyWith({
    SavedPrinter? bluetoothPrinter,
    TransportPreference? transportPreference,
    bool clearBluetoothPrinter = false,
  }) {
    return PrinterProfile(
      bluetoothPrinter: clearBluetoothPrinter
          ? null
          : (bluetoothPrinter ?? this.bluetoothPrinter),
      transportPreference: transportPreference ?? this.transportPreference,
    );
  }

  Map<String, dynamic> toJson() => {
    'bluetoothPrinter': bluetoothPrinter?.toJson(),
    'transportPreference': transportPreference.name,
  };

  factory PrinterProfile.fromJson(Map<String, dynamic> json) {
    final rawPrinter = json['bluetoothPrinter'];
    return PrinterProfile(
      bluetoothPrinter: rawPrinter is Map
          ? SavedPrinter.fromJson(Map<String, dynamic>.from(rawPrinter))
          : null,
      transportPreference: TransportPreference.values.firstWhere(
        (value) => value.name == json['transportPreference'],
        orElse: () => TransportPreference.auto,
      ),
    );
  }

  String encode() => jsonEncode(toJson());

  static PrinterProfile decode(String raw) =>
      PrinterProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
