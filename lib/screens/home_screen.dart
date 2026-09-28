import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../models/printer_settings.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/printer_service.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/printer_status_banner.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final printerStatus = ref.watch(printerStatusProvider).valueOrNull;
    final isConnected = printerStatus == PrinterConnectionStatus.connected;
    final settings = ref.watch(settingsProvider);
    final service = ref.watch(printerServiceProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A2E), Color(0xFF252540)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFF97316,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.print_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SunmiPrint',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'طباعة احترافية لطابعات Sunmi',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _ConnectionPill(isConnected: isConnected),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.queue_outlined, color: Colors.white),
                tooltip: 'طابور الطباعة',
                onPressed: () => Navigator.pushNamed(context, '/queue'),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
                tooltip: 'الإعدادات',
                onPressed: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(width: 4),
            ],
          ),
          const SliverToBoxAdapter(child: PrinterStatusBanner()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _PaperSummaryStrip(
                settings: settings,
                isConnected: isConnected,
                transportLabel: service.transportLabelAr,
                onTap: () =>
                    Navigator.pushNamed<void>(context, '/printer-settings'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              delegate: SliverChildListDelegate([
                _ActionCard(
                  icon: Icons.description_rounded,
                  label: 'طباعة ملف',
                  subtitle: 'PDF أو صورة',
                  color: AppTheme.primary,
                  isPrimary: true,
                  onTap: isConnected ? () => _pickAndPrint(context, ref) : null,
                ),
                _ActionCard(
                  icon: Icons.image_rounded,
                  label: 'طباعة صورة',
                  subtitle: 'PNG · JPG · BMP',
                  color: AppTheme.info,
                  onTap: isConnected ? () => _pickImage(context, ref) : null,
                ),
                _ActionCard(
                  icon: Icons.receipt_long_rounded,
                  label: 'إيصال جديد',
                  subtitle: 'محرر الإيصالات',
                  color: AppTheme.success,
                  onTap: isConnected
                      ? () => Navigator.pushNamed(context, '/receipt-editor')
                      : null,
                ),
                _ActionCard(
                  icon: Icons.bluetooth_rounded,
                  label: 'البحث عن طابعة',
                  subtitle: 'Bluetooth كلاسيكي',
                  color: Theme.of(context).colorScheme.secondary,
                  onTap: () => Navigator.pushNamed(context, '/bluetooth'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndPrint(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'bmp'],
    );
    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/preview', arguments: result.files.single);
    }
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/preview', arguments: result.files.single);
    }
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final bool isPrimary;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.isPrimary = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onTap == null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: isPrimary && !isDisabled ? 3 : 0,
      shadowColor: isPrimary ? color.withValues(alpha: 0.3) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(
          color: isDisabled
              ? theme.colorScheme.outline.withValues(alpha: 0.15)
              : color.withValues(alpha: isPrimary ? 0.3 : 0.2),
          width: 1,
        ),
      ),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: isPrimary && !isDisabled
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.06),
                      color.withValues(alpha: 0.02),
                    ],
                  )
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.05)
                      : color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isDisabled
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                ),
                child: Icon(
                  icon,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                      : Colors.white,
                  size: 26,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDisabled
                      ? theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.3,
                        )
                      : theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'الطابعة متصلة' : 'الطابعة غير متصلة',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the current paper geometry and the active transport in one tappable
/// row, so the print geometry is visible before every job instead of being
/// buried in settings.
class _PaperSummaryStrip extends StatelessWidget {
  const _PaperSummaryStrip({
    required this.settings,
    required this.isConnected,
    required this.transportLabel,
    required this.onTap,
  });

  final PrinterSettings settings;
  final bool isConnected;
  final String transportLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paper = settings.paperPreset == PaperPreset.custom
        ? '${settings.paperWidthMm} مم'
        : '${settings.paperPreset.rollWidthMm} مم';

    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Printer settings',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Icon(
                Icons.receipt_rounded,
                color: scheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$paper · ${settings.pixelWidth} بكسل',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${settings.printerDpi} dpi · كثافة ${settings.printDensity}/5 · ${isConnected ? transportLabel : 'غير متصلة'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
