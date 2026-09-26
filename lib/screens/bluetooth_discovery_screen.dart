import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as spp;
import '../services/printer_service.dart';

class ClassicBluetoothDevice {
  final String name;
  final String address;
  final String type;
  final String bondState;
  final bool isPaired;

  ClassicBluetoothDevice({
    required this.name,
    required this.address,
    required this.type,
    required this.bondState,
    required this.isPaired,
  });

  factory ClassicBluetoothDevice.fromMap(Map<dynamic, dynamic> map) {
    return ClassicBluetoothDevice(
      name: map['name']?.toString() ?? 'Unknown',
      address: map['address']?.toString() ?? '',
      type: map['type']?.toString() ?? 'unknown',
      bondState: map['bondState']?.toString() ?? 'none',
      isPaired: map['isPaired'] == true,
    );
  }
}

class BluetoothDiscoveryScreen extends ConsumerStatefulWidget {
  const BluetoothDiscoveryScreen({super.key});

  @override
  ConsumerState<BluetoothDiscoveryScreen> createState() => _BluetoothDiscoveryScreenState();
}

class _BluetoothDiscoveryScreenState extends ConsumerState<BluetoothDiscoveryScreen> {
  static const _methodChannel = MethodChannel('com.sunmiprint.app/bluetooth');
  static const _eventChannel = EventChannel('com.sunmiprint.app/bluetooth/events');

