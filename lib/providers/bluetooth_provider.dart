import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../core/constants/app_constants.dart';
import '../models/bluetooth_device_info.dart';
import '../services/printer_service.dart';

/// Where the discovery flow currently stands.
enum BluetoothScanStage {
  /// Nothing has happened yet.
  initial,

  /// Android 12+ runtime permissions are being resolved.
  checkingPermissions,

  /// At least one required permission is missing. The UI must explain this
  /// rather than showing an empty list, because a silent denial is the single
  /// most common reason discovery appears broken.
  permissionDenied,

  /// The radio is off.
  bluetoothOff,

  /// A scan is running.
  scanning,

  /// A scan finished and results are on screen.
  ready,

  /// A device is being connected.
  connecting,

  /// Something failed in a way the user has to resolve.
  error,
}

@immutable
class BluetoothScanState {
  const BluetoothScanState({
    this.stage = BluetoothScanStage.initial,
    this.devices = const <BluetoothDeviceInfo>[],
    this.pendingAddress,
    this.lastError,
    this.connectAttempts = 0,
    this.connectAttemptsTotal = 0,
    this.connectedAddress,
  });

  final BluetoothScanStage stage;
  final List<BluetoothDeviceInfo> devices;
  final String? pendingAddress;
  final String? lastError;

  /// How many of [connectAttemptsTotal] attempts have been spent.
  final int connectAttempts;
  final int connectAttemptsTotal;

  final String? connectedAddress;

  bool get isScanning => stage == BluetoothScanStage.scanning;
  bool get isConnecting => stage == BluetoothScanStage.connecting;
  bool get hasResults => devices.isNotEmpty;
  bool get hasBlockingProblem =>
      stage == BluetoothScanStage.permissionDenied ||
      stage == BluetoothScanStage.bluetoothOff ||
      stage == BluetoothScanStage.error;

  BluetoothScanState copyWith({
    BluetoothScanStage? stage,
    List<BluetoothDeviceInfo>? devices,
    String? pendingAddress,
    String? lastError,
    int? connectAttempts,
    int? connectAttemptsTotal,
    String? connectedAddress,
    bool clearError = false,
    bool clearPending = false,
  }) {
    return BluetoothScanState(
      stage: stage ?? this.stage,
      devices: devices ?? this.devices,
      pendingAddress: clearPending
          ? null
          : (pendingAddress ?? this.pendingAddress),
      lastError: clearError ? null : (lastError ?? this.lastError),
      connectAttempts: connectAttempts ?? this.connectAttempts,
      connectAttemptsTotal: connectAttemptsTotal ?? this.connectAttemptsTotal,
      connectedAddress: connectedAddress ?? this.connectedAddress,
    );
  }
}

/// Drives the classic Bluetooth discovery flow.
///
/// Discovery is a platform-channel affair rather than a package one, so the
/// EventChannel is owned here instead of inside a widget, which keeps the
/// device list alive across rebuilds and survives a rotation mid scan.
class BluetoothScanNotifier extends StateNotifier<BluetoothScanState> {
  BluetoothScanNotifier() : super(const BluetoothScanState()) {
    unawaited(refresh());
  }

  static const MethodChannel _method = MethodChannel(
    'com.sunmiprint.app/bluetooth',
  );
  static const EventChannel _events = EventChannel(
    'com.sunmiprint.app/bluetooth/events',
  );

  StreamSubscription<dynamic>? _eventSubscription;

  @override
  void dispose() {
    _eventSubscription?.cancel();
    unawaited(cancelScan());
    super.dispose();
  }

  /// Re-checks permissions and the radio, without starting a scan.
  Future<void> refresh() async {
    state = state.copyWith(
      stage: BluetoothScanStage.checkingPermissions,
      clearError: true,
    );

    if (!await ensurePermissions()) return;

    final enabled = await isBluetoothEnabled();
    state = state.copyWith(
      stage: enabled
          ? (state.devices.isEmpty
                ? BluetoothScanStage.initial
                : BluetoothScanStage.ready)
          : BluetoothScanStage.bluetoothOff,
    );
  }

  /// Requests every permission the platform needs for a classic scan.
  ///
  /// Android 12+ replaced the location requirement with `BLUETOOTH_SCAN` and
  /// `BLUETOOTH_CONNECT`. Older releases still gate discovery behind a location
  /// grant, so that one is only asked for where it still matters.
  /// Resolves every permission discovery needs on this Android version.
  ///
  /// The two Bluetooth permissions only exist from Android 12. Older releases
  /// gate the discovery broadcast behind a location permission instead, so
  /// asking only for the Bluetooth pair there would leave discovery silently
  /// empty. The location permission is capped at API 30 in the manifest, so
  /// nothing is asked for on a device that has no use for it.
  Future<bool> ensurePermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final required = <ph.Permission>[
        if (await _isAndroid12OrNewer()) ...<ph.Permission>[
          ph.Permission.bluetoothScan,
          ph.Permission.bluetoothConnect,
        ] else ...<ph.Permission>[ph.Permission.locationWhenInUse],
      ];

