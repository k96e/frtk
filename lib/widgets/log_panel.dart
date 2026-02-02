import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/log_provider.dart';

class LogPanel extends StatelessWidget {
  const LogPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogProvider>(
      builder: (context, logProvider, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '原始 NMEA 日志',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${logProvider.logCount} 条记录',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('清空日志'),
                    onPressed: () {
                      logProvider.clearLogs();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                child: logProvider.logLines.isEmpty
                    ? Center(
                        child: Text(
                          '暂无日志数据',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: false,
                        itemCount: logProvider.logLines.length,
                        itemBuilder: (context, index) {
                          final logLine = logProvider.logLines[index];
                          Color textColor;
                          if (logLine.contains('RTCM')) {
                            textColor = Colors.grey[600]!;
                          } else if (logLine.contains('GGA')) {
                            textColor = Colors.greenAccent;
                          } else if (logLine.contains('RMC')) {
                            textColor = Colors.cyanAccent;
                          } else {
                            textColor = Colors.grey[400]!;
                          }
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              logLine,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: textColor,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
