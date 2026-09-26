import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/printer_provider.dart';
import '../services/printer_service.dart';

class PrinterStatusBanner extends ConsumerStatefulWidget {
  const PrinterStatusBanner({super.key});

  @override
  ConsumerState<PrinterStatusBanner> createState() => _PrinterStatusBannerState();
}

class _PrinterStatusBannerState extends ConsumerState<PrinterStatusBanner> {
  bool _isReconnecting = false;

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(printerStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == PrinterConnectionStatus.connected) {
          return const SizedBox.shrink();
        }

        final (String message, Color color, IconData icon) = switch (status) {
          PrinterConnectionStatus.disconnected => ('الطابعة غير متصلة', const Color(0xFFEF4444), Icons.link_off_rounded),
          PrinterConnectionStatus.noPaper => ('نفاد الورق - أضف ورقاً', const Color(0xFFF59E0B), Icons.pending_rounded),
          PrinterConnectionStatus.overheat => ('الطابعة ساخنة - انتظر', const Color(0xFFEA580C), Icons.whatshot_rounded),
          PrinterConnectionStatus.error => ('خطأ في الطابعة', const Color(0xFFEF4444), Icons.error_outline_rounded),
          _ => ('حالة غير معروفة', const Color(0xFF64748B), Icons.help_outline_rounded),
        };

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    fontFamily: 'Work Sans',
                  ),
                ),
              ),
              _isReconnecting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                      ),
                    )
                  : TextButton(
                      onPressed: () async {
                        setState(() => _isReconnecting = true);
                        try {
                          await PrinterService.instance.initialize();
                        } finally {
                          if (mounted) setState(() => _isReconnecting = false);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('إعادة محاولة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
