import 'dart:async';
import 'package:flutter/foundation.dart';
import '../nmea.dart';


class GnssProvider extends ChangeNotifier {
  String _latitude = "--";
  String _longitude = "--";
  double? _latitudeDeg;
  double? _longitudeDeg;
  String _altitude = "--";

  String _quality = "--";
  String _satellites = "0";
  String _hdop = "--";
  String _time = "--";

  String _latStdDev = "--";
  String _lonStdDev = "--";
  String _altStdDev = "--";
  String _ellipseOrientation = "--";
  String _ellipseSemiMajor = "--";
  String _ellipseSemiMinor = "--";

  String _course = "--";
  String _speed = "--";

  String _buffer = "";
  final Map<String, SatelliteInfo> _satelliteMap = {};
  final Map<String, Set<String>> _sourceSatelliteKeys = {};
  final Map<String, _GsvCycleState> _gsvCycles = {};

  String get latitude => _latitude;
  String get longitude => _longitude;
  double? get latitudeDeg => _latitudeDeg;
  double? get longitudeDeg => _longitudeDeg;
  String get altitude => _altitude;
  String get quality => _quality;
  String get satellites => _satellites;
  String get hdop => _hdop;
  String get time => _time;
  String get latStdDev => _latStdDev;
  String get lonStdDev => _lonStdDev;
  String get altStdDev => _altStdDev;
  String get ellipseOrientation => _ellipseOrientation;
  String get ellipseSemiMajor => _ellipseSemiMajor;
  String get ellipseSemiMinor => _ellipseSemiMinor;
  String get course => _course;
  String get speed => _speed;
  List<SatelliteInfo> get satelliteList {
    final list = _satelliteMap.values.toList();
    list.sort((a, b) {
      final system = a.system.compareTo(b.system);
      if (system != 0) return system;
      final prn = a.prn.compareTo(b.prn);
      if (prn != 0) return prn;
      final sigA = a.signalId ?? '';
      final sigB = b.signalId ?? '';
      return sigA.compareTo(sigB);
    });
    return list;
  }

  bool get hasValidPosition => _latitudeDeg != null && _longitudeDeg != null;
  bool get isRtkFixed => _quality.contains("RTK");

  void processData(String chunk) {
    _buffer += chunk;
    bool needsUpdate = false;
    while (_buffer.contains('\n')) {
      int index = _buffer.indexOf('\n');
      String line = _buffer.substring(0, index).trim();
      _buffer = _buffer.substring(index + 1);
      if (line.isNotEmpty && line.startsWith('\$')) {
        if (_parseNmea(line)) {
          needsUpdate = true;
        }
      }
    }
    if (needsUpdate) {
      _scheduleUpdate();
    }
  }

  bool _update<T>(T? newValue, T currentValue, void Function(T) onUpdate) {
    if (newValue != null && newValue != currentValue) {
      onUpdate(newValue);
      return true;
    }
    return false;
  }

  Timer? _debounceTimer;

