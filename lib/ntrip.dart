import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class NtripSetting {
  String host;
  int port;
  String mountPoint;
  String username;
  String password;

  NtripSetting({
    required this.host,
    required this.port,
    required this.mountPoint,
    this.username = '',
    this.password = '',
  });

  @override
  String toString() {
    return 'NtripSetting(host: $host, port: $port, mountPoint: $mountPoint)';
  }
}


class Ntrip {
  final NtripSetting setting;

  final void Function(Uint8List data)? onDataReceived;
  final void Function(Object error)? onError;
  final void Function(bool isConnected)? onStateChanged;

  Socket? _socket;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _headerReceived = false;

  Ntrip({
    required this.setting,
    this.onDataReceived,
    this.onError,
    this.onStateChanged,
  });

  bool get isConnected => _isConnected;
  Future<void> connect() async {
    if (_isConnected) return;
    try {
      _socket = await Socket.connect(setting.host, setting.port,
          timeout: const Duration(seconds: 10));
      _socket!.setOption(SocketOption.tcpNoDelay, true);
      _subscription = _socket!.listen(
        _onSocketData,
        onError: _onSocketError,
        onDone: _onSocketDone,
      );
      _sendRequest();
      _isConnected = true;
      _headerReceived = false;
      onStateChanged?.call(true);
    } catch (e) {
      disconnect();
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _cleanup();
  }

  void sendGGA(String gga) {
    if (_socket != null && _isConnected) {
      String dataToSend = gga;
      if (!dataToSend.endsWith('\r\n')) {
        dataToSend += '\r\n';
      }
      try {
        _socket!.write(dataToSend);
      } catch (e) {
        _onSocketError(e);
      }
    }
  }

  void _sendRequest() {
    if (_socket == null) return;

    String auth =
        base64Encode(utf8.encode('${setting.username}:${setting.password}'));
    StringBuffer header = StringBuffer();
    header.write('GET /${setting.mountPoint} HTTP/1.0\r\n');
    header.write('User-Agent: NTRIP Dart Client\r\n');
    header.write('Authorization: Basic $auth\r\n');
    header.write('Accept: */*\r\n');
    header.write('Connection: close\r\n');
    header.write('\r\n');

    _socket!.write(header.toString());
  }

  void _onSocketData(Uint8List data) {
    if (!_headerReceived) {
      try {
        int checkLen = data.length > 1024 ? 1024 : data.length;
        String response = String.fromCharCodes(data.sublist(0, checkLen));

        if (response.startsWith('ICY 200') ||
            response.startsWith('HTTP/1.0 200') ||
            response.startsWith('HTTP/1.1 200')) {
          _headerReceived = true;
          int headerEndIndex = -1;
          for (int i = 0; i < data.length - 3; i++) {
            if (data[i] == 13 &&
                data[i + 1] == 10 &&
                data[i + 2] == 13 &&
                data[i + 3] == 10) {
              headerEndIndex = i + 4;
              break;
            }
          }
          if (headerEndIndex != -1 && headerEndIndex < data.length) {
            onDataReceived?.call(data.sublist(headerEndIndex));
          }
        } else if (response.startsWith('SOURCETABLE')) {
            onError?.call("Received Source Table instead of stream. Check MountPoint.");
            disconnect();
        } else if (response.startsWith('HTTP')) {
             onError?.call("Ntrip connection failed: ${response.split('\r\n').first}");
             disconnect();
        } else {
             
        }
      } catch (e) {
        debugPrint('Error processing NTRIP header: $e');
      }
    } else {
      onDataReceived?.call(data);
    }
  }

  void _onSocketError(Object error) {
    onError?.call(error);
    _cleanup();
  }

  void _onSocketDone() {
    _cleanup();
  }

  void _cleanup() {
    bool wasConnected = _isConnected;
    _isConnected = false;
    _headerReceived = false;
    _subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _subscription = null;
    
    if (wasConnected) {
      onStateChanged?.call(false);
    }
  }
}
