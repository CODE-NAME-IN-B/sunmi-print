import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/image_processor.dart';
import '../core/utils/pdf_renderer.dart';
import '../models/print_job.dart';
import '../models/printer_settings.dart';
import 'printer_service.dart';

/// What a queued job is currently doing, so the UI can show a determinate
/// progress bar instead of an endless spinner.
@immutable
class PrintProgress {
  const PrintProgress({
    required this.jobId,
    required this.stage,
    this.currentPage = 0,
    this.totalPages = 1,
  });

  final String jobId;
  final PrintStage stage;
  final int currentPage;
  final int totalPages;

  /// Between 0 and 1. Unknown totals report 0 so the bar stays in the
  /// "working, not quantifiable" state instead of lying about progress.
  double get fraction {
    if (totalPages <= 0) return 0;
    return (currentPage / totalPages).clamp(0.0, 1.0);
  }
}

enum PrintStage { preparing, sending, cutting, done }

/// Thrown when the link to the printer disappears while a job is in flight.
/// Carries an Arabic message because the queue screen shows it verbatim.
class PrintInterruptedException implements Exception {
  const PrintInterruptedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serial, retrying, durable print queue.
///
/// Jobs are executed one at a time. Three jobs fired in quick succession run
/// strictly in order, which is what a till operator expects: the receipt of
/// the previous customer must be out before the next one starts.
class PrintQueueService {
  PrintQueueService._();

  static final PrintQueueService instance = PrintQueueService._();

  final StreamController<List<PrintJob>> _queueController =
      StreamController<List<PrintJob>>.broadcast();
  final StreamController<PrintProgress?> _progressController =
      StreamController<PrintProgress?>.broadcast();

  List<PrintJob> _queue = [];
  bool _isProcessing = false;
  PrintProgress? _lastProgress;
  Box<String>? _box;

  Stream<List<PrintJob>> get queueStream => _queueController.stream;
  Stream<PrintProgress?> get progressStream => _progressController.stream;

  /// Snapshot of the most recent progress event, for screens that mount after
  /// a job has already started.
  PrintProgress? get progress => _lastProgress;

  List<PrintJob> get currentQueue => List<PrintJob>.unmodifiable(_queue);

  /// Number of jobs still waiting to be printed.
  int get pendingCount => _queue
      .where(
        (job) =>
            job.status == PrintJobStatus.pending ||
            job.status == PrintJobStatus.printing,
      )
      .length;

  Future<Box<String>> get _store async {
    _box ??= await Hive.openBox<String>(AppConstants.hiveBoxQueue);
    return _box!;
  }

  Future<void> initialize() async {
    final box = await _store;
    final saved = box.get(AppConstants.hiveKeyQueue);
    if (saved != null) {
      List<dynamic> decoded;
      try {
        decoded = jsonDecode(saved) as List<dynamic>;
      } catch (_) {
        decoded = const <dynamic>[];
      }
      _queue = decoded
          .map((e) => PrintJob.fromJson(e as Map<String, dynamic>))
          .where(
            (job) =>
                job.status == PrintJobStatus.pending ||
                job.status == PrintJobStatus.printing,
          )
          .toList();
      // A job that was mid transfer when the process died is unknown, so it
      // goes back to pending rather than silently vanishing.
      for (int i = 0; i < _queue.length; i++) {
        if (_queue[i].status == PrintJobStatus.printing) {
          _queue[i] = _queue[i].copyWith(status: PrintJobStatus.pending);
        }
      }
      await _persist();
    }
    _queueController.add(_queue);
  }

  Future<String> enqueue(PrintJob job) async {
    final id = job.id.isEmpty
        ? '${DateTime.now().microsecondsSinceEpoch}'
        : '${job.id}_${DateTime.now().microsecondsSinceEpoch}';
    final jobWithId = job.copyWith(id: id);
    _queue.add(jobWithId);
    await _persist();
    _queueController.add(_queue);
    unawaited(_processNext());
    return jobWithId.id;
  }

  Future<List<PrintJob>> getHistory() async {
    final box = await _store;
    final saved = box.get(AppConstants.hiveKeyQueue);
    if (saved == null) return const <PrintJob>[];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(saved) as List<dynamic>;
    } catch (_) {
      return const <PrintJob>[];
    }

    final history = decoded
        .map((e) => PrintJob.fromJson(e as Map<String, dynamic>))
        .where(
          (job) =>
              job.status == PrintJobStatus.completed ||
              job.status == PrintJobStatus.failed ||
              job.status == PrintJobStatus.cancelled,
        )
        .toList();
    history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return history;
  }

  Future<bool> cancelJob(String jobId) async {
    final index = _queue.indexWhere((job) => job.id == jobId);
    if (index == -1) return false;
    // A job that is already feeding cannot be recalled, so refusing is
    // honest rather than pretending.
    if (_queue[index].status == PrintJobStatus.printing) return false;

    _queue[index] = _queue[index].copyWith(status: PrintJobStatus.cancelled);
    await _persist();
    _queueController.add(_queue);
    return true;
  }

  Future<void> clearCompleted() async {
    _queue.removeWhere(
      (job) =>
          job.status == PrintJobStatus.completed ||
          job.status == PrintJobStatus.cancelled ||
          job.status == PrintJobStatus.failed,
    );
    await _persist();
    _queueController.add(_queue);
  }

