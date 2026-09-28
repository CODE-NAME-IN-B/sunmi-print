import 'package:flutter/widgets.dart';

/// Where a receipt line sits on the printed page.
enum ReceiptAlign { start, end, center }

/// Horizontal rule variants supported by thermal printers.
enum ReceiptRule { solid, dashed, double }

/// One drawn line of a receipt.
///
/// A line is either free text ([text]) or a label/value pair laid out on a
/// single baseline — the classic thermal layout where the item description hugs
/// the reading edge and the amount hugs the opposite one.
@immutable
class ReceiptLine {
  const ReceiptLine.text(
    this.text, {
    this.align = ReceiptAlign.start,
    this.bold = false,
    this.scale = 1.0,
    this.densityBoost = false,
    this.inverse = false,
  }) : value = null,
       valueAlign = ReceiptAlign.end,
       rule = null,
       height = null;

  const ReceiptLine.keyValue(
    this.text,
    this.value, {
    this.align = ReceiptAlign.start,
    this.valueAlign = ReceiptAlign.end,
    this.bold = false,
    this.scale = 1.0,
    this.densityBoost = false,
    this.inverse = false,
  }) : rule = null,
       height = null;

  const ReceiptLine.rule(this.rule, {this.height = 1, this.inverse = false})
    : text = '',
      value = null,
      align = ReceiptAlign.start,
      valueAlign = ReceiptAlign.end,
      bold = false,
      scale = 1.0,
      densityBoost = false;

  final String text;
  final String? value;
  final ReceiptAlign align;
  final ReceiptAlign valueAlign;
  final ReceiptRule? rule;
  final bool bold;
  final double scale;

  /// Draws this line as a filled black band with reversed-out text. Used for
  /// the grand total so it survives dithering on a thermal head.
  final bool inverse;

  /// Bumps the line one weight step, independent of the document density.
  final bool densityBoost;

  /// Explicit line height in dots, overriding the automatic layout.
  final double? height;
}

/// A printable receipt, independent of any transport.
///
/// Building the document separately from the raster is what lets the same
/// content be previewed on screen, sent as a raster over Bluetooth Classic, or
/// handed to the on-device SDK without duplicating layout code.
@immutable
class ReceiptDocument {
  const ReceiptDocument({
    this.header = '',
    this.subHeader,
    this.lines = const <ReceiptLine>[],
    this.footer,
    this.qrData,
    this.barcodeData,
  });

  /// Large centred store name.
  final String header;

  /// Small centred address, phone or tax number.
  final String? subHeader;

  final List<ReceiptLine> lines;

  final String? footer;

  /// Rendered as a printer-native QR symbol after the raster, never as dots.
  final String? qrData;

  /// Rendered as a printer-native barcode after the raster.
  final String? barcodeData;

  bool get isEmpty =>
      header.isEmpty &&
      (subHeader ?? '').isEmpty &&
      lines.isEmpty &&
      (footer ?? '').isEmpty &&
      (qrData ?? '').isEmpty &&
      (barcodeData ?? '').isEmpty;

  ReceiptDocument copyWith({
    String? header,
    String? subHeader,
    List<ReceiptLine>? lines,
    String? footer,
    String? qrData,
    String? barcodeData,
  }) {
    return ReceiptDocument(
      header: header ?? this.header,
      subHeader: subHeader ?? this.subHeader,
      lines: lines ?? this.lines,
      footer: footer ?? this.footer,
      qrData: qrData ?? this.qrData,
      barcodeData: barcodeData ?? this.barcodeData,
    );
  }
}

/// Rendered geometry of a receipt, reused by the on-screen preview so the
/// preview and the printout are guaranteed to share the same proportions.
///
/// Only the packed 1-bit buffer is retained. The colour raster that produced
/// it is several megabytes for a long receipt, so it is released as soon as
/// this object exists; anything that needs to display the page rebuilds it with
/// `unpackOneBitToPng`, which is also exactly the data that goes to the
/// printhead.
@immutable
class RasterizedReceipt {
  const RasterizedReceipt({
    required this.bitmapData,
    required this.width,
    required this.height,
  });

  /// 1-bit buffer, one bit per dot, ready for ESC/POS `GS v 0`.
  final List<int> bitmapData;

  final int width;
  final int height;
}
