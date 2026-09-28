import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_motion.dart';
import '../core/theme/app_theme.dart';
import '../models/printer_profile.dart';
import '../models/printer_settings.dart';
import '../providers/printer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/printer_service.dart';
import '../widgets/paper_size_preview.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/skeleton.dart';

/// Paper, resolution and density in one screen.
///
/// The order is deliberate: paper first, because it defines the dot width, then
/// resolution, then density, then the two things that verify the choice, a
/// live geometry summary and a test print that is always reachable at the
/// bottom without scrolling back.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  final TextEditingController _customWidthController = TextEditingController();
  bool _savingTest = false;
  int? _lastTestedPixelWidth;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _customWidthController.text = settings.customWidthMm.toString();
  }

  @override
  void dispose() {
    _customWidthController.dispose();
    super.dispose();
  }

  void _update(PrinterSettings next) {
    ref.read(settingsProvider.notifier).updateSettings(next);
    setState(() {});
  }

  void _onCustomWidthChanged(String raw) {
    final parsed = int.tryParse(raw);
    if (parsed == null) return;
    final settings = ref.read(settingsProvider);
    if (parsed == settings.customWidthMm) return;
    _update(settings.copyWith(customWidthMm: parsed));
  }

  Future<void> _printTest(PrinterSettings settings) async {
    if (_savingTest) return;

    setState(() => _savingTest = true);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final transport = ref.read(printerServiceProvider).transport;
    final progress = _lastTestedPixelWidth != settings.pixelWidth;

    final ok = await ref
        .read(printerServiceProvider)
        .printTestPage(settings: settings);

    if (!mounted) return;
    setState(() {
      _savingTest = false;
      if (ok) _lastTestedPixelWidth = settings.pixelWidth;
    });

    if (ok) {
      if (progress) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال صفحة الاختبار · ${settings.pixelWidth} بكسل',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('تم إرسال صفحة الاختبار')),
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            transport == PrinterTransport.none
                ? 'لا توجد طابعة متصلة. اختر طريقة الاتصال أولاً.'
                : 'فشلت الطباعة. تحقق من الورق وحالة الطابعة.',
          ),
          backgroundColor: AppTheme.error,
          action: SnackBarAction(
            label: transport == PrinterTransport.none
                ? 'الاتصال'
                : 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () async {
              if (transport != PrinterTransport.none) {
                _printTest(settings);
                return;
              }
              await navigator.pushNamed<void>('/bluetooth');
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات الطابعة')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          AppSizes.gutter,
          AppSizes.gutter,
          140,
        ),
        children: <Widget>[
          const _SectionLabel('مقاس الورق'),
          const SizedBox(height: AppSizes.itemGap),
          PaperSizePreview(settings: settings, maxHeight: 120),
          const SizedBox(height: AppSizes.sectionGap),
          _PaperPresetGrid(
            selected: settings.paperPreset,
            onSelected: (preset) =>
                _update(settings.copyWith(paperPreset: preset)),
          ),
          if (settings.paperPreset == PaperPreset.custom) ...<Widget>[
            const SizedBox(height: AppSizes.sectionGap),
            _CustomWidthField(
              controller: _customWidthController,
              onChanged: _onCustomWidthChanged,
              onSubmit: (value) {
                final parsed = int.tryParse(value);
                if (parsed == null) return;
                _update(
                  settings.copyWith(
                    customWidthMm: parsed.clamp(
                      AppConstants.minPaperWidthMm,
                      AppConstants.maxPaperWidthMm,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: AppSizes.sectionGap),
          PrintGeometrySummary(settings: settings),
          const SizedBox(height: AppSizes.sectionGap),

          const _SectionLabel('دقة الطابعة'),
          const SizedBox(height: AppSizes.itemGap),
          _DpiSelector(
            value: settings.printerDpi,
            onChanged: (dpi) => _update(settings.copyWith(printerDpi: dpi)),
          ),
          const SizedBox(height: AppSizes.sectionGap),

          const _SectionLabel('كثافة الطباعة'),
          const SizedBox(height: 4),
          Text(
            'أعلى = خطوط أدكن واختبار أبطأ. اضبطها حتى تظهر الحروف الصغيرة واضحة.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.itemGap),
          _DensitySlider(
            value: settings.printDensity,
            onChanged: (density) =>
                _update(settings.copyWith(printDensity: density)),
          ),
          const SizedBox(height: AppSizes.sectionGap),

          const _SectionLabel('خيارات الطباعة'),
          const SizedBox(height: AppSizes.itemGap),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: settings.autoCut,
                  onChanged: (v) =>
                      notifier.updateSettings(settings.copyWith(autoCut: v)),
                  title: const Text('قص تلقائي'),
                  subtitle: const Text('قص الورق بعد انتهاء كل مهمة'),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile.adaptive(
                  value: settings.applyDithering,
                  onChanged: (v) => notifier.updateSettings(
                    settings.copyWith(applyDithering: v),
                  ),
                  title: const Text('تدرّج Floyd–Steinberg'),
                  subtitle: const Text(
                    'يحسّن الصور الرمادية قبل التحويل لنقاط',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),

          const _SectionLabel('طريقة الاتصال'),
          const SizedBox(height: AppSizes.itemGap),
          _TransportSelector(
            preference:
                ref
                    .watch(printerProfileProvider)
                    .valueOrNull
                    ?.transportPreference ??
                PrinterService.instance.profile.transportPreference,
            hasBluetoothPrinter:
                ref
                    .watch(printerProfileProvider)
                    .valueOrNull
                    ?.hasBluetoothPrinter ??
                PrinterService.instance.profile.hasBluetoothPrinter,
          ),
        ],
      ),
      bottomNavigationBar: _TestPrintBar(
        settings: settings,
        busy: _savingTest,
        onPressed: () => _printTest(settings),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Segmented paper cards rather than radio rows: each option carries its dot
/// count, so the choice can be made without reading a second control.
class _PaperPresetGrid extends StatelessWidget {
  const _PaperPresetGrid({required this.selected, required this.onSelected});

  final PaperPreset selected;
  final ValueChanged<PaperPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <PaperPreset>[
      PaperPreset.mm58,
      PaperPreset.mm80,
      PaperPreset.mm100,
      PaperPreset.custom,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 520 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: <Widget>[
            for (final preset in options)
              PressableScale(
                key: ValueKey<PaperPreset>(preset),
                onTap: () => onSelected(preset),
                semanticLabel: preset == PaperPreset.custom
                    ? 'Custom paper width'
                    : '${preset.rollWidthMm} millimetre roll',
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: preset == selected
                        ? AppTheme.primary.withValues(alpha: 0.10)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(
                      color: preset == selected
                          ? AppTheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      width: preset == selected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            preset == PaperPreset.custom
                                ? 'مخصص'
                                : '${preset.rollWidthMm}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: preset == selected
                                      ? AppTheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          if (preset != PaperPreset.custom)
                            Text(
                              ' مم',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          const Spacer(),
                          if (preset == selected)
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset == PaperPreset.custom
                            ? 'أدخل العرض بالمليمتر'
                            : _dotsFor(preset),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static String _dotsFor(PaperPreset preset) {
    final width = preset.printableWidthMm(
      customWidthMm: AppConstants.printableWidth58mm,
    );
    final dots = (width * AppConstants.pdfDefaultDpi / 25.4).round();
    return '$dots بكسل @ ${AppConstants.pdfDefaultDpi}';
  }
}

class _CustomWidthField extends StatelessWidget {
  const _CustomWidthField({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmit,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: const InputDecoration(
        labelText: 'العرض القابل للطباعة (مم)',
        hintText: '48',
        suffixText: 'مم',
        helperText:
            'بين ${AppConstants.minPaperWidthMm} و ${AppConstants.maxPaperWidthMm} مم',
        helperMaxLines: 2,
        prefixIcon: Icon(Icons.straighten_rounded),
      ),
    );
  }
}

class _DpiSelector extends StatelessWidget {
  const _DpiSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: <ButtonSegment<int>>[
        for (final dpi in AppConstants.supportedDpi)
          ButtonSegment<int>(
            value: dpi,
            label: Text('$dpi'),
            icon: dpi == AppConstants.pdfDefaultDpi
                ? const Icon(Icons.star_rounded, size: 15)
                : null,
          ),
      ],
      selected: <int>{value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _DensitySlider extends StatelessWidget {
  const _DensitySlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    'خفيف',
    'خفيف+',
    'متوازن',
    'كثيف',
    'كثيف جداً',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = (value - AppConstants.minPrintDensity).clamp(
      0,
      _labels.length - 1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              '${AppConstants.minPrintDensity}',
              style: theme.textTheme.labelSmall,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Text(
                '$value · ${_labels[index]}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            Text(
              '${AppConstants.maxPrintDensity}',
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: AppConstants.minPrintDensity.toDouble(),
          max: AppConstants.maxPrintDensity.toDouble(),
          divisions:
              AppConstants.maxPrintDensity - AppConstants.minPrintDensity,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _TransportSelector extends ConsumerWidget {
  const _TransportSelector({
    required this.preference,
    required this.hasBluetoothPrinter,
  });

  final TransportPreference preference;
  final bool hasBluetoothPrinter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(printerServiceProvider);
    final theme = Theme.of(context);

    const options = <TransportPreference>[
      TransportPreference.auto,
      TransportPreference.sunmiSdk,
      TransportPreference.bluetoothClassic,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RadioGroup<TransportPreference>(
          groupValue: preference,
          onChanged: (v) {
            if (v == null) return;
            service.setTransportPreference(v);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final option in options) ...<Widget>[
                RadioListTile<TransportPreference>(
                  value: option,
                  title: Text(switch (option) {
                    TransportPreference.auto => 'تلقائي',
                    TransportPreference.sunmiSdk => 'الطابعة المدمجة (AIDL)',
                    TransportPreference.bluetoothClassic => 'بلوتوث كلاسيكي',
                  }, style: theme.textTheme.titleSmall),
                  subtitle: Text(switch (option) {
                    TransportPreference.auto =>
                      'جرّب الطابعة المدمجة أولاً ثم انتقل للبلوتوث',
                    TransportPreference.sunmiSdk =>
                      'للأجهزة المزوّدة بـ Sunmi SDK',
                    TransportPreference.bluetoothClassic =>
                      !hasBluetoothPrinter
                          ? 'لم يتم اختيار طابعة بعد'
                          : service.savedPrinter?.name ?? 'الطابعة المحفوظة',
                  }, style: theme.textTheme.bodySmall),
                  contentPadding: EdgeInsets.zero,
                ),
                if (option != options.last)
                  const Divider(indent: 0, endIndent: 0),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.itemGap),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushNamed<void>('/bluetooth'),
          icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
          label: Text(
            hasBluetoothPrinter ? 'تغيير الطابعة' : 'اختيار طابعة بلوتوث',
          ),
        ),
      ],
    );
  }
}

/// A sticky action bar so the verification step never requires scrolling.
class _TestPrintBar extends StatelessWidget {
  const _TestPrintBar({
    required this.settings,
    required this.busy,
    required this.onPressed,
  });

  final PrinterSettings settings;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          10,
          AppSizes.gutter,
          10,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('صفحة اختبار', style: theme.textTheme.labelMedium),
                  Text(
                    '${settings.pixelWidth} بكسل · ${settings.printDensity}/5',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.itemGap),
            FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 18),
              label: Text(busy ? 'جارٍ الإرسال' : 'اختبار'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width loading state used while Hive hands back saved settings.
class PrinterSettingsSkeleton extends StatelessWidget {
  const PrinterSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.gutter),
      children: const <Widget>[
        SkeletonBox(height: 18, width: 120),
        SizedBox(height: 16),
        SkeletonBox(height: 120),
        SizedBox(height: 24),
        SkeletonBox(height: 18, width: 90),
        SizedBox(height: 12),
        SkeletonDeviceTile(),
        SizedBox(height: 12),
        SkeletonDeviceTile(),
      ],
    );
  }
}
