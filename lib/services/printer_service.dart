import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as spp;
import 'package:hive/hive.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/bitmap_utils.dart';
import '../core/utils/receipt_rasterizer.dart';
import '../models/printer_profile.dart';
import '../models/printer_settings.dart';
import '../models/receipt_document.dart';

/// How the app reaches the printhead.
enum PrinterTransport {
  /// Nothing is connected yet.
  none,

  /// The printer is part of the device, reached over the vendor AIDL service.
  sunmiSdk,

  /// An external printer reached over a Bluetooth Classic RFCOMM socket.
  bluetoothClassic,
}

/// Why a Bluetooth Classic connection attempt failed.
enum BluetoothConnectError {
  unsupported,
  disabled,
  permissionDenied,
  unreachable,
  unknown,
}

/// Outcome of a Bluetooth Classic connection attempt, carrying the number of
/// attempts so the UI can explain a slow success honestly.
class BluetoothConnectResult {
  const BluetoothConnectResult.success(this.attempts)
    : success = true,
      error = null;

  const BluetoothConnectResult.failure(this.error, this.attempts)
    : success = false;

  final bool success;
  final BluetoothConnectError? error;
  final int attempts;

  String get messageAr => switch (error) {
    BluetoothConnectError.unsupported => 'الجهاز لا يدعم البلوتوث',
    BluetoothConnectError.disabled => 'البلوتوث غير مفعّل',
    BluetoothConnectError.permissionDenied =>
      'يرجى منح صلاحيات البلوتوث من إعدادات التطبيق',
    BluetoothConnectError.unreachable =>
      'تعذر الوصول إلى الطابعة — تأكد أنها مقترنة、通ريبة وتشتغل',
    BluetoothConnectError.unknown => 'فشل الاتصال بالطابعة',
    null => '',
  };
}

enum PrinterConnectionStatus {
  connected,
  disconnected,

  /// The head reports no paper.
  noPaper,

  /// The head is above its safe temperature.
  overheat,

  /// Paper is loaded but will not feed.
  paperJam,

  error,
}

/// The single place that knows how bytes reach the printhead.
///
/// Two transports, tried in a fixed order of preference:
///
/// 1. **On-device SDK** (AIDL). A local binder call to the printer service
///    that ships with the device. No Bluetooth stack, no byte encoding, no
///    pairing. This is the fast and reliable path on genuine Sunmi hardware.
/// 2. **Bluetooth Classic** (RFCOMM / SPP). The fallback, used when the SDK is
///    unavailable, when the user explicitly asks for an external printer, and
///    for every non-Sunmi thermal printer.
///
/// Every printable payload crosses both transports as a raster. Text never
/// leaves the app as characters, which is what makes Arabic immune to codepage
/// mismatches.
class PrinterService {
  PrinterService._();

  static final PrinterService instance = PrinterService._();

  // ---------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------

  PrinterConnectionStatus _status = PrinterConnectionStatus.disconnected;
  PrinterTransport _transport = PrinterTransport.none;
  PrinterProfile _profile = const PrinterProfile();

  spp.BluetoothConnection? _sppConnection;
  StreamSubscription<dynamic>? _sppCloseWatch;
  String _sppDeviceName = '';
  String _sppDeviceAddress = '';
  bool _isSending = false;

  final StreamController<PrinterConnectionStatus> _statusController =
      StreamController<PrinterConnectionStatus>.broadcast();
  final StreamController<PrinterTransport> _transportController =
      StreamController<PrinterTransport>.broadcast();
  final StreamController<PrinterProfile> _profileController =
      StreamController<PrinterProfile>.broadcast();

  Stream<PrinterConnectionStatus> get statusStream => _statusController.stream;
  Stream<PrinterTransport> get transportStream => _transportController.stream;
  Stream<PrinterProfile> get profileStream => _profileController.stream;

  PrinterConnectionStatus get status => _status;
  PrinterTransport get transport => _transport;
  PrinterProfile get profile => _profile;
  String get deviceName => _transport == PrinterTransport.sunmiSdk
      ? 'Sunmi المدمجة'
      : _sppDeviceName;
  String get deviceAddress => _sppDeviceAddress;
  SavedPrinter? get savedPrinter => _profile.bluetoothPrinter;
  bool get isUsingSunmiSdk => _transport == PrinterTransport.sunmiSdk;
  bool get isUsingBluetooth => _transport == PrinterTransport.bluetoothClassic;

