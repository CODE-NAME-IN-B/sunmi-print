import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../models/receipt_document.dart';
import '../services/printer_service.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/pressable_scale.dart';

class ReceiptEditorScreen extends ConsumerStatefulWidget {
  const ReceiptEditorScreen({super.key});

  @override
  ConsumerState<ReceiptEditorScreen> createState() =>
      _ReceiptEditorScreenState();
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

  /// Builds the printable document from the form fields.
  ///
  /// Everything goes through [ReceiptDocument] rather than a sequence of
  /// print calls so the whole receipt is laid out and rasterised at the
  /// configured paper width in one pass. That is what keeps Arabic shaping and
  /// right-to-left order correct: the Flutter text engine lays the line out,
  /// and the printer only ever receives finished dots.
  ReceiptDocument _buildDocument() {
    final body = _bodyController.text.trim();
    final store = _storeNameController.text.trim();
    final footer = _footerController.text.trim();
    final qr = _includeQR ? _qrUrlController.text.trim() : '';

    return ReceiptDocument(
      header: store,
      subHeader: store.isEmpty ? null : null,
      lines: <ReceiptLine>[
        if (store.isNotEmpty) const ReceiptLine.rule(ReceiptRule.solid),
        if (body.isNotEmpty) ReceiptLine.text(body, align: ReceiptAlign.start),
      ],
      footer: footer.isEmpty ? null : footer,
      qrData: qr.isEmpty ? null : qr,
    );
  }

  Future<void> _print() async {
    final document = _buildDocument();
    if (document.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإيصال فارغ. أدخل المحتوى أولاً.')),
      );
      return;
    }

    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    final settings = ref.read(settingsProvider);

    final ok = await ref
        .read(printerServiceProvider)
        .printReceipt(document, settings: settings, copies: settings.copies);

    if (!mounted) return;
    setState(() => _isPrinting = false);

    if (ok) {
      HapticFeedback.mediumImpact();
      messenger.showSnackBar(
        SnackBar(
          content: Text('تمت طباعة الإيصال · ${settings.pixelWidth} بكسل'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('فشلت الطباعة. تحقق من الورق واتصال الطابعة.'),
          backgroundColor: AppTheme.error,
        ),
      );
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
                    decoration: const InputDecoration(
                      labelText: 'اسم المتجر',
                      hintText: 'أدخل اسم المتجر',
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: 'نص الإيصال',
                      hintText: 'اكتب الأصناف والأسعار…',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    minLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footerController,
                    decoration: const InputDecoration(
                      labelText: 'تذييل',
                      hintText: 'شكراً لتعاملكم...',
                    ),
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
          PressableScale(
            onTap: (_isPrinting || !canPrint) ? null : _print,
            enabled: !_isPrinting && canPrint,
            child: SizedBox(
              height: AppSizes.touchTarget + 4,
              child: FilledButton.icon(
                onPressed: (_isPrinting || !canPrint) ? null : _print,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(_isPrinting ? 'جارٍ الطباعة…' : 'طباعة الإيصال'),
              ),
            ),
          ),
          if (!canPrint)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.gutter,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.link_off_rounded,
                      color: colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الطابعة غير متصلة',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed<void>('/bluetooth'),
                      child: const Text('اتصال'),
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
