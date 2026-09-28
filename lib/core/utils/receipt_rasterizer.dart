import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;

import '../../models/printer_settings.dart';
import '../../models/receipt_document.dart';
import '../constants/app_constants.dart';
import 'bitmap_utils.dart';

/// Turns a [ReceiptDocument] into a 1-bit raster for the printhead.
///
/// The whole point of this class is that no Arabic ever reaches the printer as
/// bytes. Layout goes through Flutter's own text engine, so the Unicode
/// bidirectional algorithm, Arabic contextual shaping and the font fallback
/// chain behave exactly as they do on screen. The printer only ever receives a
/// bitmap, which is why the encoding and codepage conflicts that plague ESC/POS
/// text mode cannot occur.
///
/// Sending Arabic as `codeUnits` (UTF-16) or as Windows-1256 produces mojibake
/// on any printer whose internal codepage differs from the sender's. Rendering
/// removes that entire class of bug.
class ReceiptRasterizer {
  ReceiptRasterizer._();

  /// Characters that force the paragraph to be laid out right to left.
  static final RegExp _rtlScript = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF'
    r'\u0700-\u074F\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  static bool isRtl(String text) => _rtlScript.hasMatch(text);

  /// Maps the 1..5 density control onto a dithering threshold. A denser
  /// setting burns more dots, so the threshold drops and mid greys resolve
  /// darker.
  static int thresholdForDensity(int density) {
    final clamped = density.clamp(
      AppConstants.minPrintDensity,
      AppConstants.maxPrintDensity,
    );
    return 168 - (clamped - 1) * 14; // 1 -> 168 (light) ... 5 -> 112 (dark)
  }