  /// True when a printhead is reachable, either transport.
  bool get isConnected {
    if (_transport == PrinterTransport.bluetoothClassic) {
      return _sppConnection?.isConnected == true;
    }
    if (_transport == PrinterTransport.sunmiSdk) {
      return _status == PrinterConnectionStatus.connected;
    }
    return false;
  }

  /// A human readable description of the active link, shown in the banner.
  String get transportLabelAr => switch (_transport) {
    PrinterTransport.sunmiSdk => 'الطابعة المدمجة (SDK)',
    PrinterTransport.bluetoothClassic => 'بلوتوث كلاسيكي',
    PrinterTransport.none => 'لا يوجد مسار طباعة',
  };

  // ---------------------------------------------------------------------
  // Startup
  // ---------------------------------------------------------------------

  /// Establishes a print path.
  ///
  /// The on-device SDK is always tried first, silently, because when it works
  /// it removes every failure mode the Bluetooth path has. Bluetooth is only
  /// attempted when the SDK refuses, when no internal printer exists, or when
  /// the user pinned the app to an external printer.
  Future<PrinterTransport> initialize() async {
    await _loadProfile();

    if (_profile.transportPreference != TransportPreference.bluetoothClassic) {
      if (await _tryBindSunmiSdk()) {
        return _transport;
      }
    }

    if (_profile.transportPreference != TransportPreference.sunmiSdk &&
        _profile.hasBluetoothPrinter) {
      final result = await connectBluetooth(
        _profile.bluetoothPrinter!.name,
        _profile.bluetoothPrinter!.address,
        attempts: AppConstants.connectionRetryAttempts,
        persist: false,
      );
      if (result.success) return _transport;
    }

    _setStatus(PrinterConnectionStatus.disconnected);
    _setTransport(PrinterTransport.none);
    return _transport;
  }

  /// AIDL binding. A missing service, an incompatible Android version or an
  /// updated system image all surface here as a `false` or a throw.
  Future<bool> _tryBindSunmiSdk() async {
    try {
      final bound = await SunmiPrinterPlus().rebindPrinter().timeout(
        const Duration(seconds: 6),
      );
      if (bound != true) return false;

      _sppConnection?.dispose();
      _sppConnection = null;
      _sppCloseWatch?.cancel();
      _sppCloseWatch = null;
      _sppDeviceName = '';
      _sppDeviceAddress = '';

      _setTransport(PrinterTransport.sunmiSdk);
      await _updateSunmiStatus();
      // Binding the service is not the same as having a usable printer: the
      // status read above can discover the printhead is unreachable and drop
      // the transport back to none. Reporting success here would stop the
      // caller from falling through to the Bluetooth path.
      return _transport == PrinterTransport.sunmiSdk;
    } catch (e) {
      debugPrint('PrinterService: AIDL binding unavailable: $e');
      return false;
    }
  }

  /// Reads the on-device printer width so the settings screen can preselect a
  /// roll size instead of making the user guess. Returns millimetres, or null
  /// when the vendor service cannot report it.
  Future<int?> detectSunmiPaperWidthMm() async {
    if (_transport != PrinterTransport.sunmiSdk) return null;
    try {
      final paper = await SunmiConfig.getPaper().timeout(
        AppConstants.sunmiStatusTimeout,
      );
      if (paper == null) return null;
      final match = RegExp(r'(\d{2,3})').firstMatch(paper);
      if (match == null) return null;
      final reported = int.tryParse(match.group(1)!);
      if (reported == null || reported < 20 || reported > 120) return null;
      // Roll width in, printable width out.
      return switch (reported) {
        58 => AppConstants.printableWidth58mm,
        80 => AppConstants.printableWidth80mm,
        100 => AppConstants.printableWidth100mm,
        _ => null,
      };
    } catch (e) {
      debugPrint('PrinterService: paper detection failed: $e');
      return null;
    }
  }

