import 'package:flutter/foundation.dart';


class LogProvider extends ChangeNotifier {
  final List<String> _logLines = [];
  static const int maxLogLines = 100;

  List<String> get logLines => List.unmodifiable(_logLines);
  int get logCount => _logLines.length;

  void addLog(String line) {
    final now = DateTime.now();
    final timeStamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    if (_logLines.length >= maxLogLines) {
      _logLines.removeAt(0);
    }
    
    _logLines.add('[$timeStamp] $line');
    notifyListeners();
  }

  void clearLogs() {
    _logLines.clear();
    notifyListeners();
  }

  void addLogs(List<String> lines) {
    final now = DateTime.now();
    final timeStamp = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    for (var line in lines) {
      if (_logLines.length >= maxLogLines) {
        _logLines.removeAt(0);
      }
      _logLines.add('[$timeStamp] $line');
    }
    
    notifyListeners();
  }
}
