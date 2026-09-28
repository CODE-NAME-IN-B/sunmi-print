import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../models/bluetooth_device_info.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/printer_provider.dart';
import '../services/printer_service.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/skeleton.dart';

/// Finds a Bluetooth Classic printer and connects to it.
///
/// The screen is built around the three states that actually block the user,
/// permissions, radio off, and nothing found, each of which gets an explicit
/// recovery action. Everything else is a list.
class BluetoothDiscoveryScreen extends ConsumerStatefulWidget {
  const BluetoothDiscoveryScreen({super.key});

  @override
  ConsumerState<BluetoothDiscoveryScreen> createState() =>
      _BluetoothDiscoveryScreenState();
}

class _BluetoothDiscoveryScreenState
    extends ConsumerState<BluetoothDiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    // Ask for permissions up front, then scan. Both are cheap and the user
    // almost always wants both.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(bluetoothScanProvider.notifier);
      if (await notifier.ensurePermissions()) {
        await notifier.startScan();
      }
    });
  }

  Future<void> _retry() async {
    final notifier = ref.read(bluetoothScanProvider.notifier);
    notifier.clearError();
    if (await notifier.ensurePermissions()) {
      await notifier.startScan();
    }
  }

  Future<void> _connect(BluetoothDeviceInfo device) async {
    HapticFeedback.selectionClick();
    final result = await ref
        .read(bluetoothScanProvider.notifier)
        .connect(device);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      final transport = ref.read(printerServiceProvider).transport;
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'تم الاتصال بـ ${device.name} عبر ${transport == PrinterTransport.sunmiSdk ? 'الطابعة المدمجة' : 'بلوتوث كلاسيكي'}',
          ),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 3),
        ),
      );
      await Navigator.of(context).maybePop();
    } else {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل الاتصال: ${result.messageAr}'),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _connect(device),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bluetoothScanProvider);
    final notifier = ref.read(bluetoothScanProvider.notifier);
    final isConnected =
        ref.watch(printerStatusProvider).valueOrNull ==
        PrinterConnectionStatus.connected;
    final connectedAddress = isConnected
        ? PrinterService.instance.deviceAddress
        : state.connectedAddress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث عن طابعة'),
        actions: <Widget>[
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: state.isScanning
                ? IconButton(
                    key: const ValueKey<String>('cancel'),
                    icon: const Icon(Icons.stop_rounded),
                    tooltip: 'إيقاف البحث',
                    onPressed: notifier.cancelScan,
                  )
                : IconButton(
                    key: const ValueKey<String>('scan'),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'بحث جديد',
                    onPressed: _retry,
                  ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (state.hasBlockingProblem)
            _BlockingNotice(
              state: state,
              onRetry: _retry,
              onAction: () async {
                if (state.stage == BluetoothScanStage.permissionDenied) {
                  await notifier.openAppSettings();
                } else if (state.stage == BluetoothScanStage.bluetoothOff) {
                  await notifier.openBluetoothSettings();
                } else {
                  await _retry();
                }
              },
            ),
          if (state.isScanning) _ScanProgress(state: state),
          Expanded(child: _buildBody(context, state, connectedAddress)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    BluetoothScanState state,
    String? connectedAddress,
  ) {
    if (state.stage == BluetoothScanStage.initial ||
        state.stage == BluetoothScanStage.checkingPermissions) {
      return const SkeletonDeviceList();
    }

    if (state.devices.isEmpty) {
      return _EmptyState(
        scanning: state.isScanning,
        blocked: state.hasBlockingProblem,
        onScan: _retry,
      );
    }

    return RefreshIndicator(
      onRefresh: _retry,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: state.devices.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _DeviceCountHeader(
              count: state.devices.length,
              scanning: state.isScanning,
            );
          }
          final device = state.devices[index - 1];
          return _DeviceTile(
            device: device,
            isConnected: device.address == connectedAddress,
            isConnecting:
                state.isConnecting && state.pendingAddress == device.address,
            connectProgress:
                state.connectAttemptsTotal > 0 &&
                    state.pendingAddress == device.address
                ? state.connectAttempts
                : 0,
            onTap: state.isConnecting || state.isScanning
                ? null
                : () => _connect(device),
          );
        },
      ),
    );
  }
}