  Future<void> _updateSunmiStatus() async {
    if (_transport != PrinterTransport.sunmiSdk) return;
    try {
      final statusStr = await SunmiConfig.getStatus().timeout(
        AppConstants.sunmiStatusTimeout,
      );
      if (statusStr == null) {
        _setStatus(PrinterConnectionStatus.disconnected);
        _setTransport(PrinterTransport.none);
        return;
      }
      final lower = statusStr.toLowerCase();
      if (lower.contains('ready') ||
          lower.contains('normal') ||
          lower.contains('printing') ||
          lower.contains('idle')) {
        _setStatus(PrinterConnectionStatus.connected);
      } else if (lower.contains('paper') || lower.contains('nepaper')) {
        _setStatus(PrinterConnectionStatus.noPaper);
      } else if (lower.contains('hot') ||
          lower.contains('overheat') ||
          lower.contains('thermal')) {
        _setStatus(PrinterConnectionStatus.overheat);
      } else {
        _setStatus(PrinterConnectionStatus.error);
      }
    } catch (e) {
      debugPrint('PrinterService: status read failed: $e');
      _setStatus(PrinterConnectionStatus.disconnected);
      _setTransport(PrinterTransport.none);
    }
  }

  /// Re-reads the on-device printer state. No-op on Bluetooth, where liveness
  /// is observed from the socket.
  Future<void> refreshStatus() async {
    if (_transport == PrinterTransport.sunmiSdk) {
      await _updateSunmiStatus();
    } else if (_transport == PrinterTransport.bluetoothClassic) {
      if (_sppConnection?.isConnected != true) {
        _setStatus(PrinterConnectionStatus.disconnected);
      }
    }
  }

  /// Used by the desktop and test builds where no printhead exists.
  void simulateConnected() {
    _setTransport(PrinterTransport.sunmiSdk);
    _setStatus(PrinterConnectionStatus.connected);
  }

  // ---------------------------------------------------------------------
  // Bluetooth Classic
  // ---------------------------------------------------------------------

  /// Opens an RFCOMM socket to [address].
  ///
  /// The first attempt plus [attempts] - 1 automatic retries. Cheap receipt
  /// printers park their radio in a sleep state and refuse the first channel
  /// open after power on, so a single failed attempt is not evidence that the
  /// printer is unreachable.
  Future<BluetoothConnectResult> connectBluetooth(
    String name,
    String address, {
    int attempts = AppConstants.connectionRetryAttempts,
    bool persist = true,
  }) async {
    if (address.trim().isEmpty) {
      return const BluetoothConnectResult.failure(
        BluetoothConnectError.unreachable,
        0,
      );
    }

    for (int attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _closeSpp();

        final connection = await spp.BluetoothConnection.toAddress(
          address,
        ).timeout(AppConstants.sppCommandTimeout);

        if (connection.isConnected) {
          _sppConnection = connection;
          _sppDeviceName = name.isEmpty ? address : name;
          _sppDeviceAddress = address;
          _watchRemoteClose(connection);

          _setTransport(PrinterTransport.bluetoothClassic);
          _setStatus(PrinterConnectionStatus.connected);

          if (persist) {
            await setBluetoothPrinter(name, address);
            await setTransportPreference(TransportPreference.bluetoothClassic);
          }
          return BluetoothConnectResult.success(attempt);
        }

        await connection.close();
      } catch (e) {
        debugPrint(
          'PrinterService: SPP attempt $attempt to $address failed: $e',
        );
      }

      if (attempt < attempts) {
        // Back off linearly so the second try lands after the radio settles.
        await Future<void>.delayed(AppConstants.connectionRetryDelay * attempt);
      }
    }

