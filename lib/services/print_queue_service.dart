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

class PrintQueueService {
  PrintQueueService._();
  static final PrintQueueService instance = PrintQueueService._();

  final StreamController<List<PrintJob>> _queueController =
      StreamController<List<PrintJob>>.broadcast();

  List<PrintJob> _queue = [];
  bool _isProcessing = false;
  Box<String>? _box;

  Stream<List<PrintJob>> get queueStream => _queueController.stream;
  List<PrintJob> get currentQueue => List.unmodifiable(_queue);

  Future<Box<String>> get _store async {
    _box ??= await Hive.openBox<String>(AppConstants.hiveBoxQueue);
    return _box!;
  }

  Future<void> initialize() async {
    final box = await _store;
    final saved = box.get('queue');
    if (saved != null) {
      List<dynamic> decoded;
      try {
        decoded = jsonDecode(saved) as List<dynamic>;
      } catch (_) {
        decoded = [];
      }
      _queue = decoded
          .map((e) => PrintJob.fromJson(e as Map<String, dynamic>))
          .where((job) =>
              job.status == PrintJobStatus.pending ||
              job.status == PrintJobStatus.printing)
          .toList();
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
    final saved = box.get('queue');
    if (saved == null) return [];

    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(saved) as List<dynamic>;
    } catch (_) {
      return [];
    }

    return decoded
        .map((e) => PrintJob.fromJson(e as Map<String, dynamic>))
        .where((job) =>
            job.status == PrintJobStatus.completed ||
            job.status == PrintJobStatus.failed ||
            job.status == PrintJobStatus.cancelled)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<bool> cancelJob(String jobId) async {
    final index = _queue.indexWhere((j) => j.id == jobId);
    if (index == -1) return false;
    if (_queue[index].status == PrintJobStatus.printing) return false;

    _queue[index] = _queue[index].copyWith(status: PrintJobStatus.cancelled);
    await _persist();
    _queueController.add(_queue);
    return true;
  }

  Future<void> clearCompleted() async {
    _queue.removeWhere((j) =>
        j.status == PrintJobStatus.completed ||
        j.status == PrintJobStatus.cancelled ||
        j.status == PrintJobStatus.failed);
    await _persist();
    _queueController.add(_queue);
  }

  Future<void> _processNext() async {
    if (_isProcessing) return;

    while (true) {
      if (!PrinterService.instance.isConnected) break;

      final pendingIndex = _queue.indexWhere(
          (j) => j.status == PrintJobStatus.pending);
      if (pendingIndex == -1) break;

      _isProcessing = true;
      _queue[pendingIndex] = _queue[pendingIndex].copyWith(status: PrintJobStatus.printing);
      _queueController.add(_queue);

      try {
        await _executePrintJob(_queue[pendingIndex]);
        _queue[pendingIndex] =
            _queue[pendingIndex].copyWith(status: PrintJobStatus.completed);
      } catch (e) {
        if (_queue[pendingIndex].retryCount < AppConstants.maxRetryCount) {
          _queue[pendingIndex] = _queue[pendingIndex].copyWith(
            status: PrintJobStatus.pending,
            retryCount: _queue[pendingIndex].retryCount + 1,
            errorMessage: e.toString(),
          );
        } else {
          _queue[pendingIndex] = _queue[pendingIndex].copyWith(
            status: PrintJobStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }

      await _persist();
      _queueController.add(_queue);
    }

    _isProcessing = false;
  }

  Future<void> _executePrintJob(PrintJob job) async {
    final printer = PrinterService.instance;
    if (!printer.isConnected) {
      throw Exception('الطابعة غير متصلة');
    }

    final file = File(job.filePath);
    if (!await file.exists()) {
      throw Exception('الملف غير موجود: ${job.fileName}');
    }

    final settings = ref_read_settings();
    final printerWidthPx = settings.pixelWidth;
    final applyDithering = settings.applyDithering;
    final pdfDpi = settings.pdfDpi;
    final autoCut = settings.autoCut;

    if (job.fileType == PrintFileType.pdf) {
      await _printPdf(job, printer, printerWidthPx, applyDithering, pdfDpi);
    } else {
      await _printImage(job, printer, file, printerWidthPx, applyDithering);
    }

    if (autoCut) {
      await printer.cutPaper();
    }
  }

  Future<void> _printImage(
    PrintJob job,
    PrinterService printer,
    File file,
    int printerWidthPx,
    bool applyDithering,
  ) async {
    final bytes = await file.readAsBytes();

    for (int i = 0; i < job.copies; i++) {
      final processed = ImageProcessor.processForPrinter(
        bytes,
        printerWidthPx: printerWidthPx,
        applyDithering: applyDithering,
      );
      final success = await printer.printImage(bitmapData: processed);
      if (!success) {
        throw Exception('فشل إرسال الصورة إلى الطابعة');
      }
      if (i < job.copies - 1) {
        await printer.lineWrap(2);
      }
    }
  }

  Future<void> _printPdf(
    PrintJob job,
    PrinterService printer,
    int printerWidthPx,
    bool applyDithering,
    int pdfDpi,
  ) async {
    await for (final result in PdfRenderer.renderPages(
      filePath: job.filePath,
      dpi: pdfDpi,
      printerWidthPx: printerWidthPx,
    )) {
      for (int copy = 0; copy < job.copies; copy++) {
        final success = await printer.printImage(bitmapData: result.bitmapData);
        if (!success) {
          throw Exception('فشل إرسال صفحة PDF إلى الطابعة');
        }
        if (copy < job.copies - 1 || result.pageNumber < result.totalPages) {
          await printer.lineWrap(2);
        }
      }
    }
  }

  PrinterSettings ref_read_settings() {
    try {
      final box = Hive.box<String>(AppConstants.hiveBoxSettings);
      final saved = box.get('printerSettings');
      if (saved != null) {
        return PrinterSettings.fromJson(
            jsonDecode(saved) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const PrinterSettings();
  }

  Future<void> _persist() async {
    try {
      final box = await _store;
      final encoded = jsonEncode(_queue.map((j) => j.toJson()).toList());
      await box.put('queue', encoded);
    } catch (e) {
      debugPrint('PrintQueueService: Failed to persist queue: $e');
    }
  }

  void dispose() {
    _queueController.close();
  }
}
