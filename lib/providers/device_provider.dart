import 'dart:async';
import 'package:flutter/foundation.dart';
import 'adapters/serial_adapter.dart';

class DeviceProvider extends ChangeNotifier {
  late final SerialAdapter _adapter;
  SerialDeviceInfo? _connectedDevice;
  String _status = "未连接";
  List<SerialDeviceInfo> _availableDevices = [];
  int _selectedBaudRate = 115200;
  StreamSubscription<String>? _subscription;

  DeviceProvider() {
    _adapter = SerialAdapter.create();
    _setupDataStream();
  }

  SerialDeviceInfo? get connectedDevice => _connectedDevice;
  String get status => _status;
  List<SerialDeviceInfo> get availableDevices => _availableDevices;
  int get selectedBaudRate => _selectedBaudRate;
  bool get isConnected => _adapter.isConnected;
  
  Stream<String> get dataStream => _adapter.dataStream;

  void _setupDataStream() {
    
  }

  final List<int> baudRates = [
    4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
  ];

  Future<void> scanDevices() async {
    _status = "正在扫描设备...";
    notifyListeners();

    try {
      _availableDevices = await _adapter.scanDevices();
      
      if (_availableDevices.isEmpty) {
        _status = "未发现设备";
      } else {
        _status = _connectedDevice != null 
            ? "已连接: ${_connectedDevice!.productName ?? _connectedDevice!.name}" 
            : "未连接";
      }
    } catch (e) {
      _status = "扫描失败: $e";
    }
    
    notifyListeners();
  }

  void setBaudRate(int baudRate) {
    if (_connectedDevice == null && baudRates.contains(baudRate)) {
      _selectedBaudRate = baudRate;
      notifyListeners();
    }
  }

  Future<bool> connectTo(SerialDeviceInfo device) async {
    await disconnect();

    _status = "正在连接...";
    notifyListeners();

    bool success = await _adapter.connect(device, _selectedBaudRate);
    
    if (success) {
      _connectedDevice = device;
      _status = "已连接";
    } else {
      _status = _adapter.statusMessage;
    }
    
    notifyListeners();
    return success;
  }

  Future<void> disconnect() async {
    await _adapter.disconnect();
    _connectedDevice = null;
    _status = "已断开";
    notifyListeners();
  }

  Future<bool> write(Uint8List data) async {
    return await _adapter.write(data);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_adapter is AndroidSerialAdapter) {
      _adapter.dispose();
    } else if (_adapter is WindowsSerialAdapter) {
      _adapter.dispose();
    }
    super.dispose();
  }
}
