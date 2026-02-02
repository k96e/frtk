import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ntrip.dart';


class NtripProvider extends ChangeNotifier {
  Ntrip? _ntrip;
  bool _isConnected = false;
  String _status = "未连接";
  int _rtcmBytesCount = 0;

  String _host = "rtk.ntrip.com";
  String _port = "2101";
  String _mountPoint = "";
  String _username = "";
  String _password = "";
  
  final Map<int, int> _rtcmStats = {};
  final List<int> _buffer = [];

  bool get isConnected => _isConnected;
  String get status => _status;
  int get rtcmBytesCount => _rtcmBytesCount;
  Map<int, int> get rtcmStats => Map.unmodifiable(_rtcmStats);
  String get host => _host;
  String get port => _port;
  String get mountPoint => _mountPoint;
  String get username => _username;
  String get password => _password;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('ntrip_host') ?? "rtk.ntrip.com";
    _port = prefs.getString('ntrip_port') ?? "2101";
    _mountPoint = prefs.getString('ntrip_mount') ?? "";
    _username = prefs.getString('ntrip_user') ?? "";
    _password = prefs.getString('ntrip_pass') ?? "";
    notifyListeners();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ntrip_host', _host);
    await prefs.setString('ntrip_port', _port);
    await prefs.setString('ntrip_mount', _mountPoint);
    await prefs.setString('ntrip_user', _username);
    await prefs.setString('ntrip_pass', _password);
  }

  void updateConfig({
    String? host,
    String? port,
    String? mountPoint,
    String? username,
    String? password,
  }) {
    if (_isConnected) return;

    if (host != null) _host = host;
    if (port != null) _port = port;
    if (mountPoint != null) _mountPoint = mountPoint;
    if (username != null) _username = username;
    if (password != null) _password = password;
    
    notifyListeners();
  }

  Future<bool> connect({
    required Function(Uint8List data) onDataReceived,
    Function(String log)? onLog,
  }) async {
    if (_isConnected) {
      return true;
    }

    int? portNum = int.tryParse(_port);
    if (_host.isEmpty || portNum == null || _mountPoint.isEmpty) {
      _status = "参数错误：请检查地址、端口和挂载点";
      notifyListeners();
      return false;
    }

    _status = "正在连接 NTRIP...";
    _rtcmBytesCount = 0;
    _rtcmStats.clear();
    _buffer.clear();
    notifyListeners();
    await saveSettings();

    final setting = NtripSetting(
      host: _host,
      port: portNum,
      mountPoint: _mountPoint,
      username: _username,
      password: _password,
    );

    _ntrip = Ntrip(
      setting: setting,
      onDataReceived: (data) {
        _rtcmBytesCount += data.length;
        _parseRtcmStats(data);
        onDataReceived(data);

        if (_rtcmBytesCount % 100 < data.length) {
          notifyListeners();
        }
      },
      onError: (error) {
        _status = "错误: $error";
        _isConnected = false;
        onLog?.call("[NTRIP Error] $error");
        notifyListeners();
      },
      onStateChanged: (connected) {
        _isConnected = connected;
        _status = connected ? "已连接到 $_host" : "已断开";
        onLog?.call("[NTRIP] 连接状态: ${connected ? 'Connected' : 'Disconnected'}");
        notifyListeners();
      },
    );

    try {
      await _ntrip!.connect();
      return true;
    } catch (e) {
      _status = "连接失败: $e";
      notifyListeners();
      return false;
    }
  }

  void disconnect() {
    _ntrip?.disconnect();
    _ntrip = null;
    _isConnected = false;
    _status = "未连接";
    notifyListeners();
  }

  void sendGGA(String ggaLine) {
    if (_isConnected && _ntrip != null) {
      _ntrip!.sendGGA(ggaLine);
    }
  }

  void _parseRtcmStats(Uint8List newData) {
    _buffer.addAll(newData);

    while (_buffer.length >= 3) {
      if (_buffer[0] != 0xD3) {
        _buffer.removeAt(0);
        continue;
      }
      int len = ((_buffer[1] & 0x03) << 8) | _buffer[2];
      int totalLen = 3 + len + 3;
      if (_buffer.length < totalLen) {
        break;
      }
      if (len >= 2) {
        int b3 = _buffer[3];
        int b4 = _buffer[4];
        int msgId = (b3 << 4) | (b4 >> 4);
        
        _rtcmStats.update(msgId, (value) => value + 1, ifAbsent: () => 1);
      }
      _buffer.removeRange(0, totalLen);
    }

    if (_buffer.length > 1024 * 10) {
      _buffer.clear();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
