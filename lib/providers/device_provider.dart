import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';

class DeviceProvider extends ChangeNotifier {
  UsbPort? _port;
  UsbDevice? _connectedDevice;
  String _status = "未连接";
  List<UsbDevice> _availableDevices = [];
  int _selectedBaudRate = 115200;
  StreamSubscription<Uint8List>? _subscription;

  final _dataStreamController = StreamController<String>.broadcast();

  UsbDevice? get connectedDevice => _connectedDevice;
  String get status => _status;
  List<UsbDevice> get availableDevices => _availableDevices;
  int get selectedBaudRate => _selectedBaudRate;
  bool get isConnected => _connectedDevice != null && _port != null;
  
  Stream<String> get dataStream => _dataStreamController.stream;

  final List<int> baudRates = [
    4800, 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
  ];

  Future<void> scanDevices() async {
    _status = "正在扫描设备...";
    notifyListeners();

    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      _availableDevices = devices;
      
      if (_availableDevices.isEmpty) {
        _status = "未发现设备";
      } else {
        _status = _connectedDevice != null 
            ? "已连接: ${_connectedDevice!.productName}" 
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

  Future<bool> connectTo(UsbDevice device) async {
    await disconnect();

    _status = "正在连接...";
    notifyListeners();

    try {
      UsbPort? port = await device.create();
      if (port == null) {
        _status = "创建端口失败";
        notifyListeners();
        return false;
      }

      bool openResult = await port.open();
      if (!openResult) {
        _status = "打开端口失败";
        notifyListeners();
        return false;
      }

      await port.setPortParameters(
        _selectedBaudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _port = port;
      _connectedDevice = device;
      _status = "已连接";

      _subscription = _port!.inputStream!.listen(
        (Uint8List data) {
          String dataStr = String.fromCharCodes(data);
          _dataStreamController.add(dataStr);
        },
        onError: (error) {
          _status = "数据接收错误: $error";
          notifyListeners();
        },
      );

      notifyListeners();
      return true;
    } catch (e) {
      _status = "连接失败: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    
    if (_port != null) {
      await _port!.close();
      _port = null;
    }

    _connectedDevice = null;
    _status = "已断开";
    notifyListeners();
  }

  Future<bool> write(Uint8List data) async {
    if (_port == null) {
      return false;
    }

    try {
      await _port!.write(data);
      return true;
    } catch (e) {
      debugPrint("写入串口失败: $e");
      return false;
    }
  }

  @override
  void dispose() {
    disconnect();
    _dataStreamController.close();
    super.dispose();
  }
}