    _setStatus(PrinterConnectionStatus.disconnected);
    return BluetoothConnectResult.failure(
      _classifyBluetoothFailure(address),
      attempts,
    );
  }

  BluetoothConnectError _classifyBluetoothFailure(String address) {
    if (!Platform.isAndroid) return BluetoothConnectError.unsupported;
    return BluetoothConnectError.unreachable;
  }

  /// Tears the socket down and reports the printer as gone.
  Future<void> disconnectBluetooth() async {
    await _closeSpp();
    _setTransport(PrinterTransport.none);
    _setStatus(PrinterConnectionStatus.disconnected);
  }

  /// Watches the RFCOMM socket so a printer that is switched off mid job is
  /// noticed immediately instead of surfacing as a silently truncated receipt.
  void _watchRemoteClose(spp.BluetoothConnection connection) {
    _sppCloseWatch?.cancel();
    _sppCloseWatch = connection.input?.listen(
      (_) {},
      onError: (Object _) => _onSppLost(),
      onDone: _onSppLost,
      cancelOnError: true,
    );
  }

  void _onSppLost() {
    if (_transport != PrinterTransport.bluetoothClassic) return;
    debugPrint('PrinterService: RFCOMM socket closed by the remote end');
    _sppConnection = null;
    _sppCloseWatch?.cancel();
    _sppCloseWatch = null;
    _setStatus(PrinterConnectionStatus.disconnected);
  }

  Future<void> _closeSpp() async {
    final connection = _sppConnection;
    _sppConnection = null;
    _sppCloseWatch?.cancel();
    _sppCloseWatch = null;
    if (connection == null) return;
    try {
      await connection.close();
    } catch (_) {
      // The socket is already gone, which is the state we wanted.
    }
  }

  // ---------------------------------------------------------------------
  // Profile persistence
  // ---------------------------------------------------------------------

  Future<void> _loadProfile() async {
    try {
      final box = await Hive.openBox<String>(AppConstants.hiveBoxSettings);
      final raw = box.get(AppConstants.hiveKeyPrinterProfile);
      if (raw != null) {
        _profile = PrinterProfile.decode(raw);
      }
    } catch (e) {
      debugPrint('PrinterService: profile load failed: $e');
    }
    if (!_profileController.isClosed) _profileController.add(_profile);
  }

  Future<void> _persistProfile() async {
    try {
      final box = await Hive.openBox<String>(AppConstants.hiveBoxSettings);
      await box.put(AppConstants.hiveKeyPrinterProfile, _profile.encode());
    } catch (e) {
      debugPrint('PrinterService: profile save failed: $e');
    }
    if (!_profileController.isClosed) _profileController.add(_profile);
  }

  Future<void> setBluetoothPrinter(String name, String address) async {
    _profile = _profile.copyWith(
      bluetoothPrinter: SavedPrinter(
        name: name,
        address: address,
        savedAt: DateTime.now(),
      ),
    );
    await _persistProfile();
  }

  Future<void> forgetBluetoothPrinter() async {
    _profile = _profile.copyWith(clearBluetoothPrinter: true);
    await _persistProfile();
  }

  Future<void> setTransportPreference(TransportPreference preference) async {
    _profile = _profile.copyWith(transportPreference: preference);
    await _persistProfile();
  }

  /// Drops back to the on-device printer, if there is one.
  Future<bool> useSunmiSdk() async {
    await setTransportPreference(TransportPreference.sunmiSdk);
    await _closeSpp();
    return _tryBindSunmiSdk();
  }

  // ---------------------------------------------------------------------
  // Printing
  // ---------------------------------------------------------------------

  /// Prints a 1-bit raster, one bit per dot, [pixelWidth] dots wide.
  ///
  /// [bitmapData] must be packed exactly as [packOneBit] produces it. The
  /// height is derived from the payload length, so a 58mm receipt and a 100mm
  /// receipt of the same content need no extra bookkeeping.
  Future<bool> printRaster({
    required List<int> bitmapData,
    required int pixelWidth,
    int copies = 1,
  }) async {
    if (!isConnected) return false;
    if (bitmapData.isEmpty) return false;

    final bytesPerRow = (pixelWidth + 7) ~/ 8;
    if (bytesPerRow == 0 || bitmapData.length % bytesPerRow != 0) {
      debugPrint(
        'PrinterService: raster length ${bitmapData.length} is not a '
        'multiple of the $bytesPerRow byte row for $pixelWidth dots',
      );
      return false;
    }
    final height = bitmapData.length ~/ bytesPerRow;

    try {
      _isSending = true;
      for (int copy = 0; copy < copies; copy++) {
        final success = _transport == PrinterTransport.bluetoothClassic
            ? await _sendRasterSpp(bitmapData, pixelWidth, height)
            : await _sendRasterSdk(bitmapData, pixelWidth);
        if (!success) return false;

        if (copy < copies - 1) {
          await lineWrap(2);
        }
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: raster print failed: $e');
      return false;
    } finally {
      _isSending = false;
    }
  }

  Future<bool> _sendRasterSdk(List<int> bitmapData, int pixelWidth) async {
    // The vendor SDK runs the payload through BitmapFactory, so the raster is
    // wrapped in a bitmap container instead of being sent as raw dots.
    final bmp = packOneBitBmp(bitmapData, pixelWidth: pixelWidth);
    try {
      final result = await SunmiPrinter.printImage(
        bmp,
        align: SunmiPrintAlign.CENTER,
      ).timeout(AppConstants.printTimeout);
      return result != null && result.toLowerCase() != 'invalid';
    } on TimeoutException {
      _setStatus(PrinterConnectionStatus.disconnected);
      _setTransport(PrinterTransport.none);
      return false;
    } catch (e) {
      debugPrint('PrinterService: SDK raster failed: $e');
      await _updateSunmiStatus();
      return false;
    }
  }

  Future<bool> _sendRasterSpp(
    List<int> bitmapData,
    int pixelWidth,
    int height,
  ) async {
    final bytesPerRow = (pixelWidth + 7) ~/ 8;
    try {
      // ESC @ resets any leftover state from a previous job, then the raster
      // is announced with GS v 0 before the dots follow.
      await _sendSpp(<int>[0x1B, 0x40]);
      await _sendSpp(<int>[0x1B, 0x61, 0x01]); // centre align

      await _sendSpp(<int>[
        0x1D, 0x76, 0x30, 0x00, //
        bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
        height & 0xFF, (height >> 8) & 0xFF,
      ]);
      await _sendSpp(bitmapData);
      await _sendSpp(<int>[0x1B, 0x64, 0x01]); // one line of feed
      return true;
    } catch (e) {
      debugPrint('PrinterService: SPP raster failed: $e');
      _onSppLost();
      return false;
    }
  }

  /// Renders [document] and prints it as a raster, then appends the printer
  /// native QR and barcode symbols.
  ///
  /// The raster path is what makes Arabic print correctly. The QR and barcode
  /// stay as ESC/POS commands because the printhead draws them itself, which
  /// is both crisper and faster than burning dots for them.
  Future<bool> printReceipt(
    ReceiptDocument document, {
    required PrinterSettings settings,
    int copies = 1,
  }) async {
    if (!isConnected) return false;
    if (document.isEmpty) return false;

    try {
      final raster = await ReceiptRasterizer.render(
        document,
        settings: settings,
      );
      final printed = await printRaster(
        bitmapData: raster.bitmapData,
        pixelWidth: raster.width,
        copies: copies,
      );
      if (!printed) return false;

      final qr = document.qrData;
      if (qr != null && qr.trim().isNotEmpty) {
        if (!await printQRCode(qr)) return false;
      }
      final barcode = document.barcodeData;
      if (barcode != null && barcode.trim().isNotEmpty) {
        if (!await printBarcode(barcode)) return false;
      }

      if (settings.autoCut) {
        await cutPaper();
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: receipt print failed: $e');
      return false;
    }
  }

  /// Prints a single line of text. The text is rasterised, never encoded.
  Future<bool> printTextLine(
    String text, {
    required PrinterSettings settings,
    ReceiptAlign align = ReceiptAlign.start,
    bool bold = false,
  }) async {
    if (text.trim().isEmpty) return false;
    if (!isConnected) return false;

    try {
      final raster = await ReceiptRasterizer.render(
        ReceiptDocument(
          lines: <ReceiptLine>[
            ReceiptLine.text(text, align: align, bold: bold),
          ],
        ),
        settings: settings,
      );
      // Awaited, not returned: returning the future from inside a try block
      // lets a print failure escape this catch, and the caller would be told
      // the line printed when it did not.
      return await printRaster(
        bitmapData: raster.bitmapData,
        pixelWidth: raster.width,
      );
    } catch (e) {
      debugPrint('PrinterService: text print failed: $e');
      return false;
    }
  }

  /// Prints a stock test page: identity block, geometry, a dithering ramp and
  /// a QR symbol. Exercises every capability the app relies on.
  Future<bool> printTestPage({required PrinterSettings settings}) async {
    final now = DateTime.now();
    final document = ReceiptDocument(
      header: 'SunmiPrint',
      subHeader: settings.paperPreset == PaperPreset.custom
          ? '${settings.paperWidthMm} مم · ${settings.printerDpi} dpi'
          : '${settings.paperPreset.rollWidthMm} مم · ${settings.printerDpi} dpi',
      lines: <ReceiptLine>[
        const ReceiptLine.rule(ReceiptRule.solid),
        ReceiptLine.keyValue(
          'عرض الطباعة',
          '${settings.pixelWidth} بكسل',
          bold: true,
        ),
        const ReceiptLine.text('اختبار الاتصال والطابعة — انتهى الاختبار'),
        const ReceiptLine.rule(ReceiptRule.dashed),
        const ReceiptLine.text('كثافة الطباعة'),
        const ReceiptLine.text('########  ███  ▓▓▓  ▒▒▒  ····  ....'),
        const ReceiptLine.text('حروف عربية:receipt · Latin 0123456789'),
        const ReceiptLine.rule(ReceiptRule.double),
        ReceiptLine.keyValue(
          '${now.hour.toString().padLeft(2, '0')}:'
              '${now.minute.toString().padLeft(2, '0')}',
          'تم',
          valueAlign: ReceiptAlign.end,
        ),
      ],
      footer: 'شكراً لتعاملكم معنا',
      qrData: 'SUNMIPRINT-TEST:${now.millisecondsSinceEpoch}',
    );

    return printReceipt(document, settings: settings);
  }

  /// Printer generated QR symbol. Byte safe, so it needs no rasterisation.
  Future<bool> printQRCode(String data, {int size = 6}) async {
    if (data.isEmpty) return false;
    final moduleSize = size.clamp(1, 16);
    try {
      if (_transport == PrinterTransport.bluetoothClassic) {
        final bytes = Uint8List.fromList(utf8.encode(data));
        final payloadLength = bytes.length + 3;
        await _sendSpp(<int>[0x1B, 0x40]);
        await _sendSpp(<int>[0x1B, 0x61, 0x01]);
        // Model 2.
        await _sendSpp(<int>[
          0x1D,
          0x28,
          0x6B,
          0x04,
          0x00,
          0x31,
          0x41,
          0x32,
          0x00,
        ]);
        // Module size.
        await _sendSpp(<int>[
          0x1D,
          0x28,
          0x6B,
          0x03,
          0x00,
          0x31,
          0x43,
          moduleSize,
        ]);
        // Error correction level M.
        await _sendSpp(<int>[0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
        // Store the payload, prefixed by the pL/pH length pair.
        await _sendSpp(<int>[
          0x1D,
          0x28,
          0x6B,
          payloadLength & 0xFF,
          (payloadLength >> 8) & 0xFF,
          0x30,
          0x50,
          0x30,
          ...bytes,
        ]);
        // Print from the symbol storage area.
        await _sendSpp(<int>[0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
        await _sendSpp(<int>[0x1B, 0x64, 0x01]);
      } else {
        await SunmiPrinter.printQRCode(
          data,
          style: SunmiQrcodeStyle(qrcodeSize: moduleSize),
        ).timeout(AppConstants.printTimeout);
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: QR print failed: $e');
      return false;
    }
  }

  /// CODE 128 barcode with the human readable digits underneath.
  Future<bool> printBarcode(String data) async {
    if (data.isEmpty) return false;
    final bytes = Uint8List.fromList(utf8.encode(data));
    if (bytes.length > 255) return false;
    try {
      if (_transport == PrinterTransport.bluetoothClassic) {
        await _sendSpp(<int>[0x1B, 0x40]);
        await _sendSpp(<int>[0x1B, 0x61, 0x01]);
        await _sendSpp(<int>[0x1D, 0x48, 0x02]); // readable text below
        await _sendSpp(<int>[0x1D, 0x68, 60]); // bar height
        await _sendSpp(<int>[0x1D, 0x77, 0x02]); // module width
        await _sendSpp(<int>[0x1D, 0x48, 0x02]);
        await _sendSpp(<int>[0x1D, 0x6B, 0x49, bytes.length, ...bytes]);
        await _sendSpp(<int>[0x1B, 0x64, 0x01]);
      } else {
        await SunmiPrinter.printBarCode(
          data,
        ).timeout(AppConstants.printTimeout);
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: barcode print failed: $e');
      return false;
    }
  }

  /// Advances the paper by [lines] rows.
  Future<bool> lineWrap(int lines) async {
    final count = lines.clamp(0, 10);
    if (count == 0) return true;
    try {
      if (_transport == PrinterTransport.bluetoothClassic) {
        await _sendSpp(<int>[0x1B, 0x64, count]);
      } else {
        await SunmiPrinter.lineWrap(count).timeout(AppConstants.printTimeout);
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: line feed failed: $e');
      return false;
    }
  }

  /// Feeds [dots] horizontal motion units, used to position a cut.
  Future<bool> feed(int dots) async {
    final count = dots.clamp(0, 255);
    try {
      if (_transport == PrinterTransport.bluetoothClassic) {
        await _sendSpp(<int>[0x1B, 0x4A, count]);
      } else {
        await SunmiPrinter.lineWrap(
          (count / 203).ceil().clamp(1, 10),
        ).timeout(AppConstants.printTimeout);
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: feed failed: $e');
      return false;
    }
  }

  /// Cuts the receipt.
  ///
  /// A short feed runs first because most cheap mechanisms need the paper past
  /// the cutter bar before the blade engages.
  Future<bool> cutPaper() async {
    try {
      if (_transport == PrinterTransport.bluetoothClassic) {
        await _sendSpp(<int>[0x1B, 0x64, 0x04]);
        await _sendSpp(<int>[0x1D, 0x56, 0x42]); // feed then full cut
      } else {
        await SunmiPrinter.cutPaper().timeout(AppConstants.printTimeout);
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService: cut failed: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------
  // Raw Bluetooth writes
  // ---------------------------------------------------------------------

  /// Writes [data] to the RFCOMM socket in printer-sized chunks.
  ///
  /// Cheap thermal printers have a small input buffer; a single write larger
  /// than that overflows it and the job is silently lost. Chunking with a short
  /// pause between packets is the equivalent of RawBT's "delay between
  /// packets" setting, applied automatically.
  Future<void> _sendSpp(List<int> data) async {
    final connection = _sppConnection;
    if (connection == null || connection.isConnected != true) {
      throw const _SppDisconnectedException();
    }

    if (data.isEmpty) return;
    if (data.length <= AppConstants.sppChunkSize) {
      connection.output.add(Uint8List.fromList(data));
      await connection.output.allSent;
      return;
    }

    for (
      int offset = 0;
      offset < data.length;
      offset += AppConstants.sppChunkSize
    ) {
      // Re-check on every chunk: a printer switched off mid job must abort the
      // transfer instead of printing a truncated receipt.
      if (connection.isConnected != true) {
        throw const _SppDisconnectedException();
      }
      final end = math.min(offset + AppConstants.sppChunkSize, data.length);
      connection.output.add(Uint8List.fromList(data.sublist(offset, end)));
      await connection.output.allSent;
      await Future<void>.delayed(AppConstants.sppChunkDelay);
    }
  }

  // ---------------------------------------------------------------------
  // Status plumbing
  // ---------------------------------------------------------------------

  void _setStatus(PrinterConnectionStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  void _setTransport(PrinterTransport transport) {
    if (_transport == transport) return;
    _transport = transport;
    if (!_transportController.isClosed) _transportController.add(transport);
  }

  /// Exposed for the queue screen, which disables actions mid transfer.
  bool get isSending => _isSending;

  void dispose() {
    _sppCloseWatch?.cancel();
    _sppConnection?.dispose();
    _sppConnection = null;
    _statusController.close();
    _transportController.close();
    _profileController.close();
  }
}

/// Raised internally when the RFCOMM socket disappears mid job.
class _SppDisconnectedException implements Exception {
  const _SppDisconnectedException();

  @override
  String toString() => 'Bluetooth connection lost';
}
