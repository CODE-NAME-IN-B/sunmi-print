import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/print_job.dart';
import '../services/print_queue_service.dart';

final printQueueServiceProvider = Provider<PrintQueueService>((ref) {
  return PrintQueueService.instance;
});

final printQueueProvider = StreamProvider<List<PrintJob>>((ref) {
  final service = ref.watch(printQueueServiceProvider);
  return service.queueStream;
});
