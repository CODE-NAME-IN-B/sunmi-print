import 'package:flutter/material.dart';
import '../models/print_job.dart';

class PrintJobTile extends StatelessWidget {
  final PrintJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const PrintJobTile({
    super.key,
    required this.job,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (IconData icon, Color iconColor) = switch (job.fileType) {
      PrintFileType.image => (Icons.image_rounded, colorScheme.tertiary),
      PrintFileType.pdf => (Icons.picture_as_pdf_rounded, colorScheme.error),
      PrintFileType.text => (Icons.text_snippet_rounded, colorScheme.secondary),
    };

    final statusInfo = _getStatusInfo(job.status);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          job.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusInfo.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusInfo.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        trailing: _buildTrailing(context, colorScheme),
      ),
    );
  }

  _StatusInfo _getStatusInfo(PrintJobStatus status) {
    return switch (status) {
      PrintJobStatus.pending => _StatusInfo('في الانتظار', const Color(0xFFF59E0B)),
      PrintJobStatus.printing => _StatusInfo('جاري الطباعة', const Color(0xFF3B82F6)),
      PrintJobStatus.completed => _StatusInfo('تم بنجاح', const Color(0xFF10B981)),
      PrintJobStatus.failed => _StatusInfo('فشل', const Color(0xFFEF4444)),
      PrintJobStatus.cancelled => _StatusInfo('ملغي', const Color(0xFF64748B)),
    };
  }

  Widget? _buildTrailing(BuildContext context, ColorScheme colorScheme) {
    switch (job.status) {
      case PrintJobStatus.pending:
        return IconButton(
          icon: const Icon(Icons.cancel_outlined),
          color: const Color(0xFFEF4444),
          onPressed: onCancel,
          tooltip: 'إلغاء',
        );
      case PrintJobStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh_rounded),
          color: const Color(0xFFF97316),
          onPressed: onRetry,
          tooltip: 'إعادة المحاولة',
        );
      case PrintJobStatus.printing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
        );
      case PrintJobStatus.completed:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
        );
      case PrintJobStatus.cancelled:
        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF64748B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cancel_rounded, color: Color(0xFF64748B), size: 20),
        );
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  const _StatusInfo(this.label, this.color);
}