  /// Renders [document] for a printhead [pixelWidth] dots wide.
  static Future<RasterizedReceipt> render(
    ReceiptDocument document, {
    required PrinterSettings settings,
  }) async {
    if (document.isEmpty) {
      throw StateError('لا يوجد محتوى للطباعة');
    }

    final width = settings.pixelWidth;
    final layout = _Layout.forWidth(width, settings.textColumns);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final blocks = _buildBlocks(document, layout);

    final totalHeight = _totalHeight(blocks, layout);
    if (totalHeight <= 0) {
      throw StateError('لا يوجد محتوى للطباعة');
    }

    final painter = _BlockPainter(
      canvas: canvas,
      layout: layout,
      threshold: thresholdForDensity(settings.printDensity),
    );
    painter.paint(blocks, totalHeight.toDouble());

    final picture = recorder.endRecording();
    // The colour raster is only needed to derive the packed 1-bit buffer, so
    // it is released as soon as that buffer exists. The on-screen preview is
    // rebuilt from the packed buffer on demand, which keeps the two views
    // identical without holding the large intermediate alive.
    final ui.Image raster;
    try {
      raster = await picture.toImage(width, totalHeight);
    } finally {
      picture.dispose();
    }

    try {
      final rgba = await raster.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) {
        throw StateError('تعذر تجهيز محتوى الطباعة');
      }

      final source = img.Image.fromBytes(
        width: width,
        height: totalHeight,
        bytes: rgba.buffer,
        numChannels: 4,
      );
      final plane = extractLuminance(source);
      diffuseError(
        plane,
        thresholdLevel: thresholdForDensity(settings.printDensity),
      );

      return RasterizedReceipt(
        bitmapData: packOneBit(plane),
        width: width,
        height: totalHeight,
      );
    } finally {
      raster.dispose();
    }
  }

  /// Renders a single line of text as its own raster. Used by the test print
  /// button and by the "print this line" action.
  static Future<Uint8List> renderTextLine(
    String text, {
    required PrinterSettings settings,
    ReceiptAlign align = ReceiptAlign.center,
    bool bold = true,
  }) async {
    final document = ReceiptDocument(
      lines: <ReceiptLine>[
        ReceiptLine.text(text, align: align, bold: bold, inverse: true),
      ],
    );
    final result = await render(document, settings: settings);
    return Uint8List.fromList(result.bitmapData);
  }

  // -------------------------------------------------------------------
  // Layout
  // -------------------------------------------------------------------

  static List<_Block> _buildBlocks(ReceiptDocument document, _Layout layout) {
    final blocks = <_Block>[];

    if (document.header.trim().isNotEmpty) {
      blocks.add(
        _TextBlock(
          text: document.header.trim(),
          fontSize: layout.fontSize * 1.35,
          bold: true,
          align: ReceiptAlign.center,
        ),
      );
    }

    final sub = document.subHeader;
    if (sub != null && sub.trim().isNotEmpty) {
      blocks.add(
        _TextBlock(
          text: sub.trim(),
          fontSize: layout.fontSize * 0.82,
          bold: false,
          align: ReceiptAlign.center,
        ),
      );
    }

    if (document.header.trim().isNotEmpty ||
        (sub?.trim().isNotEmpty ?? false)) {
      blocks.add(const _SpaceBlock(factor: 0.4));
      blocks.add(const _RuleBlock(ReceiptRule.dashed));
    }

    for (final line in document.lines) {
      blocks.addAll(_blocksForLine(line, layout));
    }

    final footer = document.footer;
    if (footer != null && footer.trim().isNotEmpty) {
      blocks.add(const _RuleBlock(ReceiptRule.dashed));
      blocks.add(
        _TextBlock(
          text: footer.trim(),
          fontSize: layout.fontSize * 0.78,
          bold: false,
          align: ReceiptAlign.center,
        ),
      );
    }

    return blocks;
  }

  static List<_Block> _blocksForLine(ReceiptLine line, _Layout layout) {
    if (line.rule != null) {
      return <_Block>[
        const _SpaceBlock(factor: 0.25),
        _RuleBlock(line.rule!, thickness: line.height ?? 1),
        const _SpaceBlock(factor: 0.25),
      ];
    }

    final scale = line.scale;
    final weightStep = line.densityBoost ? 100 : 0;
    final blocks = <_Block>[];

    final value = line.value;
    if (value != null && value.isNotEmpty) {
      blocks.add(
        _KeyValueBlock(
          label: line.text,
          value: value,
          labelFontSize: layout.fontSize * scale,
          valueFontSize: layout.fontSize * scale,
          labelBold: line.bold,
          valueBold: line.bold,
          labelAlign: line.align,
          valueAlign: line.valueAlign,
          inverse: line.inverse,
          weightBoost: weightStep,
          lineHeight: line.height,
        ),
      );
    } else {
      blocks.add(
        _TextBlock(
          text: line.text,
          fontSize: layout.fontSize * scale,
          bold: line.bold,
          align: line.align,
          inverse: line.inverse,
          weightBoost: weightStep,
          lineHeight: line.height,
        ),
      );
    }

    if (line.inverse) {
      blocks.insert(0, const _SpaceBlock(factor: 0.2));
      blocks.add(const _SpaceBlock(factor: 0.2));
    } else {
      blocks.add(const _SpaceBlock(factor: 0.12));
    }

    return blocks;
  }

  static int _totalHeight(List<_Block> blocks, _Layout layout) {
    var height = 0.0;
    for (final block in blocks) {
      height += block.measure();
    }
    return math.max(1, height.ceil());
  }
}

/// Fixed measurements derived from the printhead width.
class _Layout {
  const _Layout({
    required this.width,
    required this.columns,
    required this.fontSize,
    required this.padding,
    required this.gap,
  });

  factory _Layout.forWidth(int width, int columns) {
    final padding = math.max(4, (width * 0.025).round());
    final cell = width / columns;
    return _Layout(
      width: width,
      columns: columns,
      // Two character cells tall, matching the classic 24 dot CJK cell.
      fontSize: math.max(9.0, cell * 2.0),
      padding: padding,
      gap: math.max(2.0, cell * 0.35),
    );
  }

  final int width;
  final int columns;
  final double fontSize;
  final int padding;
  final double gap;
}

