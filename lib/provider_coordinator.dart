import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'providers/device_provider.dart';
import 'providers/gnss_provider.dart';
import 'providers/ntrip_provider.dart';
import 'providers/log_provider.dart';


class ProviderCoordinator {
  StreamSubscription? _deviceDataSubscription;
  bool _isInitialized = false;

  void initialize(BuildContext context) {
    if (_isInitialized) return;
    _isInitialized = true;

    final deviceProvider = context.read<DeviceProvider>();
    final gnssProvider = context.read<GnssProvider>();
    final ntripProvider = context.read<NtripProvider>();
    final logProvider = context.read<LogProvider>();

    _deviceDataSubscription = deviceProvider.dataStream.listen((data) {
      gnssProvider.processData(data);

      _extractNmeaLines(data, (line) {
        if (line.startsWith('\$')) {
          logProvider.addLog(line);
          
          if (line.contains("GGA") && ntripProvider.isConnected) {
            gnssProvider.saveGGA(line);
            ntripProvider.sendGGA(line);
          }
        } else if (line.contains(RegExp(r'[\x00-\x1F\x7F-\xFF]'))) {
          logProvider.addLog('[RTCM 二进制数据]');
        }
      });
    });

    ntripProvider.loadSettings();
    deviceProvider.scanDevices();
  }

  String _lineBuffer = "";
  void _extractNmeaLines(String data, Function(String) onLine) {
    _lineBuffer += data;
    
    while (_lineBuffer.contains('\n')) {
      int index = _lineBuffer.indexOf('\n');
      String line = _lineBuffer.substring(0, index).trim();
      _lineBuffer = _lineBuffer.substring(index + 1);
      
      if (line.isNotEmpty) {
        onLine(line);
      }
    }
  }

  void dispose() {
    _deviceDataSubscription?.cancel();
    _deviceDataSubscription = null;
    _isInitialized = false;
  }
}
