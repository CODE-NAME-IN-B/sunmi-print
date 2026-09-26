import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as spp;
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

enum PrinterConnectionStatus {
  connected,
  disconnected,
  noPaper,
  overheat,
  error,
}

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  PrinterConnectionStatus _status = PrinterConnectionStatus.disconnected;
  BluetoothDevice? _bleDevice;
  BluetoothCharacteristic? _bleChar;
  bool _isUsingBle = false;

  spp.BluetoothConnection? _sppConnection;
  String _sppDeviceName = '';
  String _sppDeviceAddress = '';
  bool _isUsingSpp = false;

  PrinterConnectionStatus get status => _status;
  bool get isConnected {
    if (_isUsingSpp) return _sppConnection?.isConnected == true;
    if (_isUsingBle) return _bleDevice?.isConnected == true;
    return _status == PrinterConnectionStatus.connected;
  }
  bool get isUsingBle => _isUsingBle;
  bool get isUsingSpp => _isUsingSpp;
  BluetoothDevice? get bleDevice => _bleDevice;
  String get sppDeviceName => _sppDeviceName;
  String get sppDeviceAddress => _sppDeviceAddress;

  final StreamController<PrinterConnectionStatus> _statusController =
      StreamController<PrinterConnectionStatus>.broadcast();

  Stream<PrinterConnectionStatus> get statusStream => _statusController.stream;

  static const Duration _printTimeout = Duration(seconds: 30);
  static const Duration _statusTimeout = Duration(seconds: 10);

  void setBleDevice(BluetoothDevice device) {
    _bleDevice = device;
    _isUsingBle = true;
    _bleChar = null; // Reset cached char, will discover on first print
    _status = PrinterConnectionStatus.connected;
    _statusController.add(_status);
  }

  void clearBleDevice() {
    _bleDevice = null;
    _bleChar = null;
    _isUsingBle = false;
    _status = PrinterConnectionStatus.disconnected;
    _statusController.add(_status);
  }

  void setSppConnection(spp.BluetoothConnection connection, String deviceName, {String address = ''}) {
    _sppConnection = connection;
    _sppDeviceName = deviceName;
    _sppDeviceAddress = address;
    _isUsingSpp = true;
    _status = PrinterConnectionStatus.connected;
    _statusController.add(_status);
  }

  void clearSppConnection() {
    _sppConnection?.dispose();
    _sppConnection = null;
    _sppDeviceName = '';
    _sppDeviceAddress = '';
    _isUsingSpp = false;
    _status = PrinterConnectionStatus.disconnected;
    _statusController.add(_status);
  }

  Future<bool> reconnectSpp() async {
    if (_sppDeviceAddress.isEmpty) return false;
    try {
      final connection = await spp.BluetoothConnection.toAddress(_sppDeviceAddress);
      _sppConnection?.dispose();
      _sppConnection = connection;
      _isUsingSpp = true;
      _status = PrinterConnectionStatus.connected;
      _statusController.add(_status);
      return true;
    } catch (e) {
      debugPrint('PrinterService: SPP reconnect failed: $e');
      _sppConnection = null;
      _status = PrinterConnectionStatus.disconnected;
      _statusController.add(_status);
      return false;
    }
  }

  Future<BluetoothCharacteristic?> _getBleChar() async {
    if (_bleChar != null) return _bleChar;
    if (_bleDevice == null) return null;
    try {
      final services = await _bleDevice!.discoverServices();
      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.write) {
            _bleChar = char;
            return char;
          }
        }
      }
    } catch (e) {
      debugPrint('PrinterService: Failed to discover BLE services: $e');
    }
    return null;
  }

  Future<bool> initialize() async {
    try {
      final bound = await SunmiPrinterPlus().rebindPrinter();
      if (bound) {
        await _updateStatus();
        return true;
      }
    } catch (e) {
      _status = PrinterConnectionStatus.disconnected;
      _statusController.add(_status);
    }
    return false;
  }

  Future<String> getPrinterWidth() async {
    try {
      final paper = await SunmiConfig.getPaper();
      if (paper != null) {
        if (paper.contains('58') || paper.contains('57')) return 'mm58';
        if (paper.contains('80')) return 'mm80';
      }
    } catch (e) {
      debugPrint('PrinterService: Failed to detect printer width: $e');
    }
    return 'mm58';
  }

  Future<bool> printImage({
    required Uint8List bitmapData,
    int copies = 1,
  }) async {
    if (!isConnected) return false;

    try {
      for (int i = 0; i < copies; i++) {
        if (_isUsingSpp && _sppConnection != null) {
          await _printImageSpp(bitmapData);
        } else if (_isUsingBle && _bleDevice != null) {
          await _printImageBle(bitmapData);
        } else {
          await SunmiPrinter.printImage(bitmapData).timeout(_printTimeout);
        }
        if (i < copies - 1) {
          if (_isUsingSpp && _sppConnection != null) {
            await _lineWrapSpp(1);
          } else if (_isUsingBle && _bleDevice != null) {
            await _lineWrapBle(1);
          } else {
            await SunmiPrinter.lineWrap(1);
          }
        }
      }
      return true;
    } on TimeoutException {
      if (!_isUsingBle && !_isUsingSpp) {
        _status = PrinterConnectionStatus.disconnected;
        _statusController.add(_status);
      }
      return false;
    } catch (e) {
      if (!_isUsingBle && !_isUsingSpp) {
        await _updateStatus();
      }
      return false;
    }
  }

  Future<bool> printText(String text,
      {SunmiPrintAlign align = SunmiPrintAlign.LEFT}) async {
    try {
      if (_isUsingSpp && _sppConnection != null) {
        await _printTextSpp(text);
      } else if (_isUsingBle && _bleDevice != null) {
        await _printTextBle(text);
      } else {
        await SunmiPrinter.printText(text,
            style: SunmiTextStyle(align: align)).timeout(_printTimeout);
      }
      return true;
    } on TimeoutException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> printQRCode(String data,
      {int size = 4}) async {
    try {
      if (_isUsingSpp && _sppConnection != null) {
        await _printQRCodeSpp(data, size: size);
      } else if (_isUsingBle && _bleDevice != null) {
        await _printQRCodeBle(data, size: size);
      } else {
        await SunmiPrinter.printQRCode(data,
            style: SunmiQrcodeStyle(qrcodeSize: size)).timeout(_printTimeout);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> printBarcode(String data) async {
    try {
      if (_isUsingSpp && _sppConnection != null) {
        await _printBarcodeSpp(data);
      } else if (_isUsingBle && _bleDevice != null) {
        await _printBarcodeBle(data);
      } else {
        await SunmiPrinter.printBarCode(data).timeout(_printTimeout);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> lineWrap(int lines) async {
    try {
      if (_isUsingSpp && _sppConnection != null) {
        await _lineWrapSpp(lines);
      } else if (_isUsingBle && _bleDevice != null) {
        await _lineWrapBle(lines);
      } else {
        await SunmiPrinter.lineWrap(lines).timeout(_printTimeout);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cutPaper() async {
    try {
      if (_isUsingSpp && _sppConnection != null) {
        await _cutPaperSpp();
      } else if (_isUsingBle && _bleDevice != null) {
        await _cutPaperBle();
      } else {
        await SunmiPrinter.cutPaper().timeout(_printTimeout);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _updateStatus() async {
    try {
      final statusStr = await SunmiConfig.getStatus().timeout(_statusTimeout);
      if (statusStr == null) {
        _status = PrinterConnectionStatus.disconnected;
      } else {
        final lower = statusStr.toLowerCase();
        if (lower.contains('ready') || lower.contains('normal')) {
          _status = PrinterConnectionStatus.connected;
        } else if (lower.contains('paper')) {
          _status = PrinterConnectionStatus.noPaper;
        } else if (lower.contains('hot') || lower.contains('overheat')) {
          _status = PrinterConnectionStatus.overheat;
        } else {
          _status = PrinterConnectionStatus.error;
        }
      }
    } catch (e) {
      _status = PrinterConnectionStatus.disconnected;
    }
    _statusController.add(_status);
  }

  void simulateConnected() {
    _status = PrinterConnectionStatus.connected;
    _statusController.add(_status);
  }

  // ESC/POS BLE printing helpers
  Future<void> _printImageBle(Uint8List bitmapData) async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      // ESC/POS: Initialize
      await char.write([0x1B, 0x40], withoutResponse: true);

      // ESC/POS: Center align
      await char.write([0x1B, 0x61, 0x01], withoutResponse: true);

      // ESC/POS: Set image mode and print bitmap
      final List<int> chunks = [];
      const int bytesPerLine = (384 + 7) ~/ 8;

      chunks.add(0x1D);
      chunks.add(0x76);
      chunks.add(0x30);
      chunks.add(0x00);
      chunks.add(bytesPerLine & 0xFF);
      chunks.add((bytesPerLine >> 8) & 0xFF);
      chunks.add((bitmapData.length ~/ bytesPerLine) & 0xFF);
      chunks.add(((bitmapData.length ~/ bytesPerLine) >> 8) & 0xFF);

      for (final byte in bitmapData) {
        chunks.add(byte);
      }

      // Write in chunks to avoid BLE MTU issues
      const int chunkSize = 20;
      for (int i = 0; i < chunks.length; i += chunkSize) {
        final end = (i + chunkSize < chunks.length) ? i + chunkSize : chunks.length;
        await char.write(chunks.sublist(i, end), withoutResponse: true);
      }

      // ESC/POS: Feed and cut
      await char.write([0x1B, 0x64, 0x03], withoutResponse: true);
    } catch (e) {
      debugPrint('PrinterService: BLE image print failed: $e');
    }
  }

  Future<void> _printTextBle(String text) async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      // ESC/POS: Initialize
      await char.write([0x1B, 0x40], withoutResponse: true);

      // ESC/POS: Left align
      await char.write([0x1B, 0x61, 0x00], withoutResponse: true);

      // ESC/POS: Print text
      final bytes = Uint8List.fromList(text.codeUnits);
      const int chunkSize = 20;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        await char.write(bytes.sublist(i, end), withoutResponse: true);
      }
    } catch (e) {
      debugPrint('PrinterService: BLE text print failed: $e');
    }
  }

  Future<void> _lineWrapBle(int lines) async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      await char.write([0x1B, 0x64, lines], withoutResponse: true);
    } catch (e) {
      debugPrint('PrinterService: BLE line wrap failed: $e');
    }
  }

  Future<void> _cutPaperBle() async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      // ESC/POS: Full cut
      await char.write([0x1D, 0x56, 0x00], withoutResponse: true);
    } catch (e) {
      debugPrint('PrinterService: BLE cut paper failed: $e');
    }
  }

  Future<void> _printQRCodeBle(String data, {int size = 4}) async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      // ESC/POS: Initialize
      await char.write([0x1B, 0x40], withoutResponse: true);

      // ESC/POS: QR Code model
      await char.write([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00], withoutResponse: true);

      // ESC/POS: QR Code size
      await char.write([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size], withoutResponse: true);

      // ESC/POS: QR Code error correction
      await char.write([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30], withoutResponse: true);

      // ESC/POS: Store QR Code data
      final dataBytes = Uint8List.fromList(data.codeUnits);
      final len = dataBytes.length + 3;
      final storeCmd = [0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x30, 0x50, ...dataBytes];
      await char.write(storeCmd, withoutResponse: true);

      // ESC/POS: Print QR Code
      await char.write([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30], withoutResponse: true);
    } catch (e) {
      debugPrint('PrinterService: BLE QR code print failed: $e');
    }
  }

  Future<void> _printBarcodeBle(String data) async {
    final char = await _getBleChar();
    if (char == null) return;

    try {
      // ESC/POS: Initialize
      await char.write([0x1B, 0x40], withoutResponse: true);

      // ESC/POS: HRI text below barcode
      await char.write([0x1D, 0x48, 0x02], withoutResponse: true);

      // ESC/POS: Barcode height
      await char.write([0x1D, 0x68, 50], withoutResponse: true);

      // ESC/POS: Print CODE128 barcode
      final dataBytes = Uint8List.fromList(data.codeUnits);
      final cmd = [0x1D, 0x6B, 0x49, dataBytes.length, ...dataBytes];
      await char.write(cmd, withoutResponse: true);
    } catch (e) {
      debugPrint('PrinterService: BLE barcode print failed: $e');
    }
  }

  // SPP (Serial Port Profile) helpers
  Future<void> _sendSpp(List<int> data) async {
    if (_sppConnection == null) throw Exception('SPP connection not available');
    if (_sppConnection!.isConnected != true) {
      // Attempt reconnect
      final reconnected = await reconnectSpp();
      if (!reconnected || _sppConnection == null) {
        throw Exception('SPP connection lost');
      }
    }
    _sppConnection!.output.add(Uint8List.fromList(data));
    await _sppConnection!.output.allSent;
  }

  Future<void> _printImageSpp(Uint8List bitmapData) async {
    await _sendSpp([0x1B, 0x40]); // Initialize
    await _sendSpp([0x1B, 0x61, 0x01]); // Center align

    const int bytesPerLine = (384 + 7) ~/ 8;
    final header = [
      0x1D, 0x76, 0x30, 0x00,
      bytesPerLine & 0xFF, (bytesPerLine >> 8) & 0xFF,
      (bitmapData.length ~/ bytesPerLine) & 0xFF,
      ((bitmapData.length ~/ bytesPerLine) >> 8) & 0xFF,
    ];
    await _sendSpp(header);
    await _sendSpp(bitmapData);
    await _sendSpp([0x1B, 0x64, 0x03]); // Feed
  }

  Future<void> _printTextSpp(String text) async {
    await _sendSpp([0x1B, 0x40]); // Initialize
    await _sendSpp([0x1B, 0x61, 0x00]); // Left align
    await _sendSpp(text.codeUnits);
  }

  Future<void> _lineWrapSpp(int lines) async {
    await _sendSpp([0x1B, 0x64, lines]);
  }

  Future<void> _cutPaperSpp() async {
    await _sendSpp([0x1D, 0x56, 0x00]); // Full cut
  }

  Future<void> _printQRCodeSpp(String data, {int size = 4}) async {
    await _sendSpp([0x1B, 0x40]); // Initialize
    await _sendSpp([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]); // QR model
    await _sendSpp([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]); // QR size
    await _sendSpp([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]); // Error correction

    final dataBytes = Uint8List.fromList(data.codeUnits);
    final len = dataBytes.length + 3;
    await _sendSpp([0x1D, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x30, 0x50, ...dataBytes]);
    await _sendSpp([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]); // Print QR
  }

  Future<void> _printBarcodeSpp(String data) async {
    await _sendSpp([0x1B, 0x40]); // Initialize
    await _sendSpp([0x1D, 0x48, 0x02]); // HRI below
    await _sendSpp([0x1D, 0x68, 50]); // Height

    final dataBytes = Uint8List.fromList(data.codeUnits);
    await _sendSpp([0x1D, 0x6B, 0x49, dataBytes.length, ...dataBytes]);
  }

  void dispose() {
    _statusController.close();
  }
}