      final results = await required.request();
      final missing = results.entries
          .where((entry) => !entry.value.isGranted)
          .map((entry) => entry.key)
          .toList();

      if (missing.isNotEmpty) {
        state = state.copyWith(
          stage: BluetoothScanStage.permissionDenied,
          lastError: 'صلاحية البلوتوث مرفوضة — لا يمكن البحث عن الطابعات',
        );
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('BluetoothScan: permission request failed: $e');
      state = state.copyWith(
        stage: BluetoothScanStage.error,
        lastError: 'تعذر التحقق من الصلاحيات: $e',
      );
      return false;
    }
  }

  /// Android 12 introduced the `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`
  /// runtime permissions. Below that, discovery is gated on location.
  static Future<bool> _isAndroid12OrNewer() async {
    if (!Platform.isAndroid) return false;
    try {
      final sdk = await _method.invokeMethod<int>('getSdkInt');
      return (sdk ?? 0) >= 31;
    } catch (_) {
      // If the platform cannot answer, assume the modern model: requesting a
      // location permission nobody needs is worse than asking for a Bluetooth
      // permission that does not exist and being told no.
      return true;
    }
  }

  Future<bool> isBluetoothEnabled() async {
    try {
      return await _method.invokeMethod<bool>('isBluetoothEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks the system to turn the radio on. Android has no direct toggle, so
  /// this opens the adapter settings and lets the user flip it.
  Future<void> openBluetoothSettings() async {
    try {
      await _method.invokeMethod('openBluetoothSettings');
    } catch (_) {
      // Older adapters have no such intent; fall back to app settings.
      await ph.openAppSettings();
    }
  }

  /// Opens this app's system settings page, where the user can grant the
  /// Bluetooth permissions the app was denied.
  Future<bool> openAppSettings() => ph.openAppSettings();

  /// Runs a live scan, merging bonded devices with freshly discovered ones.
  Future<void> startScan() async {
    if (state.isScanning) return;

    state = state.copyWith(
      stage: BluetoothScanStage.checkingPermissions,
      clearError: true,
      clearPending: true,
    );
    if (!await ensurePermissions()) return;

    if (!await isBluetoothEnabled()) {
      state = state.copyWith(
        stage: BluetoothScanStage.bluetoothOff,
        lastError: 'البلوتوث غير مفعّل',
      );
      return;
    }

    state = state.copyWith(
      stage: BluetoothScanStage.scanning,
      devices: const <BluetoothDeviceInfo>[],
    );

    _eventSubscription?.cancel();
    _eventSubscription = _events.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object error) {
        debugPrint('BluetoothScan: event stream error: $error');
      },
    );

    try {
      await _method.invokeMethod('startDiscovery');
    } on PlatformException catch (e) {
      _applyPlatformError(e);
    } catch (e) {
      debugPrint('BluetoothScan: startDiscovery failed: $e');
      state = state.copyWith(
        stage: BluetoothScanStage.error,
        lastError: 'تعذر بدء البحث عن الأجهزة: $e',
      );
    }
  }

  Future<void> cancelScan() async {
    if (state.stage != BluetoothScanStage.scanning) return;
    try {
      await _method.invokeMethod('cancelDiscovery');
    } catch (_) {
      // The scan already ended on its own.
    }
    if (state.isScanning) {
      state = state.copyWith(
        stage: state.devices.isEmpty
            ? BluetoothScanStage.initial
            : BluetoothScanStage.ready,
      );
    }
  }

  void _onEvent(dynamic event) {
    if (!mounted) return;
    if (event is! Map) return;

    final name = event['event']?.toString();
    switch (name) {
      case 'paired':
        final list = (event['devices'] as List?) ?? const <dynamic>[];
        _merge(
          list.map(
            (e) => BluetoothDeviceInfo.fromMap(e as Map<dynamic, dynamic>),
          ),
        );
      case 'deviceFound':
        final device = event['device'];
        if (device is Map) {
          _merge(<BluetoothDeviceInfo>[BluetoothDeviceInfo.fromMap(device)]);
        }
      case 'discoveryFinished':
        if (state.isScanning) {
          state = state.copyWith(stage: BluetoothScanStage.ready);
        }
      case 'bondStateChanged':
        _updateBondState(
          event['address']?.toString(),
          event['bondState']?.toString(),
        );
    }
  }

  void _merge(Iterable<BluetoothDeviceInfo> incoming) {
    if (!mounted) return;
    final byAddress = <String, BluetoothDeviceInfo>{
      for (final device in state.devices) device.address: device,
    };
    var changed = false;
    for (final device in incoming) {
      if (device.address.isEmpty) continue;
      final existing = byAddress[device.address];
      if (existing == null) {
        byAddress[device.address] = device;
        changed = true;
      } else if (existing.isPaired != device.isPaired ||
          existing.name != device.name) {
        // A device we already listed as unpaired has now been bonded, or it
        // finally reported its name.
        byAddress[device.address] = device;
        changed = true;
      }
    }
    if (!changed) return;

    final updated = byAddress.values.toList()..sort(_compareDevices);
    state = state.copyWith(devices: updated);
  }

  void _updateBondState(String? address, String? bondState) {
    if (address == null || bondState == null || !mounted) return;
    final devices = state.devices
        .map(
          (device) => device.address == address
              ? BluetoothDeviceInfo(
                  name: device.name,
                  address: device.address,
                  type: device.type,
                  bondState: BluetoothDeviceInfo.fromMap(<String, String>{
                    'bondState': bondState,
                  }).bondState,
                  isPaired: bondState == 'bonded',
                )
              : device,
        )
        .toList(growable: false);
    state = state.copyWith(devices: devices);
  }

  /// Bonded and obviously named devices first, everything else alphabetically.
  static int _compareDevices(BluetoothDeviceInfo a, BluetoothDeviceInfo b) {
    if (a.isPaired != b.isPaired) return a.isPaired ? -1 : 1;
    if (a.hasRealName != b.hasRealName) return a.hasRealName ? -1 : 1;
    return a.name.compareTo(b.name);
  }

  void _applyPlatformError(PlatformException error) {
    final stage = switch (error.code) {
      'PERMISSION_DENIED' => BluetoothScanStage.permissionDenied,
      'BLUETOOTH_OFF' => BluetoothScanStage.bluetoothOff,
      'NO_BLUETOOTH' => BluetoothScanStage.error,
      _ => BluetoothScanStage.error,
    };
    final text = switch (error.code) {
      'PERMISSION_DENIED' => 'صلاحية البلوتوث مرفوضة',
      'BLUETOOTH_OFF' => 'البلوتوث غير مفعّل',
      'NO_BLUETOOTH' => 'هذا الجهاز لا يدعم البلوتوث',
      _ => 'خطأ في البلوتوث: ${error.message ?? error.code}',
    };
    state = state.copyWith(stage: stage, lastError: text);
  }

  /// Connects to [device], retrying up to
  /// [AppConstants.connectionRetryAttempts] times before giving up.
  Future<BluetoothConnectResult> connect(BluetoothDeviceInfo device) async {
    state = state.copyWith(
      stage: BluetoothScanStage.connecting,
      pendingAddress: device.address,
      clearError: true,
      connectAttempts: 0,
      connectAttemptsTotal: AppConstants.connectionRetryAttempts,
    );

    if (!device.supportsClassic) {
      const failure = BluetoothConnectResult.failure(
        BluetoothConnectError.unreachable,
        0,
      );
      state = state.copyWith(
        stage: BluetoothScanStage.ready,
        lastError: 'هذا الجهاز لا يدعم بلوتوث كلاسيكي (SPP)',
        clearPending: true,
      );
      return failure;
    }

    const total = AppConstants.connectionRetryAttempts;
    for (int attempt = 1; attempt <= total; attempt++) {
      if (!mounted) {
        return const BluetoothConnectResult.failure(
          BluetoothConnectError.unknown,
          0,
        );
      }
      state = state.copyWith(connectAttempts: attempt);

      final result = await PrinterService.instance.connectBluetooth(
        device.hasRealName ? device.name : device.address,
        device.address,
        attempts: 1,
      );
      if (result.success) {
        state = state.copyWith(
          stage: BluetoothScanStage.ready,
          connectedAddress: device.address,
          clearPending: true,
          clearError: true,
        );
        return result;
      }

      if (attempt < total) {
        await Future<void>.delayed(AppConstants.connectionRetryDelay * attempt);
      }
    }

    state = state.copyWith(
      stage: BluetoothScanStage.ready,
      lastError:
          'تعذر الاتصال بالطابعة بعد $total محاولات — تأكد أنها '
          'مقترنة بالجهاز وتشتغل',
      clearPending: true,
    );
    return const BluetoothConnectResult.failure(
      BluetoothConnectError.unreachable,
      0,
    );
  }

  Future<void> disconnect() async {
    await PrinterService.instance.disconnectBluetooth();
    state = state.copyWith(clearPending: true, connectedAddress: null);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final bluetoothScanProvider =
    StateNotifierProvider<BluetoothScanNotifier, BluetoothScanState>(
      (ref) => BluetoothScanNotifier(),
    );
