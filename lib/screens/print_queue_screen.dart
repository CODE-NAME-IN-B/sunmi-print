import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.queue_rounded,
                      size: 40,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مهام في الطابور',
                    style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أضف ملفات للطباعة من الشاشة الرئيسية',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            );
          }

          final activeJobs = jobs.where((j) =>
              j.status == PrintJobStatus.pending ||
              j.status == PrintJobStatus.printing).toList();
          final completedJobs = jobs.where((j) =>
              j.status == PrintJobStatus.completed ||
              j.status == PrintJobStatus.failed ||
              j.status == PrintJobStatus.cancelled).toList();

          return CustomScrollView(
            slivers: [
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
                            color: const Color(0xFFF97316),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final job = activeJobs[index];
                      return PrintJobTile(
                        job: job,
                        onCancel: job.status == PrintJobStatus.pending
                            ? () => PrintQueueService.instance.cancelJob(job.id)
                            : null,
                        onRetry: null,
                      );
                    },
                    childCount: activeJobs.length,
                  ),
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
                            color: const Color(0xFF64748B),
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
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final job = completedJobs[index];
                      return PrintJobTile(
                        job: job,
                        onCancel: null,
                        onRetry: job.status == PrintJobStatus.failed
                            ? () => PrintQueueService.instance.enqueue(job.copyWith(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                status: PrintJobStatus.pending,
                                retryCount: 0,
                                errorMessage: null,
                              ))
                            : null,
                      );
                    },
                    childCount: completedJobs.length,
                  ),
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
