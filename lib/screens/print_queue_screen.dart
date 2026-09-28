import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_motion.dart';
import '../models/print_job.dart';
import '../providers/print_queue_provider.dart';
import '../services/print_queue_service.dart';
import '../widgets/print_job_tile.dart';

class PrintQueueScreen extends ConsumerWidget {
  const PrintQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(printQueueProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('طابور الطباعة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'مسح المهام المنتهية',
            onPressed: () => PrintQueueService.instance.clearCompleted(),
          ),
        ],
      ),
      body: queueAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.08,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.queue_rounded,
                      size: 40,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مهام في الطابور',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أضف ملفات للطباعة من الشاشة الرئيسية',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final activeJobs = jobs
              .where(
                (j) =>
                    j.status == PrintJobStatus.pending ||
                    j.status == PrintJobStatus.printing,
              )
              .toList();
          final completedJobs = jobs
              .where(
                (j) =>
                    j.status == PrintJobStatus.completed ||
                    j.status == PrintJobStatus.failed ||
                    j.status == PrintJobStatus.cancelled,
              )
              .toList();

          final progress = ref.watch(printProgressProvider).valueOrNull;
          final active = jobs.any(
            (j) =>
                j.status == PrintJobStatus.printing ||
                j.status == PrintJobStatus.pending,
          );

          return CustomScrollView(
            slivers: [
              if (active)
                SliverToBoxAdapter(child: _ProgressHeader(progress: progress)),
              if (activeJobs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'نشطة (${activeJobs.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final job = activeJobs[index];
                    return PrintJobTile(
                      job: job,
                      onCancel: job.status == PrintJobStatus.pending
                          ? () => PrintQueueService.instance.cancelJob(job.id)
                          : null,
                      onRetry: null,
                    );
                  }, childCount: activeJobs.length),
                ),
              ],
              if (completedJobs.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'منجزة (${completedJobs.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final job = completedJobs[index];
                    return PrintJobTile(
                      job: job,
                      onCancel: null,
                      onRetry: job.status == PrintJobStatus.failed
                          ? () => PrintQueueService.instance.enqueue(
                              job.copyWith(
                                id: DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                                status: PrintJobStatus.pending,
                                retryCount: 0,
                                errorMessage: null,
                              ),
                            )
                          : null,
                    );
                  }, childCount: completedJobs.length),
                ),
              ],
              const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

/// Byte-level progress for the job in flight.
///
/// Printing a dense photo over Bluetooth takes long enough that an
/// indeterminate spinner reads as a hang, so the page counter and a real
/// fraction are shown instead.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.progress});

  final PrintProgress? progress;

  static String _stageLabel(PrintStage stage) => switch (stage) {
    PrintStage.preparing => 'تجهيز الصفحة',
    PrintStage.sending => 'إرسال البيانات',
    PrintStage.cutting => 'قص الورق',
    PrintStage.done => 'اكتمل',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = progress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value == null
                        ? 'بانتظار الطابعة…'
                        : _stageLabel(value.stage),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (value != null && value.totalPages > 0)
                  Text(
                    'صفحة ${value.currentPage} من ${value.totalPages}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: value?.fraction ?? 0),
              duration: AppMotion.base,
              curve: AppMotion.curve,
              builder: (context, animated, _) => LinearProgressIndicator(
                value: value == null ? null : animated,
                minHeight: 6,
              ),
            ),
            if (value != null && value.stage == PrintStage.sending) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'قد تستغرق الصفحة الكثيفة عدة ثوانٍ حسب الدقة وكثافة الطباعة.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
