import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../services/printer_service.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';

class ReceiptEditorScreen extends ConsumerStatefulWidget {
  const ReceiptEditorScreen({super.key});

  @override
  ConsumerState<ReceiptEditorScreen> createState() => _ReceiptEditorScreenState();
}

class _ReceiptEditorScreenState extends ConsumerState<ReceiptEditorScreen> {
  final _storeNameController = TextEditingController();
  final _bodyController = TextEditingController();
  final _footerController = TextEditingController();
  final _qrUrlController = TextEditingController(text: 'https://');
  bool _includeQR = false;
  bool _isPrinting = false;

  @override
  void dispose() {
    _storeNameController.dispose();
    _bodyController.dispose();
    _footerController.dispose();
    _qrUrlController.dispose();
    super.dispose();
  }

  int _getSeparatorLength() {
    final settings = ref.read(settingsProvider);
    return settings.printerWidth == 'mm80' ? 48 : 32;
  }

  Future<void> _print() async {
    setState(() => _isPrinting = true);
    try {
      final printer = PrinterService.instance;
      final separator = '─' * _getSeparatorLength();

      if (_storeNameController.text.isNotEmpty) {
        if (!await printer.printText(_storeNameController.text, align: SunmiPrintAlign.CENTER)) {
          throw Exception('فشل طباعة اسم المتجر');
        }
        if (!await printer.printText(separator, align: SunmiPrintAlign.CENTER)) {
          throw Exception('فشل طباعة الفاصل');
        }
      }

      await printer.lineWrap(1);
      if (!await printer.printText(_bodyController.text, align: SunmiPrintAlign.RIGHT)) {
        throw Exception('فشل طباعة نص الإيصال');
      }
      await printer.lineWrap(1);

      if (_footerController.text.isNotEmpty) {
        if (!await printer.printText(_footerController.text, align: SunmiPrintAlign.CENTER)) {
          throw Exception('failure printing footer');
        }
      }

      if (_includeQR && _qrUrlController.text.isNotEmpty) {
        await printer.lineWrap(1);
        if (!await printer.printQRCode(_qrUrlController.text, size: 5)) {
          throw Exception('failure printing QR code');
        }
      }

      await printer.lineWrap(3);
      if (!await printer.cutPaper()) {
        throw Exception('failure cutting paper');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت طباعة الإيصال بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشلت الطباعة: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final printerStatus = ref.watch(printerStatusProvider).valueOrNull;
    final canPrint = printerStatus == PrinterConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('محرر الإيصال')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                        'محتوى الإيصال',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(labelText: 'اسم المتجر', hintText: 'أدخل اسم المتجر'),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(labelText: 'نص الإيصال', hintText: 'محتوى الإيصال...'),
                    maxLines: 6,
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footerController,
                    decoration: const InputDecoration(labelText: 'تذييل', hintText: 'شكراً لتعاملكم...'),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('إضافة QR Code'),
                  subtitle: const Text('رابط المتجر'),
                  value: _includeQR,
                  onChanged: (v) => setState(() => _includeQR = v),
                ),
                if (_includeQR) ...[
                  const Divider(indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextField(
                      controller: _qrUrlController,
                      decoration: const InputDecoration(
                        labelText: 'رابط QR Code',
                        hintText: 'https://example.com',
                      ),
                      textAlign: TextAlign.left,
                      keyboardType: TextInputType.url,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: (_isPrinting || !canPrint) ? null : _print,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.print_rounded),
              label: Text(_isPrinting ? 'جاري الطباعة...' : 'طباعة الإيصال'),
            ),
          ),
          if (!canPrint)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'الطابعة غير متصلة - قم بتوصيل الطابعة أولاً',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
