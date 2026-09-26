import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/utils/image_processor.dart';
import '../core/utils/pdf_renderer.dart';
import '../models/print_job.dart';
import '../models/printer_settings.dart';
import '../services/print_queue_service.dart';
import '../providers/settings_provider.dart';

class PreviewScreen extends ConsumerStatefulWidget {
  const PreviewScreen({super.key});

  @override
  ConsumerState<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends ConsumerState<PreviewScreen> {
  PlatformFile? _file;
  Uint8List? _previewData;
  bool _isLoading = false;
  bool _isPrinting = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is PlatformFile && _previewData == null) {
      _file = args;
      _generatePreview();
    }
  }

  bool get _isPdf => _file?.extension?.toLowerCase() == 'pdf';

  Future<void> _generatePreview() async {
    setState(() => _isLoading = true);

    try {
      final file = _file;
      if (file == null || file.path == null) {
        setState(() { _error = 'لم يتم اختيار ملف'; _isLoading = false; });
        return;
      }

      final settings = ref.read(settingsProvider);

      if (_isPdf) {
        await _generatePdfPreview(file.path!, settings);
      } else {
        await _generateImagePreview(file.path!, settings);
      }
    } catch (e) {
      setState(() { _error = 'فشل المعالجة: $e'; _isLoading = false; });
    }
  }

  Future<void> _generateImagePreview(String path, PrinterSettings settings) async {
    final file = File(path);
    final sizeBytes = await file.length();
    if (sizeBytes > 20 * 1024 * 1024) {
      setState(() { _error = 'حجم الملف كبير جداً (${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB). الحد الأقصى 20 MB.'; _isLoading = false; });
      return;
    }
    final bytes = await file.readAsBytes();
    final processed = ImageProcessor.processForPrinter(
      bytes,
      printerWidthPx: settings.pixelWidth,
      applyDithering: settings.applyDithering,
    );
    setState(() { _previewData = processed; _isLoading = false; });
  }

  Future<void> _generatePdfPreview(String path, PrinterSettings settings) async {
    await for (final result in PdfRenderer.renderPages(
      filePath: path,
      dpi: settings.pdfDpi,
      printerWidthPx: settings.pixelWidth,
    )) {
      setState(() { _previewData = result.bitmapData; });
      break;
    }
    setState(() { _isLoading = false; });
  }

  Future<void> _print() async {
    final file = _file;
    if (_previewData == null || file == null || file.path == null) return;

    setState(() => _isPrinting = true);
    final settings = ref.read(settingsProvider);

    try {
      final job = PrintJob(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        filePath: file.path!,
        fileName: file.name,
        fileType: _isPdf ? PrintFileType.pdf : PrintFileType.image,
        copies: settings.copies,
        createdAt: DateTime.now(),
      );

      await PrintQueueService.instance.enqueue(job);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت الإضافة إلى طابور الطباعة')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'فشل الطباعة: $e');
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('معاينة الطباعة')),
      body: _buildBody(theme, colorScheme),
      bottomNavigationBar: _previewData != null && !_isLoading
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isPrinting ? null : _print,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.print_rounded),
                    label: Text(_isPrinting ? 'جاري الإضافة...' : 'إضافة للطباعة'),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
              ),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _generatePreview,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_previewData == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.preview_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد معاينة',
              style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.memory(_previewData!, width: double.infinity, fit: BoxFit.contain),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  border: Border(
                    top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _file!.name,
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