  void _scheduleUpdate() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      notifyListeners();
      _debounceTimer = null;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  bool _parseNmea(String line) {
    if (!line.startsWith("\$")) return false;
    final data = NmeaParser.parse(line);
    if (data == null) return false;

    bool hasChanges = false;
    hasChanges |= _update(data.time, _time, (v) => _time = v);
    hasChanges |= _update(data.quality, _quality, (v) => _quality = v);
    hasChanges |= _update(data.satellites, _satellites, (v) => _satellites = v);
    hasChanges |= _update(data.hdop, _hdop, (v) => _hdop = v);
    hasChanges |= _update(data.latitude, _latitude, (v) => _latitude = v);
    hasChanges |= _update(data.longitude, _longitude, (v) => _longitude = v);
    hasChanges |= _update(data.altitude, _altitude, (v) => _altitude = v);
    hasChanges |= _update(data.latitudeDeg, _latitudeDeg, (v) => _latitudeDeg = v);
    hasChanges |= _update(data.longitudeDeg, _longitudeDeg, (v) => _longitudeDeg = v);
    hasChanges |= _update(data.latStdDev, _latStdDev, (v) => _latStdDev = v);
    hasChanges |= _update(data.lonStdDev, _lonStdDev, (v) => _lonStdDev = v);
    hasChanges |= _update(data.altStdDev, _altStdDev, (v) => _altStdDev = v);
    hasChanges |= _update(data.ellipseMajorOrientation, _ellipseOrientation, (v) => _ellipseOrientation = v);
    hasChanges |= _update(data.ellipseSemiMajor, _ellipseSemiMajor, (v) => _ellipseSemiMajor = v);
    hasChanges |= _update(data.ellipseSemiMinor, _ellipseSemiMinor, (v) => _ellipseSemiMinor = v);
    hasChanges |= _update(data.course, _course, (v) => _course = v);
    hasChanges |= _update(data.speed, _speed, (v) => _speed = v);
    hasChanges |= _updateGsvData(data);

    return hasChanges;
  }

  bool _updateGsvData(NmeaData data) {
    final sourceKey = data.gsvSourceKey;
    final updates = data.satelliteUpdates;
    if (sourceKey == null || updates == null) return false;

    final totalMessages = data.gsvTotalMessages ?? 0;
    final messageNumber = data.gsvMessageNumber ?? 0;

    if (totalMessages <= 0 || messageNumber <= 0) {
      return false;
    }

    final cycle = _gsvCycles.putIfAbsent(
      sourceKey,
      () => _GsvCycleState(totalMessages: totalMessages),
    );

    bool isNewCycle = messageNumber == 1 || cycle.totalMessages != totalMessages;
    
    if (!isNewCycle && cycle.frames.containsKey(messageNumber)) {
       cycle.frames.clear();
    }

    if (isNewCycle) {
      cycle.totalMessages = totalMessages;
      cycle.frames.clear();
    }

    cycle.frames[messageNumber] = updates;

    if (cycle.frames.length < cycle.totalMessages) {
      return false;
    }

    final newKeys = <String>{};
    
    for (final frameUpdates in cycle.frames.values) {
      for (final sat in frameUpdates) {
        _satelliteMap[sat.uniqueKey] = sat;
        newKeys.add(sat.uniqueKey);
      }
    }

    final oldKeys = _sourceSatelliteKeys[sourceKey];
    if (oldKeys != null && oldKeys.isNotEmpty) {
      final toRemove = <String>[];
      for (final oldKey in oldKeys) {
        if (!newKeys.contains(oldKey)) {
          toRemove.add(oldKey);
        }
      }
      for (final key in toRemove) {
        _satelliteMap.remove(key);
      }
    }
    
    _sourceSatelliteKeys[sourceKey] = newKeys;
    
    cycle.frames.clear(); 
    
    return true;
  }

  String? _lastGGA;
  String? get lastGGA => _lastGGA;

  void saveGGA(String ggaLine) {
    _lastGGA = ggaLine;
  }

  void reset() {
    _latitude = "--";
    _longitude = "--";
    _latitudeDeg = null;
    _longitudeDeg = null;
    _altitude = "--";
    _quality = "--";
    _satellites = "0";
    _hdop = "--";
    _time = "--";
    _latStdDev = "--";
    _lonStdDev = "--";
    _altStdDev = "--";
    _ellipseOrientation = "--";
    _course = "--";
    _speed = "--";
    _ellipseSemiMajor = "--";
    _ellipseSemiMinor = "--";
    _buffer = "";
    _lastGGA = null;
    _satelliteMap.clear();
    _sourceSatelliteKeys.clear();
    _gsvCycles.clear();
    notifyListeners();
  }
}

class _GsvCycleState {
  int totalMessages;
  final Map<int, List<SatelliteInfo>> frames = {};

  _GsvCycleState({required this.totalMessages});
}