class _BlockingNotice extends StatelessWidget {
  const _BlockingNotice({
    required this.state,
    required this.onRetry,
    required this.onAction,
  });

  final BluetoothScanState state;
  final Future<void> Function() onRetry;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, title, action) = switch (state.stage) {
      BluetoothScanStage.permissionDenied => (
        Icons.lock_person_rounded,
        'صلاحية البلوتوث مرفوضة',
        'فتح الإعدادات',
      ),
      BluetoothScanStage.bluetoothOff => (
        Icons.bluetooth_disabled_rounded,
        'البلوتوث غير مفعّل',
        'تفعيل البلوتوث',
      ),
      _ => (
        Icons.error_outline_rounded,
        'تعذّر البحث عن الأجهزة',
        'إعادة المحاولة',
      ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: scheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppTheme.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (state.lastError != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    state.lastError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress({required this.state});

  final BluetoothScanState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'جارٍ البحث عن الأجهزة القريبة…',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DeviceCountHeader extends StatelessWidget {
  const _DeviceCountHeader({required this.count, required this.scanning});

  final int count;
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Row(
        children: <Widget>[
          Text(
            'الأجهزة ($count)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (scanning)
            Text(
              'يتم التحديث تلقائياً',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.isConnecting,
    required this.connectProgress,
    required this.onTap,
  });

  final BluetoothDeviceInfo device;
  final bool isConnected;
  final bool isConnecting;
  final int connectProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null;

    final (icon, tint) = isConnected
        ? (Icons.print_rounded, AppTheme.success)
        : device.supportsClassic
        ? (Icons.bluetooth_rounded, scheme.primary)
        : (Icons.bluetooth_audio_rounded, scheme.onSurfaceVariant);

    return PressableScale(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: 'Connect to ${device.name}',
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.curve,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isConnected
              ? AppTheme.success.withValues(alpha: 0.06)
              : scheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: isConnected ? AppTheme.success : scheme.outlineVariant,
            width: isConnected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(icon, color: tint, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    device.hasRealName ? device.name : 'جهاز غير مسمى',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(
                        device.address,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (device.isPaired) ...<Widget>[
                        const SizedBox(width: 6),
                        const _Tag(label: 'مقترنة', color: AppTheme.success),
                      ] else if (!device.supportsClassic) ...<Widget>[
                        const SizedBox(width: 6),
                        const _Tag(
                          label: 'Bluetooth LE',
                          color: AppTheme.warning,
                        ),
                      ],
                    ],
                  ),
                  if (isConnecting && connectProgress > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: LinearProgressIndicator(
                            value: connectProgress == 0
                                ? null
                                : connectProgress / 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'محاولة $connectProgress/3',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isConnected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.success,
                size: 26,
              )
            else if (isConnecting)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_left_rounded,
                color: enabled ? scheme.primary : scheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.scanning,
    required this.blocked,
    required this.onScan,
  });

  final bool scanning;
  final bool blocked;
  final Future<void> Function() onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                scanning
                    ? Icons.bluetooth_searching_rounded
                    : Icons.print_disabled_rounded,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              scanning ? 'جارٍ البحث…' : 'لم يتم العثور على أجهزة',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              blocked
                  ? 'عالج المشكلة أعلاه ثم أعد المحاولة.'
                  : 'شغّل الطابعة، اجعلها قريبة، ثم ابدأ البحث مرة أخرى.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!scanning)
              FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('بدء البحث'),
              ),
          ],
        ),
      ),
    );
  }
}
