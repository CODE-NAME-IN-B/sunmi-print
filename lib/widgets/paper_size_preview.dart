import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_motion.dart';
import '../models/printer_settings.dart';

/// A schematic of the paper coming out of the printer.
///
/// The point is to make the dot width tangible. A shop owner choosing between
/// 58mm and 80mm does not think in dots, so this shows both the millimetre
/// width and the resulting dot count, scaled so the two previews are directly
/// comparable.
class PaperSizePreview extends StatelessWidget {
  const PaperSizePreview({
    super.key,
    required this.settings,
    this.maxHeight = 150,
    this.showLabels = true,
  });

  final PrinterSettings settings;
  final double maxHeight;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    const rollWidths = <int>[58, 80, 100];
    final active = settings.paperPreset == PaperPreset.custom
        ? settings.paperWidthMm
        : settings.paperPreset.rollWidthMm;
    final widest = rollWidths.reduce(math.max);
    final scale = maxHeight / widest;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final mm in rollWidths) ...<Widget>[
          _Roll(
            widthMm: mm,
            dotWidth: mm == active ? settings.pixelWidth : null,
            scale: scale,
            isActive:
                mm == active && settings.paperPreset != PaperPreset.custom,
            scheme: scheme,
            label: showLabels ? '$mm مم' : null,
          ),
          const SizedBox(width: 12),
        ],
        if (settings.paperPreset == PaperPreset.custom)
          _Roll(
            widthMm: settings.paperWidthMm,
            dotWidth: settings.pixelWidth,
            scale: scale,
            isActive: true,
            scheme: scheme,
            label: showLabels ? '${settings.paperWidthMm} مم' : null,
          ),
      ],
    );
  }
}

class _Roll extends StatelessWidget {
  const _Roll({
    required this.widthMm,
    required this.scale,
    required this.isActive,
    required this.scheme,
    this.dotWidth,
    this.label,
  });

  final int widthMm;
  final double scale;
  final bool isActive;
  final ColorScheme scheme;
  final int? dotWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = math.max(18.0, widthMm * scale);
    final active = isActive;

    return Semantics(
      label: '$widthMm millimetre roll',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.curve,
            width: width,
            height: 64,
            decoration: BoxDecoration(
              color: active
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              border: Border.all(
                color: active ? scheme.primary : scheme.outlineVariant,
                width: active ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: dotWidth == null
                ? Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                  )
                : Text(
                    '$dotWidth',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: math.max(width, 44),
            child: Text(
              label ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: active ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the resolved print geometry as a small stat strip.
///
/// Anything that changes a byte count belongs on screen next to the control
/// that changed it, because a misconfigured dot width is otherwise invisible
/// until the output is visibly cropped.
class PrintGeometrySummary extends StatelessWidget {
  const PrintGeometrySummary({super.key, required this.settings});

  final PrinterSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final items = <(String, String)>[
      ('عرض الطباعة', '${settings.paperWidthMm} مم'),
      ('الدقة', '${settings.pixelWidth} بكسل'),
      ('بايت/سطر', '${settings.bytesPerRow}'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              Container(width: 1, height: 28, color: scheme.outlineVariant),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    items[i].$1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].$2,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
