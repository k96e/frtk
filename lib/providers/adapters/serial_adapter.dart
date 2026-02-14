import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:usb_serial/usb_serial.dart';
import 'package:serial_port_win32/serial_port_win32.dart' as win32;

/// 串口设备信息的统一抽象
class SerialDeviceInfo {
  final String id;
  final String name;
  final String? manufacturer;
  final String? productName;

  SerialDeviceInfo({
    required this.id,
    required this.name,
    this.manufacturer,
    this.productName,
  });

  @override
  String toString() => productName ?? name;
}

/// 串口适配器抽象类 - 定义统一的串口操作接口
abstract class SerialAdapter {
  /// 扫描可用设备
  Future<List<SerialDeviceInfo>> scanDevices();

  /// 连接到指定设备
  Future<bool> connect(SerialDeviceInfo device, int baudRate);

  /// 断开连接
  Future<void> disconnect();

  /// 写入数据
  Future<bool> write(Uint8List data);

  /// 数据流
  Stream<String> get dataStream;

  /// 是否已连接
  bool get isConnected;

  /// 获取连接状态信息
  String get statusMessage;

  /// 工厂方法 - 根据平台自动选择适配器
  static SerialAdapter create() {
    if (Platform.isWindows) {
      return WindowsSerialAdapter();
    } else if (Platform.isAndroid || Platform.isLinux) {
      return AndroidSerialAdapter();
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }
  }
}

/// Android/Linux平台的USB串口适配器
class AndroidSerialAdapter extends SerialAdapter {
  UsbPort? _port;
  UsbDevice? _currentDevice;
  StreamSubscription<Uint8List>? _subscription;
  final _dataController = StreamController<String>.broadcast();
  String _status = "未连接";

  @override
  Future<List<SerialDeviceInfo>> scanDevices() async {
    try {
      List<UsbDevice> devices = await UsbSerial.listDevices();
      return devices.map((device) {
        return SerialDeviceInfo(
          id: '${device.vid}_${device.pid}_${device.deviceId}',
          name: device.deviceName,
          manufacturer: device.manufacturerName,
          productName: device.productName,
        );
      }).toList();
    } catch (e) {
      debugPrint('扫描Android设备失败: $e');
      return [];
    }
  }

  @override
  Future<bool> connect(SerialDeviceInfo deviceInfo, int baudRate) async {
    await disconnect();

    try {
      // 重新扫描找到对应设备
      List<UsbDevice> devices = await UsbSerial.listDevices();
      UsbDevice? targetDevice;
      
      for (var device in devices) {
        String id = '${device.vid}_${device.pid}_${device.deviceId}';
        if (id == deviceInfo.id) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice == null) {
        _status = "设备未找到";
        return false;
      }

      UsbPort? port = await targetDevice.create();
      if (port == null) {
        _status = "创建端口失败";
        return false;
      }

      bool openResult = await port.open();
      if (!openResult) {
        _status = "打开端口失败";
        return false;
      }

      await port.setPortParameters(
        baudRate,
        UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1,
        UsbPort.PARITY_NONE,
      );

      _port = port;
      _currentDevice = targetDevice;
      _status = "已连接";

      // 监听数据流
      _subscription = _port!.inputStream!.listen(
        (Uint8List data) {
          String dataStr = String.fromCharCodes(data);
          _dataController.add(dataStr);
        },
        onError: (error) {
          _status = "数据接收错误: $error";
          debugPrint(_status);
        },
      );

      return true;
    } catch (e) {
      _status = "连接失败: $e";
      debugPrint(_status);
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    if (_port != null) {
      await _port!.close();
      _port = null;
    }

    _currentDevice = null;
    _status = "已断开";
  }

  @override
  Future<bool> write(Uint8List data) async {
    if (_port == null) return false;

    try {
      await _port!.write(data);
      return true;
    } catch (e) {
      debugPrint("写入串口失败: $e");
      return false;
    }
  }

  @override
  Stream<String> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _port != null && _currentDevice != null;

  @override
  String get statusMessage => _status;

  void dispose() {
    disconnect();
    _dataController.close();
  }
}

/// Windows平台的串口适配器
class WindowsSerialAdapter extends SerialAdapter {
  win32.SerialPort? _port;
  StreamSubscription<Uint8List>? _subscription;
  final _dataController = StreamController<String>.broadcast();
  String _status = "未连接";

  @override
  Future<List<SerialDeviceInfo>> scanDevices() async {
    try {
      List<String> ports = win32.SerialPort.getAvailablePorts();
      return ports.map((portName) {
        return SerialDeviceInfo(
          id: portName,
          name: portName,
          productName: portName,
        );
      }).toList();
    } catch (e) {
      debugPrint('扫描Windows串口失败: $e');
      return [];
    }
  }

  @override
  Future<bool> connect(SerialDeviceInfo deviceInfo, int baudRate) async {
    await disconnect();

    try {
      _port = win32.SerialPort(deviceInfo.id, openNow: false, BaudRate: baudRate, ReadIntervalTimeout: 1, ReadTotalTimeoutConstant: 2);
      
      _port!.open();

      // _port!.openWithSettings(
      //   BaudRate: baudRate,
      //   ByteSize: 8
      // );

      if (!_port!.isOpened) {
        _status = "打开端口失败";
        _port = null;
        return false;
      }

      _status = "已连接";

      // 启动数据监听
      _startListening();

      return true;
    } catch (e) {
      _status = "连接失败: $e";
      debugPrint(_status);
      _port?.close();
      _port = null;
      return false;
    }
  }

  void _startListening() {
    if (_port == null || !_port!.isOpened) return;

    try {
      _port!.readBytesOnListen(1024, (Uint8List data) {
        if (data.isNotEmpty) {
          String dataStr = String.fromCharCodes(data);
          _dataController.add(dataStr);
        }
      });
    } catch (e) {
      debugPrint("监听串口数据失败: $e");
    }
  }

  @override
  Future<void> disconnect() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }

    if (_port != null) {
      try {
        _port!.close();
      } catch (e) {
        debugPrint("关闭串口失败: $e");
      }
      _port = null;
    }

    _status = "已断开";
  }

  @override
  Future<bool> write(Uint8List data) async {
    if (_port == null || !_port!.isOpened) return false;

    try {
      return _port!.writeBytesFromUint8List(data);
    } catch (e) {
      debugPrint("写入串口失败: $e");
      return false;
    }
  }

  @override
  Stream<String> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _port != null && _port!.isOpened;

  @override
  String get statusMessage => _status;

  void dispose() {
    disconnect();
    _dataController.close();
  }
}
