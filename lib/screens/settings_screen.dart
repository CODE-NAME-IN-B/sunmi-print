import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          _SectionHeader(title: 'الطباعة'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Floyd-Steinberg Dithering'),
                  subtitle: const Text('يحسن جودة الصور عند الطباعة'),
                  value: settings.applyDithering,
                  onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(applyDithering: v)),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: const Text('قص تلقائي'),
                  subtitle: const Text('قص الورق بعد كل طباعة'),
                  value: settings.autoCut,
                  onChanged: (v) => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(autoCut: v)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم النسخ ---
          _SectionHeader(title: 'عدد النسخ'),
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
                    child: Icon(Icons.copy_rounded, color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('عدد النسخ')),
                  _CopyButton(
                    icon: Icons.remove_circle_outline,
                    onPressed: settings.copies > 1
                        ? () => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(copies: settings.copies - 1))
                        : null,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${settings.copies}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFFF97316),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _CopyButton(
                    icon: Icons.add_circle_outline,
                    onPressed: settings.copies < 99
                        ? () => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(copies: settings.copies + 1))
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم عرض الطابعة ---
          _SectionHeader(title: 'عرض الطابعة'),
          Card(
            child: RadioGroup<String>(
              groupValue: settings.printerWidth,
              onChanged: (v) {
                if (v == null) return;
                ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(printerWidth: v));
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('58 مم'),
                    subtitle: const Text('384 بكسل - الأصغر'),
                    value: 'mm58',
                  ),
                  const Divider(indent: 16, endIndent: 16),
                  RadioListTile<String>(
                    title: const Text('80 مم'),
                    subtitle: const Text('576 بكسل - الأكبر'),
                    value: 'mm80',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم الطابعة ---
          _SectionHeader(title: 'الطابعة'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bluetooth_rounded, color: Color(0xFFF97316), size: 20),
                  ),
                  title: const Text('البحث عن طابعة Bluetooth'),
                  subtitle: const Text('اكتشاف الطابعات القريبة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.pushNamed(context, '/bluetooth'),
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                  ),
                  title: const Text('إعادة الاتصال'),
                  subtitle: const Text('محاولة إعادة الاتصال بالطابعة'),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('جاري محاولة إعادة الاتصال...')),
                    );
                    final success = await PrinterService.instance.initialize();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'تم الاتصال بالطابعة بنجاح' : 'فشل الاتصال بالطابعة'),
                        backgroundColor: success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // --- قسم حول ---
          _SectionHeader(title: 'حول التطبيق'),
          Card(
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.info_outline, color: colorScheme.secondary, size: 20),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
            ? const Color(0xFFF97316).withValues(alpha: 0.08)
            : null,
        foregroundColor: onPressed != null ? const Color(0xFFF97316) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(44, 44),
      ),
    );
  }
}