  bool _isScanning = false;
  bool _isBluetoothOn = false;
  bool _isPairing = false;
  final List<ClassicBluetoothDevice> _devices = [];
  String? _error;
  ClassicBluetoothDevice? _connectedDevice;
  spp.BluetoothConnection? _connection;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _connection = null;
    _connectedDevice = null;
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    try {
      final isEnabled = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      if (mounted) {
        setState(() {
          _isBluetoothOn = isEnabled ?? false;
          if (!_isBluetoothOn) {
            _error = 'يرجى تفعيل Bluetooth';
          }
        });
      }
    } catch (e) {
      debugPrint('BluetoothDiscovery: Failed to check state: $e');
    }
  }

  Future<void> _turnOnBluetooth() async {
    try {
      await _methodChannel.invokeMethod('enableBluetooth');
      // Wait a moment for Bluetooth to enable
      await Future.delayed(const Duration(seconds: 1));
      await _initBluetooth();
    } catch (e) {
      debugPrint('BluetoothDiscovery: Failed to turn on: $e');
    }
  }

  void _listenToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (!mounted) return;
        final map = event as Map<dynamic, dynamic>;
        final eventName = map['event']?.toString();

        switch (eventName) {
          case 'paired':
            final devices = (map['devices'] as List<dynamic>?) ?? [];
            setState(() {
              for (final d in devices) {
                final device = ClassicBluetoothDevice.fromMap(d);
                if (!_devices.any((existing) => existing.address == device.address)) {
                  _devices.add(device);
                }
              }
            });
            break;

          case 'deviceFound':
            final deviceMap = map['device'] as Map<dynamic, dynamic>?;
            if (deviceMap != null) {
              final device = ClassicBluetoothDevice.fromMap(deviceMap);
              final alreadyExists = _devices.any((d) => d.address == device.address);
              if (!alreadyExists) {
                setState(() {
                  _devices.add(device);
                });
              }
            }
            break;

          case 'discoveryStarted':
            debugPrint('BluetoothDiscovery: Discovery started');
            break;

          case 'discoveryFinished':
            debugPrint('BluetoothDiscovery: Discovery finished');
            if (mounted) {
              setState(() => _isScanning = false);
            }
            break;

          case 'bondStateChanged':
            final address = map['address']?.toString();
            final bondState = map['bondState']?.toString();
            if (address != null && bondState != null) {
              setState(() {
                final index = _devices.indexWhere((d) => d.address == address);
                if (index != -1) {
                  final old = _devices[index];
                  _devices[index] = ClassicBluetoothDevice(
                    name: old.name,
                    address: old.address,
                    type: old.type,
                    bondState: bondState,
                    isPaired: bondState == 'bonded',
                  );
                }
              });
            }
            break;
        }
      },
      onError: (error) {
        debugPrint('BluetoothDiscovery: Event error: $error');
      },
    );
  }

  Future<void> _scan() async {
    if (_isScanning) return;

    if (!_isBluetoothOn) {
      await _turnOnBluetooth();
      if (!_isBluetoothOn) return;
    }

    setState(() {
      _isScanning = true;
      _error = null;
      _devices.clear();
    });

    _listenToEvents();

    try {
      await _methodChannel.invokeMethod('startDiscovery');
    } on PlatformException catch (e) {
      debugPrint('BluetoothDiscovery: Platform error: $e');
      if (mounted) {
        String userMessage;
        switch (e.code) {
          case 'PERMISSION_DENIED':
            userMessage = 'يرجى منح صلاحيات Bluetooth من إعدادات الجهاز';
            break;
          case 'BLUETOOTH_OFF':
            userMessage = 'يرجى تفعيل Bluetooth';
            _isBluetoothOn = false;
            break;
          case 'NO_BLUETOOTH':
            userMessage = 'الجهاز لا يدعم Bluetooth';
            break;
          default:
            userMessage = 'خطأ في Bluetooth: ${e.message}';
        }
        setState(() => _error = userMessage);
      }
    } catch (e) {
      debugPrint('BluetoothDiscovery: Scan error: $e');
      if (mounted) {
        setState(() => _error = 'خطأ في البحث: $e');
      }
    }
  }

  Future<bool> _pairDevice(ClassicBluetoothDevice device) async {
    if (device.isPaired) return true;

    try {
      setState(() {
        _error = null;
        _isPairing = true;
      });
      final result = await _methodChannel.invokeMethod<bool>('pairDevice', {
        'address': device.address,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('BluetoothDiscovery: Pairing failed: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('BOND_FAILED') || errorMsg.contains('Pairing failed')) {
          errorMsg = 'فشل الاقتران - يرجى المحاولة مرة أخرى';
        }
        setState(() => _error = 'خطأ في الاقتران: $errorMsg');
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isPairing = false);
      }
    }
  }

  Future<void> _connectToDevice(ClassicBluetoothDevice device) async {
    try {
      setState(() => _error = null);

      // Cancel any ongoing discovery before connecting (RFCOMM requires this)
      try {
        await _methodChannel.invokeMethod('cancelDiscovery');
      } catch (_) {}

      // Pair/bond the device first if not already paired
      if (!device.isPaired) {
        final paired = await _pairDevice(device);
        if (!paired) {
          if (mounted) {
            setState(() => _error = 'يرجى الاقتران بالطابعة أولاً');
          }
          return;
        }

        // Update device bond state in list
        if (mounted) {
          final index = _devices.indexWhere((d) => d.address == device.address);
          if (index != -1) {
            final old = _devices[index];
            _devices[index] = ClassicBluetoothDevice(
              name: old.name,
              address: old.address,
              type: old.type,
              bondState: 'bonded',
              isPaired: true,
            );
          }
        }
      }

      if (mounted) {
        setState(() => _error = null);
      }

      final connection = await spp.BluetoothConnection.toAddress(device.address);

      // Clean up old connection via PrinterService
      if (_connection != null) {
        PrinterService.instance.clearSppConnection();
      }

      _connection = connection;
      _connectedDevice = device;

      PrinterService.instance.setSppConnection(connection, device.name, address: device.address);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الاتصال بـ ${device.name}'),
            backgroundColor: const Color(0xFF10B981),
            action: SnackBarAction(
              label: 'قطع الاتصال',
              textColor: Colors.white,
              onPressed: () => _disconnectDevice(),
            ),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('BluetoothDiscovery: Connection failed: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('connect_error') || errorMsg.contains('socket might closed')) {
          errorMsg = 'فشل الاتصال - تأكد أن الطابعة مدعومة وقريبة';
        } else if (errorMsg.contains('read failed')) {
          errorMsg = 'فشل الاتصال - تأكد أن الطابعة تعمل وقريبة من الجهاز';
        }
        setState(() => _error = 'فشل الاتصال: $errorMsg');
      }
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      _connection = null;
      _connectedDevice = null;
      PrinterService.instance.clearSppConnection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قطع الاتصال'),
            backgroundColor: Color(0xFF64748B),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('BluetoothDiscovery: Disconnect failed: $e');
    }
  }

  String _bondStateLabel(String bondState) {
    switch (bondState) {
      case 'bonded':
        return 'مقترن';
      case 'bonding':
        return 'يتم الاقتران';
      case 'none':
        return 'غير مقترن';
      default:
        return '';
    }
  }

  Color _bondStateColor(String bondState) {
    switch (bondState) {
      case 'bonded':
        return const Color(0xFF10B981);
      case 'bonding':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث عن طابعة'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
              ),
            )
          else ...[
            if (_connectedDevice != null)
              IconButton(
                icon: const Icon(Icons.bluetooth_connected, color: Color(0xFF10B981)),
                tooltip: 'قطع الاتصال',
                onPressed: _disconnectDevice,
              ),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'بحث',
              onPressed: _scan,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Bluetooth status card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withAlpha(15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF97316).withAlpha(40)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isBluetoothOn
                        ? const Color(0xFF10B981).withAlpha(30)
                        : const Color(0xFFEF4444).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isBluetoothOn ? Icons.bluetooth_rounded : Icons.bluetooth_disabled_rounded,
                    color: _isBluetoothOn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isBluetoothOn ? 'Bluetooth مفعل' : 'Bluetooth مطفأ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _isBluetoothOn ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _connectedDevice != null
                            ? 'متصل بـ ${_connectedDevice!.name}'
                            : 'تأكد من تشغيل Bluetooth على جهازك',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (!_isBluetoothOn)
                  FilledButton.tonal(
                    onPressed: _turnOnBluetooth,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316).withAlpha(25),
                      foregroundColor: const Color(0xFFF97316),
                    ),
                    child: const Text('تفعيل'),
                  ),
                if (_connectedDevice != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: colorScheme.onSurfaceVariant,
                    onPressed: _disconnectDevice,
                  ),
              ],
            ),
          ),

          // Error message
          if (_error != null && !_isPairing)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Pairing loading indicator
          if (_isPairing)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withAlpha(15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF97316).withAlpha(40)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'جاري الاقتران بالطابعة...',
                    style: TextStyle(color: Color(0xFFF97316), fontSize: 13),
                  ),
                ],
              ),
            ),

          // Device count
          if (_devices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'الأجهزة المكتشفة (${_devices.length})',
                    style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  if (_isScanning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)),
                    ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isScanning ? Icons.bluetooth_searching_rounded : Icons.bluetooth_disabled_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning ? 'جاري البحث...' : 'لا توجد أجهزة',
                          style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        if (!_isScanning)
                          FilledButton.tonalIcon(
                            onPressed: _scan,
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('بدء البحث'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF97316).withAlpha(25),
                              foregroundColor: const Color(0xFFF97316),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isConnected = _connectedDevice?.address == device.address;
                      final bondColor = _bondStateColor(device.bondState);
                      final bondLabel = _bondStateLabel(device.bondState);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isConnected
                                ? const Color(0xFF10B981).withAlpha(128)
                                : colorScheme.outline.withAlpha(50),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? const Color(0xFF10B981).withAlpha(30)
                                  : const Color(0xFFF97316).withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              color: isConnected ? const Color(0xFF10B981) : const Color(0xFFF97316),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  device.name,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (bondLabel.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: bondColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    bondLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: bondColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            device.address,
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          trailing: isConnected
                              ? const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24)
                              : _isPairing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF97316),
                                      ),
                                    )
                                  : FilledButton(
                                      onPressed: () => _connectToDevice(device),
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(80, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        backgroundColor: const Color(0xFFF97316),
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(
                                        device.isPaired ? 'اتصال' : 'اقتران واتصال',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