/// An element of the receipt, already measured for the target width.
abstract class _Block {
  const _Block();

  double measure();

  void paint(Canvas canvas, double top, _Layout layout, _PaintState state);
}

class _PaintState {
  _PaintState(this.threshold);

  final int threshold;
}

class _SpaceBlock extends _Block {
  const _SpaceBlock({required this.factor});

  final double factor;

  @override
  double measure() => factor * 20;

  @override
  void paint(Canvas canvas, double top, _Layout layout, _PaintState state) {}
}

class _RuleBlock extends _Block {
  const _RuleBlock(this.rule, {this.thickness = 1});

  final ReceiptRule rule;
  final double thickness;

  @override
  double measure() => thickness;

  @override
  void paint(Canvas canvas, double top, _Layout layout, _PaintState state) {
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;
    final y = top + thickness / 2;
    final left = layout.padding.toDouble();
    final right = (layout.width - layout.padding).toDouble();

    switch (rule) {
      case ReceiptRule.solid:
        canvas.drawLine(Offset(left, y), Offset(right, y), paint);
      case ReceiptRule.dashed:
        const dash = 6.0;
        const gap = 4.0;
        for (double x = left; x < right; x += dash + gap) {
          canvas.drawLine(
            Offset(x, y),
            Offset(math.min(x + dash, right), y),
            paint,
          );
        }
      case ReceiptRule.double:
        canvas.drawLine(Offset(left, y), Offset(right, y), paint);
        canvas.drawLine(
          Offset(left, y + thickness * 2),
          Offset(right, y + thickness * 2),
          paint,
        );
    }
  }
}

class _TextBlock extends _Block {
  _TextBlock({
    required this.text,
    required this.fontSize,
    required this.bold,
    required this.align,
    this.inverse = false,
    this.weightBoost = 0,
    this.lineHeight,
  }) : direction = ReceiptRasterizer.isRtl(text)
           ? TextDirection.rtl
           : TextDirection.ltr,
       _painter = null;

  final String text;
  final double fontSize;
  final bool bold;
  final ReceiptAlign align;
  final bool inverse;
  final int weightBoost;
  final double? lineHeight;
  final TextDirection direction;

  TextPainter? _painter;

  TextPainter _layoutPainter(double maxWidth) {
    final existing = _painter;
    if (existing != null) return existing;
    final created = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: _weight(bold, weightBoost),
          color: inverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          height: 1.15,
        ),
      ),
      textDirection: direction,
      textAlign: _textAlign(align),
    )..layout(maxWidth: maxWidth);
    _painter = created;
    return created;
  }

  @override
  double measure() {
    final painter = _layoutPainter(double.infinity);
    return lineHeight ?? painter.height;
  }

  @override
  void paint(Canvas canvas, double top, _Layout layout, _PaintState state) {
    final painter = _layoutPainter(
      (layout.width - layout.padding * 2).toDouble(),
    );

    if (inverse) {
      canvas.drawRect(
        Rect.fromLTWH(
          0,
          top,
          layout.width.toDouble(),
          lineHeight ?? painter.height,
        ),
        Paint()..color = const Color(0xFF000000),
      );
    }

    painter.paint(canvas, Offset(0, top));
  }
}

class _KeyValueBlock extends _Block {
  _KeyValueBlock({
    required this.label,
    required this.value,
    required this.labelFontSize,
    required this.valueFontSize,
    required this.labelBold,
    required this.valueBold,
    required this.labelAlign,
    required this.valueAlign,
    required this.inverse,
    required this.weightBoost,
    this.lineHeight,
  }) {
    _labelPainter = _build(label, labelFontSize, labelBold, labelAlign);
    _valuePainter = _build(value, valueFontSize, valueBold, valueAlign);
  }

  final String label;
  final String value;
  final double labelFontSize;
  final double valueFontSize;
  final bool labelBold;
  final bool valueBold;
  final ReceiptAlign labelAlign;
  final ReceiptAlign valueAlign;
  final bool inverse;
  final int weightBoost;
  final double? lineHeight;

