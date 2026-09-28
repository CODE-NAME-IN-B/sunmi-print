import 'package:flutter/foundation.dart';

/// Transport class reported by the Android Bluetooth stack.
enum BluetoothDeviceType { classic, lowEnergy, dual, unknown }

/// Bond state of a remote device.
enum BluetoothBondState { none, bonding, bonded, unknown }

/// One remote Bluetooth device as seen by discovery.
///
/// The classic thermal printers this app targets advertise over SPP, so
/// [type] is surfaced in the UI to make it obvious when a listed device is a
/// low energy peripheral that cannot receive ESC/POS at all.
@immutable
class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.type = BluetoothDeviceType.unknown,
    this.bondState = BluetoothBondState.none,
    this.isPaired = false,
  });

  final String name;
  final String address;
  final BluetoothDeviceType type;
  final BluetoothBondState bondState;
  final bool isPaired;

  /// Names that never identify a device to a user.
  bool get hasRealName => name.trim().isNotEmpty && name != 'Unknown';

  /// Devices that cannot open an RFCOMM socket.
  bool get supportsClassic {
    if (isPaired) return true;
    return switch (type) {
      BluetoothDeviceType.classic => true,
      BluetoothDeviceType.dual => true,
      BluetoothDeviceType.lowEnergy => false,
      BluetoothDeviceType.unknown => true,
    };
  }

  factory BluetoothDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return BluetoothDeviceInfo(
      name: map['name']?.toString() ?? 'Unknown',
      address: map['address']?.toString() ?? '',
      type: _parseType(map['type']),
      bondState: _parseBondState(map['bondState']),
      isPaired: map['isPaired'] == true,
    );
  }

  static BluetoothDeviceType _parseType(Object? raw) {
    return switch (raw?.toString()) {
      'classic' => BluetoothDeviceType.classic,
      'ble' => BluetoothDeviceType.lowEnergy,
      'dual' => BluetoothDeviceType.dual,
      _ => BluetoothDeviceType.unknown,
    };
  }

  static BluetoothBondState _parseBondState(Object? raw) {
    return switch (raw?.toString()) {
      'bonded' => BluetoothBondState.bonded,
      'bonding' => BluetoothBondState.bonding,
      'none' => BluetoothBondState.none,
      _ => BluetoothBondState.unknown,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is BluetoothDeviceInfo && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'BluetoothDeviceInfo($name, $address)';
}
