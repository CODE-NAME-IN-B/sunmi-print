import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../models/printer_settings.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/printer_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),

          // --- قسم الطباعة ---
          const _SectionHeader(title: 'الطباعة'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Floyd-Steinberg Dithering'),
                  subtitle: const Text('يحسن جودة الصور عند الطباعة'),
                  value: settings.applyDithering,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .updateSettings(settings.copyWith(applyDithering: v)),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('قص تلقائي'),
                  subtitle: const Text('قص الورق بعد كل طباعة'),
                  value: settings.autoCut,
                  onChanged: (v) => ref
                      .read(settingsProvider.notifier)
                      .updateSettings(settings.copyWith(autoCut: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم النسخ ---
          const _SectionHeader(title: 'عدد النسخ'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('عدد النسخ')),
                  _CopyButton(
                    icon: Icons.remove_circle_outline,
                    onPressed: settings.copies > 1
                        ? () => ref
                              .read(settingsProvider.notifier)
                              .updateSettings(
                                settings.copyWith(copies: settings.copies - 1),
                              )
                        : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF97316).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${settings.copies}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CopyButton(
                    icon: Icons.add_circle_outline,
                    onPressed: settings.copies < 99
                        ? () => ref
                              .read(settingsProvider.notifier)
                              .updateSettings(
                                settings.copyWith(copies: settings.copies + 1),
                              )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم الطابعة ---
          const _SectionHeader(title: 'الطابعة'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('إعدادات الطابعة'),
                  subtitle: Text(
                    '${settings.paperPreset.rollWidthMm} مم · ${settings.pixelWidth} بكسل · ${settings.printDensity}/5',
                  ),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () =>
                      Navigator.pushNamed(context, '/printer-settings'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Icon(
                      Icons.bluetooth_searching_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('البحث عن طابعة Bluetooth'),
                  subtitle: const Text('اكتشاف الطابعات القريبة وربطها'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () => Navigator.pushNamed(context, '/bluetooth'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  title: const Text('إعادة الاتصال'),
                  subtitle: const Text('محاولة إعادة الاتصال بالطابعة'),
                  trailing: const Icon(Icons.chevron_left_rounded),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final transport = await ref
                        .read(printerServiceProvider)
                        .initialize();
                    final connected = transport != PrinterTransport.none;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          connected
                              ? 'متصل عبر ${ref.read(printerServiceProvider).transportLabelAr}'
                              : 'لم يتم العثور على طابعة متاحة',
                        ),
                        backgroundColor: connected
                            ? AppTheme.success
                            : AppTheme.error,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم حول ---
          const _SectionHeader(title: 'حول التطبيق'),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: colorScheme.secondary,
                  size: 20,
                ),
              ),
              title: const Text('عن التطبيق'),
              subtitle: const Text('المطور، الإصدار، التراخيص'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.pushNamed(context, '/about'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        AppSizes.sectionGap,
        AppSizes.gutter,
        AppSizes.itemGap,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  const _CopyButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: onPressed != null
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
            : null,
        foregroundColor: onPressed != null
            ? Theme.of(context).colorScheme.primary
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        minimumSize: const Size(AppSizes.touchTarget, AppSizes.touchTarget),
      ),
    );
  }
}