  late final TextPainter _labelPainter;
  late final TextPainter _valuePainter;

  TextPainter _build(
    String text,
    double size,
    bool isBold,
    ReceiptAlign align,
  ) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: _weight(isBold, weightBoost),
          color: inverse ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          height: 1.15,
        ),
      ),
      textDirection: ReceiptRasterizer.isRtl(text)
          ? TextDirection.rtl
          : TextDirection.ltr,
      textAlign: _textAlign(align),
    )..layout(maxWidth: double.infinity);
  }

  @override
  double measure() {
    final natural = math.max(_labelPainter.height, _valuePainter.height);
    return lineHeight ?? natural;
  }

  @override
  void paint(Canvas canvas, double top, _Layout layout, _PaintState state) {
    final height = lineHeight ?? measure();
    if (inverse) {
      canvas.drawRect(
        Rect.fromLTWH(0, top, layout.width.toDouble(), height),
        Paint()..color = const Color(0xFF000000),
      );
    }

    final contentWidth = (layout.width - layout.padding * 2).toDouble();

    // Shrink the value column first if the two labels would collide, then let
    // the label ellipsize. Prices must stay legible.
    var labelWidth = _labelPainter.width;
    var valueWidth = _valuePainter.width;
    final overflow = labelWidth + valueWidth - contentWidth;
    if (overflow > 0) {
      final reducible = valueWidth - (contentWidth * 0.35);
      if (reducible > 0) {
        valueWidth -= reducible;
        _valuePainter.layout(maxWidth: valueWidth);
      }
      labelWidth = math.max(0.0, contentWidth - valueWidth);
      _labelPainter.layout(maxWidth: labelWidth);
    }

    _labelPainter.paint(
      canvas,
      Offset(
        _xFor(labelAlign, contentWidth, labelWidth, layout),
        top + (height - _labelPainter.height) / 2,
      ),
    );
    _valuePainter.paint(
      canvas,
      Offset(
        _xFor(valueAlign, contentWidth, _valuePainter.width, layout),
        top + (height - _valuePainter.height) / 2,
      ),
    );
  }
}

/// Lays a single line out as a full-width band so key/value rows and inverse
/// bands share one code path.
class _BlockPainter {
  _BlockPainter({
    required this.canvas,
    required this.layout,
    required this.threshold,
  });

  final Canvas canvas;
  final _Layout layout;
  final int threshold;

  void paint(List<_Block> blocks, double totalHeight) {
    final state = _PaintState(threshold);
    var top = 0.0;
    for (final block in blocks) {
      block.paint(canvas, top, layout, state);
      top += block.measure();
    }
    if (top < totalHeight) {
      // Paper continues to the end of the cut, filled with feed lines.
      canvas.drawRect(
        Rect.fromLTWH(0, top, layout.width.toDouble(), totalHeight - top),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }
}

FontWeight _weight(bool bold, int boost) {
  final step = (bold ? 1 : 0) + (boost > 0 ? 1 : 0);
  return switch (step) {
    0 => FontWeight.w400,
    1 => FontWeight.w600,
    _ => FontWeight.w700,
  };
}

TextAlign _textAlign(ReceiptAlign align) => switch (align) {
  ReceiptAlign.start => TextAlign.start,
  ReceiptAlign.end => TextAlign.end,
  ReceiptAlign.center => TextAlign.center,
};

/// Maps a logical edge onto a physical x offset inside the content column,
/// honouring the text direction of the block being placed.
double _xFor(
  ReceiptAlign align,
  double contentWidth,
  double blockWidth,
  _Layout layout,
) {
  final left = layout.padding.toDouble();
  final usable = math.max(0.0, contentWidth);
  return switch (align) {
    ReceiptAlign.start => left,
    ReceiptAlign.end => left + usable - blockWidth,
    ReceiptAlign.center => left + (usable - blockWidth) / 2,
  };
}