  /// Resumes the queue after the printer comes back.
  void resume() {
    if (!_isProcessing) unawaited(_processNext());
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;

    try {
      while (true) {
        if (!PrinterService.instance.isConnected) break;

        final pendingIndex = _queue.indexWhere(
          (job) => job.status == PrintJobStatus.pending,
        );
        if (pendingIndex == -1) break;

        _isProcessing = true;
        _queue[pendingIndex] = _queue[pendingIndex].copyWith(
          status: PrintJobStatus.printing,
        );
        _queueController.add(_queue);

        try {
          await _executePrintJob(_queue[pendingIndex]);
          _queue[pendingIndex] = _queue[pendingIndex].copyWith(
            status: PrintJobStatus.completed,
          );
        } catch (e) {
          final job = _queue[pendingIndex];
          if (job.retryCount < AppConstants.maxRetryCount) {
            _queue[pendingIndex] = job.copyWith(
              status: PrintJobStatus.pending,
              retryCount: job.retryCount + 1,
              errorMessage: e.toString(),
            );
          } else {
            _queue[pendingIndex] = job.copyWith(
              status: PrintJobStatus.failed,
              errorMessage: e.toString(),
            );
          }
        }

        await _persist();
        _queueController.add(_queue);
      }
    } finally {
      _isProcessing = false;
      _emitProgress(null);
    }
  }

  Future<void> _executePrintJob(PrintJob job) async {
    final printer = PrinterService.instance;
    if (!printer.isConnected) {
      throw const PrintInterruptedException('الطابعة غير متصلة');
    }

    final file = File(job.filePath);
    if (!await file.exists()) {
      throw PrintInterruptedException('الملف غير موجود: ${job.fileName}');
    }

    final settings = readSettings();

    if (job.fileType == PrintFileType.pdf) {
      await _printPdf(job, printer, file, settings);
    } else {
      await _printImage(job, printer, file, settings);
    }

    if (settings.autoCut) {
      _emitProgress(
        PrintProgress(
          jobId: job.id,
          stage: PrintStage.cutting,
          currentPage: job.totalPages,
          totalPages: job.totalPages,
        ),
      );
      await printer.cutPaper();
    }

    _emitProgress(
      PrintProgress(
        jobId: job.id,
        stage: PrintStage.done,
        currentPage: job.totalPages,
        totalPages: job.totalPages,
      ),
    );
  }

  Future<void> _printImage(
    PrintJob job,
    PrinterService printer,
    File file,
    PrinterSettings settings,
  ) async {
    _emitProgress(
      PrintProgress(
        jobId: job.id,
        stage: PrintStage.preparing,
        currentPage: 0,
        totalPages: job.copies,
      ),
    );

    final sizeBytes = await file.length();
    if (sizeBytes > AppConstants.maxFileSizeBytes) {
      throw const ImageProcessingException(
        'حجم الملف كبير جداً — الحد الأقصى 20 ميجابايت',
      );
    }
    final bytes = await file.readAsBytes();

    for (int copy = 0; copy < job.copies; copy++) {
      final packed = ImageProcessor.processForPrinter(
        bytes,
        printerWidthPx: settings.pixelWidth,
        applyDithering: settings.applyDithering,
      );

      _emitProgress(
        PrintProgress(
          jobId: job.id,
          stage: PrintStage.sending,
          currentPage: copy,
          totalPages: job.copies,
        ),
      );

      final ok = await printer.printRaster(
        bitmapData: packed,
        pixelWidth: settings.pixelWidth,
      );
      if (!ok) {
        // A failure here is almost always a dropped link, and printing more
        // pages into a half delivered receipt is worse than stopping.
        throw const PrintInterruptedException(
          'انقطع الاتصال بالطابعة — أعد المحاولة',
        );
      }
    }
  }

  Future<void> _printPdf(
    PrintJob job,
    PrinterService printer,
    File file,
    PrinterSettings settings,
  ) async {
    final total = job.copies;
    var pageIndex = 0;

    await for (final result in PdfRenderer.renderPages(
      filePath: file.path,
      dpi: settings.pdfDpi,
      printerWidthPx: settings.pixelWidth,
      applyDithering: settings.applyDithering,
    )) {
      for (int copy = 0; copy < total; copy++) {
        pageIndex++;
        _emitProgress(
          PrintProgress(
            jobId: job.id,
            stage: PrintStage.sending,
            currentPage: pageIndex,
            totalPages: result.totalPages * total,
          ),
        );

        final ok = await printer.printRaster(
          bitmapData: result.bitmapData,
          pixelWidth: settings.pixelWidth,
        );
        if (!ok) {
          throw const PrintInterruptedException(
            'انقطع الاتصال بالطابعة — أعد المحاولة',
          );
        }

        final isLastPage = result.pageNumber >= result.totalPages;
        if (copy < total - 1 || !isLastPage) {
          await printer.lineWrap(2);
        }
      }
    }
  }

  /// Reads the saved settings directly from Hive.
  ///
  /// The queue lives outside the widget tree, so it cannot watch a provider.
  /// Reading the box keeps a single source of truth without threading the
  /// settings through every enqueue call site.
  static PrinterSettings readSettings() {
    try {
      final box = Hive.box<String>(AppConstants.hiveBoxSettings);
      final saved = box.get(AppConstants.hiveKeyPrinterSettings);
      if (saved != null) {
        return PrinterSettings.decode(saved);
      }
    } catch (e) {
      debugPrint('PrintQueueService: settings read failed: $e');
    }
    return const PrinterSettings();
  }

  void _emitProgress(PrintProgress? value) {
    _lastProgress = value;
    if (_progressController.isClosed) return;
    _progressController.add(value);
  }

  Future<void> _persist() async {
    try {
      final box = await _store;
      final encoded = jsonEncode(_queue.map((job) => job.toJson()).toList());
      await box.put(AppConstants.hiveKeyQueue, encoded);
    } catch (e) {
      debugPrint('PrintQueueService: Failed to persist queue: $e');
    }
  }

  void dispose() {
    _queueController.close();
    _progressController.close();
  }
}
