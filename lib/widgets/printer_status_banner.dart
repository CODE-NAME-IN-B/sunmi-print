import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../providers/printer_provider.dart';
import '../services/printer_service.dart';

/// Tells the user when the printer needs something from them, and offers the
/// one action that fixes it.
///
/// The banner stays hidden when everything is fine, because a permanent strip
/// at the top of the home screen would push the print actions down for a
/// condition that only matters occasionally.
class PrinterStatusBanner extends ConsumerStatefulWidget {
  const PrinterStatusBanner({super.key});

  @override
  ConsumerState<PrinterStatusBanner> createState() =>
      _PrinterStatusBannerState();
}

class _PrinterStatusBannerState extends ConsumerState<PrinterStatusBanner> {
  bool _busy = false;

  Future<void> _reconnect() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(printerServiceProvider).initialize();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(printerStatusProvider).valueOrNull;

    if (status == null || status == PrinterConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final (
      String message,
      String hint,
      Color color,
      IconData icon,
      bool canRetry,
    ) = switch (status) {
      PrinterConnectionStatus.noPaper => (
        'نفد الورق',
        'أضف لفافة ورق جديدة ثم أعد المحاولة',
        AppTheme.warning,
        Icons.pending_rounded,
        true,
      ),
      PrinterConnectionStatus.overheat => (
        'رأس الطابعة ساخن',
        'انتظر حتى يبرد قبل الطباعة',
        const Color(0xFFEA580C),
        Icons.whatshot_rounded,
        false,
      ),
      PrinterConnectionStatus.paperJam => (
        'انحشار الورق',
        'افتح غطاء الطابعة وأزل الورق',
        AppTheme.error,
        Icons.report_problem_rounded,
        true,
      ),
      PrinterConnectionStatus.error => (
        'خطأ في الطابعة',
        'أعد المحاولة أو غيّر طريقة الاتصال',
        AppTheme.error,
        Icons.error_outline_rounded,
        true,
      ),
      PrinterConnectionStatus.disconnected => (
        'الطابعة غير متصلة',
        'لم يتم العثور على طابعة متاحة',
        AppTheme.error,
        Icons.link_off_rounded,
        true,
      ),
      _ => (
        'حالة غير معروفة',
        'راجع حالة الطابعة',
        scheme.onSurfaceVariant,
        Icons.help_outline_rounded,
        true,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.curve,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    message,
                    style: theme.textTheme.titleSmall?.copyWith(color: color),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canRetry)
              if (_busy)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed<void>('/bluetooth'),
                      child: const Text('اختيار طابعة'),
                    ),
                    TextButton(
                      onPressed: _reconnect,
                      child: const Text('إعادة محاولة'),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
